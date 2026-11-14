program define gracedr_simulate, rclass
    version 19
    syntax ,                        ///
        METHODS(string)             ///
        NSIMS(string)               ///
        SEED(string)                ///
        [                           ///
        STUDY(string)               ///
        N(string)                   ///
        ARMS(string asis)           ///
        RATIO(string)               ///
        WEIGHTS(string)             ///
        PSTAR(string)               ///
        XI(string)                  ///
        RUNIN(string)               ///
        RUNINMETHOD(string)         ///
        FORCEDAT(string)            ///
        SIZEBOUND(string)           ///
        CATEGORICAL(string asis)    ///
        CONTINUOUS(string asis)     ///
        GENERATOR(string)           ///
        PROBS(string)               ///
        MEANSD(string)              ///
        DRIFTTO(string)             ///
        PHIGH(string)               ///
        SAVING(string)              ///
        SUMMARY(string)             ///
        CLEAR                       ///
        ]
    _gracedr_core load
    _gracedr_generate load
    _gracedr_metrics load
    _gracedr_simulate_load
    local methods : list clean methods
    _gracedr_simulate_check_inputs, ///
        methods(`"`macval(methods)'"') ///
        nsims(`"`macval(nsims)'"') ///
        seed(`"`macval(seed)'"')
    _gracedr_simulate_check_paths, ///
        study(`"`macval(study)'"') ///
        saving(`"`macval(saving)'"') ///
        summary(`"`macval(summary)'"')
    if !missing(`"`macval(study)'"') {
        local design_given = !missing(`"`n'`macval(arms)'`ratio'`weights'`pstar'`xi'`runin'"')
        local design_given = `design_given' | !missing(`"`runinmethod'`forcedat'`sizebound'"')
        local variables_given = !missing(`"`macval(categorical)'`macval(continuous)'"')
        local design_given = `design_given' | `variables_given'
        if `design_given' == 1 {
            display as error "gracedr: use either study() or the design options, not both"
            exit 198
        }
        _gracedr_settings load, study(`"`macval(study)'"') designonly
        foreach setting in n ratio weights pstar xi runin runinmethod forcedat sizebound {
            local d_`setting' "`r(`setting')'"
        }
        local d_nvars "`r(nvars)'"
        local d_varnames "`r(varnames)'"
        local d_vartypes "`r(vartypes)'"
        mata: st_local("d_arms", st_global("r(arms)"))
        forvalues position = 1/`d_nvars' {
            mata: st_local("d_levels`position'", st_global("r(levels`position')"))
        }
    }
    else {
        if missing(`"`n'"') | missing(`"`macval(arms)'"') {
            display as error "gracedr: simulate needs study() or n() and arms()"
            exit 198
        }
        local call `"_gracedr_design validate, n(`n') arms(`macval(arms)')"'
        foreach option in ratio weights pstar xi runin runinmethod forcedat sizebound {
            if !missing(`"``option''"') {
                local call `"`call' `option'(``option'')"'
            }
        }
        if !missing(`"`macval(categorical)'"') {
            local call `"`call' categorical(`macval(categorical)')"'
        }
        if !missing(`"`macval(continuous)'"') {
            local call `"`call' continuous(`macval(continuous)')"'
        }
        `call'
        local d_n = string(r(n), "%21.0f")
        local d_pstar = strtrim(string(r(pstar), "%21.15g"))
        local d_xi = strtrim(string(r(xi), "%21.15g"))
        local d_runin = string(r(runin), "%21.0f")
        local d_sizebound = string(r(sizebound), "%21.0f")
        local d_nvars = string(r(nvars), "%21.0f")
        foreach setting in ratio weights runinmethod forcedat varnames vartypes {
            mata: st_local("d_`setting'", st_global("r(`setting')"))
        }
        mata: st_local("d_arms", st_global("r(arms)"))
        forvalues position = 1/`d_nvars' {
            mata: st_local("d_levels`position'", st_global("r(levels`position')"))
        }
    }
    local counts ""
    forvalues position = 1/`d_nvars' {
        local level_count : word count `d_levels`position''
        local counts "`counts' `level_count'"
    }
    _gracedr_simulate_check_methods, methods(`methods') ratio(`d_ratio') phigh(`"`phigh'"')
    local d_phigh "`phigh'"
    _gracedr_generate check, ///
        varnames(`d_varnames') ///
        vartypes(`d_vartypes') ///
        levelcounts(`counts') ///
        generator(`generator') ///
        probs(`"`macval(probs)'"') ///
        meansd(`"`macval(meansd)'"') ///
        driftto(`"`macval(driftto)'"')
    forvalues position = 1/`d_nvars' {
        local g_start`position' "`r(start`position')'"
        local g_end`position' "`r(end`position')'"
    }
    local user_rng = c(rng)
    local user_state = c(rngstate)
    preserve
    set rng mt64
    capture noisily mata: gd_simulate()
    local failure = _rc
    set rng `user_rng'
    set rngstate `user_state'
    if inrange(`failure', 1, 1e9) {
        exit `failure'
    }
    tempfile results
    _gracedr_simulate_report, ///
        resrows(`result_rows') ///
        sumrows(`summary_rows') ///
        results(`"`results'"') ///
        saving(`"`macval(saving)'"') ///
        summary(`"`macval(summary)'"')
    if !missing("`clear'") {
        quietly use `"`results'"', clear
        restore, not
    }
    return scalar nsims = real("`nsims'")
    return local methods "`methods'"
end

program define _gracedr_simulate_load
    version 19
    capture mata: gd_simulate_version()
    local ready = _rc == 0
    if `ready' == 0 {
        quietly findfile _gracedr_simulate.mata
        quietly do "`r(fn)'"
    }
end

program define _gracedr_simulate_check_inputs
    syntax , METHODS(string) NSIMS(string) SEED(string)
    local known mmsb srs blocks minimization msb
    local repeated : list dups methods
    if missing("`methods'") | !missing("`repeated'") {
        display as error "gracedr: methods() must be a non-empty set of unique method names"
        exit 198
    }
    foreach method of local methods {
        local is_known : list method in known
        if `is_known' == 0 {
            display as error "gracedr: unknown method `method'; choose from `known'"
            exit 198
        }
    }
    local valid = regexm(`"`nsims'"', "^[0-9]+$")
    if `valid' == 1 {
        local valid = inrange(real(`"`nsims'"'), 1, 100000000)
    }
    if `valid' == 0 {
        display as error "gracedr: nsims() must be a whole number from 1 to 100000000"
        exit 198
    }
    _gracedr_rng check_seed, seed(`"`seed'"')
end

program define _gracedr_simulate_check_paths
    syntax , [STUDY(string) SAVING(string) SUMMARY(string)]
    local same = !missing(`"`macval(saving)'"') & `"`macval(saving)'"' == `"`macval(summary)'"'
    if `same' == 1 {
        display as error "gracedr: saving() and summary() must be different files"
        exit 198
    }
    if missing(`"`macval(study)'"') {
        exit
    }
    _gracedr_study folder, study(`"`macval(study)'"')
    mata: st_local("folder", ustrlower(st_global("r(folder)")))
    foreach option in saving summary {
        local path = ustrlower(subinstr(`"`macval(`option')'"', char(92), "/", .))
        local inside = strpos(`"`macval(path)'"', `"`macval(folder)'/"') == 1
        if `inside' == 1 {
            display as error "gracedr: `option'() must not point into the study folder"
            exit 198
        }
    }
end

program define _gracedr_simulate_check_methods
    syntax , METHODS(string) RATIO(string) [PHIGH(string)]
    local blocks : list posof "blocks" in methods
    if inrange(`blocks', 1, 100) {
        foreach value of local ratio {
            local whole = `value' == round(`value')
            if `whole' == 0 {
                display as error "gracedr: blocks needs whole-number ratio values"
                exit 198
            }
        }
    }
    if !missing(`"`phigh'"') {
        local high = real(`"`phigh'"')
        local valid = !missing(`high') & inrange(`high', 0.0000000001, 0.9999999999)
        if `valid' == 0 {
            display as error "gracedr: phigh() must be a number greater than 0 and less than 1"
            exit 198
        }
    }
end

program define _gracedr_simulate_report
    syntax ,                    ///
        RESROWS(integer)        ///
        SUMROWS(integer)        ///
        RESULTS(string)         ///
        [                       ///
        SAVING(string)          ///
        SUMMARY(string)         ///
        ]
    clear
    quietly set obs `resrows'
    quietly generate long sim = .
    quietly generate str12 method = ""
    quietly generate str12 point = ""
    quietly generate strL metric = ""
    quietly generate double value = .
    mata: gd_results_to_data()
    if !missing(`"`macval(saving)'"') {
        capture quietly save `"`macval(saving)'"', replace
        local saved = _rc == 0
        if `saved' == 0 {
            display as error `"gracedr: could not save the results to `macval(saving)'"'
            exit 603
        }
    }
    quietly save `"`results'"', replace
    clear
    quietly set obs `sumrows'
    quietly generate str12 method = ""
    quietly generate str12 point = ""
    quietly generate strL metric = ""
    foreach name in mean sd q95 q99 max {
        quietly generate double `name' = .
    }
    mata: gd_summary_to_data()
    if !missing(`"`macval(summary)'"') {
        capture quietly save `"`macval(summary)'"', replace
        local saved = _rc == 0
        if `saved' == 0 {
            display as error `"gracedr: could not save the summary to `macval(summary)'"'
            exit 603
        }
    }
    format mean sd q95 q99 max %10.3f
    display as text "Simulation summary (mean, sd, 95th and 99th percentiles, maximum)"
    list method point metric mean sd q95 q99 max, noobs separator(0) abbreviate(24)
end
