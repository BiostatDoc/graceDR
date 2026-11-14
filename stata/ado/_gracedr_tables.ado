program define _gracedr_tables
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known groupsize balance
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown tables subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_tables_`subcommand' `macval(0)'
end

program define _gracedr_tables_checkpoints
    syntax , N(string) RATIO(string) RUNIN(string) [FORCEDAT(string)]
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
end

program define _gracedr_tables_groupsize, rclass
    syntax , STUDY(string) [FROM(string) TO(string) CHECKPOINT(string) VARS(string)]
    preserve
    _gracedr_settings load, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    mata: st_local("n", st_global("r(n)"))
    mata: st_local("arms", st_global("r(arms)"))
    mata: st_local("ratio", st_global("r(ratio)"))
    mata: st_local("runin", st_global("r(runin)"))
    mata: st_local("forcedat", st_global("r(forcedat)"))
    local arm_count : word count `macval(arms)'
    local total = _N
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        quietly count if arm == `"`macval(label)'"'
        local count`arm' = r(N)
    }
    _gracedr_tables_checkpoints, ///
        n(`n') ///
        ratio(`ratio') ///
        runin(`runin') ///
        forcedat(`forcedat')
    local rows = _N
    local next_row = `rows'
    local found = 0
    forvalues row = 1/`rows' {
        local reached = inrange(n[`row'], `total' + 1, 1e15)
        if `reached' == 1 & `found' == 0 {
            local next_row = `row'
            local found = 1
        }
    }
    tempname sizes
    matrix `sizes' = J(`arm_count', 4, .)
    local row_names ""
    display as text "Group sizes"
    display as text %-20s "Arm" %8s "n" %8s "pct" %14s "Next target" %14s "Final target"
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        local percent = 0
        if inrange(`total', 1, 1e15) {
            local percent = round(100 * `count`arm'' / `total', 0.1)
        }
        local next_target = target`arm'[`next_row']
        local final_target = target`arm'[`rows']
        matrix `sizes'[`arm', 1] = `count`arm''
        matrix `sizes'[`arm', 2] = `percent'
        matrix `sizes'[`arm', 3] = `next_target'
        matrix `sizes'[`arm', 4] = `final_target'
        local row_name = strtoname(`"`macval(label)'"')
        local row_names "`row_names' `row_name'"
        local shown = abbrev(`"`macval(label)'"', 20)
        display as text %-20s `"`macval(shown)'"' as result %8.0g `count`arm'' ///
            %8.1f `percent' %14.0g `next_target' %14.0g `final_target'
    }
    matrix rownames `sizes' = `row_names'
    matrix colnames `sizes' = n pct next_target final_target
    return matrix groupsize = `sizes'
    return scalar total = `total'
end

program define _gracedr_tables_cell
    syntax , NAME(string) TYPE(string) LABEL(string asis) [LEVEL(string asis)]
    quietly count if arm == `"`macval(label)'"' & !missing(`name')
    local present = r(N)
    if "`type'" == "categorical" {
        quietly count if arm == `"`macval(label)'"' & ///
            `name' == `"`macval(level)'"'
        local percent = 0
        if inrange(`present', 1, 1e15) {
            local percent = 100 * r(N) / `present'
        }
        local text = string(r(N)) + " (" + strtrim(string(`percent', "%9.1f")) + "%)"
    }
    else {
        local text "-"
        if inrange(`present', 1, 1e15) {
            quietly summarize `name' if arm == `"`macval(label)'"'
            local spread "-"
            if inrange(`present', 2, 1e15) {
                local spread = strtrim(string(r(sd), "%9.1f"))
            }
            local text = strtrim(string(r(mean), "%9.1f")) + " (" + "`spread'" + ")"
        }
    }
    c_local cell `"`macval(text)'"'
end

program define _gracedr_tables_balance, rclass
    syntax , STUDY(string) [SAVING(string) FROM(string) TO(string) CHECKPOINT(string) ///
        VARS(string)]
    preserve
    _gracedr_settings load, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    mata: st_local("arms", st_global("r(arms)"))
    mata: st_local("varnames", st_global("r(varnames)"))
    mata: st_local("vartypes", st_global("r(vartypes)"))
    local variable_count = real(r(nvars))
    forvalues position = 1/`variable_count' {
        mata: st_local("levels`position'", st_global("r(levels`position')"))
    }
    local arm_count : word count `macval(arms)'
    tempname smd_values
    matrix `smd_values' = J(`variable_count', 1, .)
    local row = 0
    forvalues position = 1/`variable_count' {
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        _gracedr_smd variable, ///
            name(`name') ///
            type(`type') ///
            arms(`macval(arms)') ///
            levels(`macval(levels`position')')
        matrix `smd_values'[`position', 1] = r(smd)
        local smd_value = r(smd)
        quietly count if missing(`name')
        local missing_count = r(N)
        local level_total = 1
        if "`type'" == "categorical" {
            local level_total : word count `macval(levels`position')'
        }
        forvalues index = 1/`level_total' {
            local level ""
            if "`type'" == "categorical" {
                local level : word `index' of `macval(levels`position')'
            }
            local row = `row' + 1
            local row_variable`row' "`name'"
            local row_level`row' `"`macval(level)'"'
            local row_missing`row' = `missing_count'
            local row_smd`row' = `smd_value'
            forvalues arm = 1/`arm_count' {
                local label : word `arm' of `macval(arms)'
                _gracedr_tables_cell, ///
                    name(`name') ///
                    type(`type') ///
                    label(`macval(label)') ///
                    level(`macval(level)')
                local row_cell`row'_`arm' `"`macval(cell)'"'
            }
        }
    }
    clear
    quietly set obs `row'
    quietly generate str32 variable = ""
    quietly generate str244 level = ""
    forvalues arm = 1/`arm_count' {
        quietly generate str40 arm`arm' = ""
    }
    quietly generate long nmissing = .
    quietly generate double smd = .
    forvalues position = 1/`row' {
        quietly replace variable = "`row_variable`position''" in `position'
        quietly replace level = `"`macval(row_level`position')'"' in `position'
        quietly replace nmissing = `row_missing`position'' in `position'
        quietly replace smd = `row_smd`position'' in `position'
        forvalues arm = 1/`arm_count' {
            quietly replace arm`arm' = `"`macval(row_cell`position'_`arm')'"' in `position'
        }
    }
    display as text "Balance by arm"
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        display as text "  arm`arm' = " as result `"`macval(label)'"'
    }
    format smd %6.3f
    list, noobs separator(0) abbreviate(20)
    if !missing(`"`macval(saving)'"') {
        capture quietly save `"`macval(saving)'"', replace
        local saved = _rc == 0
        if `saved' == 0 {
            display as error `"gracedr: could not save the table to `macval(saving)'"'
            exit 603
        }
    }
    matrix rownames `smd_values' = `varnames'
    matrix colnames `smd_values' = smd
    return matrix smd = `smd_values'
    return local varnames "`varnames'"
end
