program define _gracedr_graphs
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known imbalance smd
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown graphs subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_graphs_`subcommand' `macval(0)'
end

program define _gracedr_graphs_save
    args graph_name saving
    if !missing(`"`macval(saving)'"') {
        capture quietly graph save `graph_name' `"`macval(saving)'"', replace
        local saved = _rc == 0
        if `saved' == 0 {
            display as error `"gracedr: could not save the graph to `macval(saving)'"'
            exit 603
        }
    }
end

program define _gracedr_graphs_reached, rclass
    syntax , N(string) RATIO(string) RUNIN(string) [FORCEDAT(string)] LIMIT(integer)
    if missing(`"`macval(forcedat)'"') {
        _gracedr_design checkpoints, n(`n') ratio(`ratio') runin(`runin')
    }
    else {
        _gracedr_design checkpoints, ///
            n(`n') ///
            ratio(`ratio') ///
            runin(`runin') ///
            forcedat(`forcedat')
    }
    local reached ""
    local rows = _N
    forvalues row = 1/`rows' {
        local value = n[`row']
        if inrange(`macval(value)', 1, `limit') {
            local reached "`reached' `macval(value)'"
        }
    }
    return local reached = strtrim("`reached'")
end

program define _gracedr_graphs_imbalance, rclass
    syntax , STUDY(string) [SAVING(string) FROM(string) TO(string) CHECKPOINT(string)]
    preserve
    _gracedr_settings load, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"')
    mata: st_local("n", st_global("r(n)"))
    mata: st_local("arms", st_global("r(arms)"))
    mata: st_local("ratio", st_global("r(ratio)"))
    mata: st_local("runin", st_global("r(runin)"))
    mata: st_local("forcedat", st_global("r(forcedat)"))
    local arm_count : word count `macval(arms)'
    local total = _N
    return scalar total = `total'
    if `total' == 0 {
        twoway (scatteri 0 0, msymbol(none)), ///
            name(gracedr_imbalance, replace) ///
            xtitle("Participants randomized") ///
            ytitle("Count minus target") ///
            subtitle("No participants randomized yet.") ///
            legend(off)
        _gracedr_graphs_save gracedr_imbalance `"`macval(saving)'"'
        return local reached ""
        exit
    }
    tempfile enrolled
    quietly save `"`enrolled'"'
    _gracedr_graphs_reached, ///
        n(`n') ///
        ratio(`ratio') ///
        runin(`runin') ///
        forcedat(`forcedat') ///
        limit(`total')
    local reached "`r(reached)'"
    quietly use `"`enrolled'"', clear
    local ratio_total = 0
    foreach value of local ratio {
        local ratio_total = `ratio_total' + `macval(value)'
    }
    local plots ""
    local legend_order ""
    local final_values ""
    local largest = 0
    tempname deviation_values
    matrix `deviation_values' = J(1, `arm_count', .)
    quietly generate double step = _n
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        local share = real(word("`ratio'", `arm')) / `ratio_total'
        quietly generate byte hit`arm' = arm == `"`macval(label)'"'
        quietly generate double deviation`arm' = sum(hit`arm') - `share' * _n
        quietly summarize deviation`arm'
        local largest = max(`largest', abs(r(min)), abs(r(max)))
        matrix `deviation_values'[1, `arm'] = deviation`arm'[_N]
        local plots "`plots' (line deviation`arm' step, connect(stairstep))"
        local legend_order `"`legend_order' `arm' "`macval(label)'""'
    }
    local lines ""
    if !missing("`reached'") {
        local lines "xline(`reached', lpattern(dash))"
    }
    twoway `plots', ///
        name(gracedr_imbalance, replace) ///
        yline(0) ///
        `lines' ///
        xtitle("Participants randomized") ///
        ytitle("Count minus target") ///
        legend(order(`legend_order') title("Arm"))
    _gracedr_graphs_save gracedr_imbalance `"`macval(saving)'"'
    return matrix deviation = `deviation_values'
    return scalar maxdeviation = `largest'
    return local reached "`reached'"
end

program define _gracedr_graphs_smd, rclass
    syntax , STUDY(string) [SAVING(string) FROM(string) TO(string) CHECKPOINT(string) ///
        VARS(string)]
    quietly _gracedr_tables balance, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    tempname smd_values
    matrix `smd_values' = r(smd)
    local varnames "`r(varnames)'"
    local variable_count : word count `varnames'
    preserve
    clear
    quietly set obs `variable_count'
    quietly generate double absolute = .
    quietly generate str32 shown = ""
    forvalues index = 1/`variable_count' {
        quietly replace absolute = abs(`smd_values'[`index', 1]) in `index'
        local name : word `index' of `varnames'
        quietly replace shown = "`name'" in `index'
    }
    quietly drop if missing(absolute)
    local plotted = _N
    quietly generate byte position = _N - _n + 1
    forvalues index = 1/`plotted' {
        local place = position[`index']
        local name = shown[`index']
        label define variable_names `place' "`name'", add
    }
    label values position variable_names
    local labels "1/`plotted'"
    if `plotted' == 0 {
        local labels "0"
    }
    local options ///
        `"name(gracedr_smd, replace) xline(0.1, lpattern(dash)) ytitle("")"'
    local options `"`options' xtitle("Absolute standardized mean difference")"'
    local options `"`options' ylabel(`labels', valuelabel angle(horizontal))"'
    if `plotted' == 0 {
        twoway (scatteri 0 0, msymbol(none)), `options' legend(off)
    }
    else {
        twoway scatter position absolute, `options'
    }
    _gracedr_graphs_save gracedr_smd `"`macval(saving)'"'
    return scalar plotted = `plotted'
end
