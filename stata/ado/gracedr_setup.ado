*! version 1.0.0  15nov2026
program define gracedr_setup, rclass
    version 19
    syntax ,                        ///
        STUDY(string)               ///
        N(string)                   ///
        ARMS(string asis)           ///
        [                           ///
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
        CODES(string)               ///
        SEED(string)                ///
        ENCRYPT                     ///
        ]
    _gracedr_study folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study exists, study(`"`macval(study)'"')
    if r(exists) == 1 {
        display as error `"gracedr: a study already exists in `macval(study)'"'
        exit 602
    }
    _gracedr_study reserved_id
    mata: st_local("audit_id", st_global("r(id)"))
    if missing(`"`seed'"') {
        _gracedr_utc
        local seed = string(mod(floor(r(time)), 2147483648), "%21.0f")
        local seed_note " (chosen from the clock)"
    }
    _gracedr_rng check_seed, seed(`"`seed'"')
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
    local variable_count = r(nvars)
    local val_n = string(r(n), "%21.0f")
    mata: st_local("val_arms", st_global("r(arms)"))
    mata: st_local("val_ratio", st_global("r(ratio)"))
    mata: st_local("val_weights", st_global("r(weights)"))
    local val_pstar = strtrim(string(r(pstar), "%21.15g"))
    local val_xi = strtrim(string(r(xi), "%21.15g"))
    local val_runin = string(r(runin), "%21.0f")
    mata: st_local("val_runinmethod", st_global("r(runinmethod)"))
    mata: st_local("val_forcedat", st_global("r(forcedat)"))
    local val_sizebound = string(r(sizebound), "%21.0f")
    local val_nvars = string(r(nvars), "%21.0f")
    mata: st_local("val_varnames", st_global("r(varnames)"))
    mata: st_local("val_vartypes", st_global("r(vartypes)"))
    forvalues position = 1/`variable_count' {
        mata: st_local("val_levels`position'", st_global("r(levels`position')"))
    }
    preserve
    if !missing(`"`macval(codes)'"') {
        _gracedr_codes using `"`macval(codes)'"', arms(`macval(val_arms)')
    }
    capture mkdir `"`macval(folder)'"'
    _gracedr_study folder, study(`"`macval(study)'"')
    if r(found) == 0 {
        display as error `"gracedr: could not create the study folder `macval(study)'"'
        exit 603
    }
    capture noisily {
        _gracedr_study empty, name(design)
        local items n arms ratio weights pstar xi runin runinmethod forcedat sizebound
        local items "`items' nvars varnames vartypes"
        forvalues position = 1/`variable_count' {
            local items "`items' levels`position'"
        }
        local row = 0
        foreach item of local items {
            local row = `macval(row)' + 1
            quietly set obs `macval(row)'
            mata: st_sstore(`macval(row)', "name", "`item'")
            mata: st_sstore(`macval(row)', "value", st_local("val_`item'"))
            quietly replace order = `macval(row)' in `macval(row)'
        }
        _gracedr_study write, study(`"`macval(study)'"') name(design) `encrypt'
        if !missing(`"`macval(codes)'"') {
            quietly _gracedr_codes using `"`macval(codes)'"', arms(`macval(val_arms)')
        }
        else {
            _gracedr_study empty, name(codes)
        }
        _gracedr_study write, study(`"`macval(study)'"') name(codes)
        _gracedr_study empty, name(participants) study(`"`macval(study)'"')
        _gracedr_study write, study(`"`macval(study)'"') name(participants)
        _gracedr_rng init, study(`"`macval(study)'"') seed(`seed')
        _gracedr_study append_audit, ///
            study(`"`macval(study)'"') ///
            action(create) ///
            id(`"`audit_id'"') ///
            reason("study created")
    }
    local failure = _rc
    if `failure' == 0 {
        restore
        display as text `"gracedr: study created in `macval(study)'"'
        display as text "  `val_n' participants planned, run-in `val_runin', " ///
            "seed `seed'`seed_note'"
        return scalar seed = `seed'
        return local study `"`macval(folder)'"'
    }
    else {
        _gracedr_study extension, study(`"`macval(study)'"')
        local extension "`r(extension)'"
        display as error "gracedr: setup stopped before it finished."
        local leftovers ".tmp or .bak"
        if "`extension'" == "zip" {
            local leftovers ".tmp.zip or .bak.zip"
        }
        display as error `"Remove design.`extension', codes.`extension', "' ///
            `"participants.`extension', audit.`extension' and state.`extension', "' ///
            `"and any `leftovers' copies of them, "' ///
            `"from `macval(study)' and run setup again."'
        exit `failure'
    }
end
