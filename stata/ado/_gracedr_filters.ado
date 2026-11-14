program define _gracedr_filters
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known records positions
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown filters subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_filters_`subcommand' `macval(0)'
end

program define _gracedr_filters_whole, rclass
    syntax , NAME(string) [VALUE(string)]
    local present = !missing(`"`macval(value)'"')
    local number = .
    if `present' == 1 {
        local valid = regexm(`"`macval(value)'"', "^[0-9]+$")
        if `valid' == 1 {
            local number = real(`"`macval(value)'"')
            local valid = inrange(`number', 1, 2000000000)
        }
        if `valid' == 0 {
            display as error "gracedr: `name'() must be a whole number of at least 1"
            exit 198
        }
    }
    return scalar number = `number'
end

program define _gracedr_filters_resolve, rclass
    syntax , CHECKPOINT(string) N(string) RATIO(string) RUNIN(string) ///
        [FORCEDAT(string)]
    if missing(`"`forcedat'"') {
        _gracedr_design checkpoints, n(`n') ratio(`ratio') runin(`runin')
    }
    else {
        _gracedr_design checkpoints, ///
            n(`n') ///
            ratio(`ratio') ///
            runin(`runin') ///
            forcedat(`forcedat')
    }
    local total = .
    local rows = _N
    local numeric = regexm(`"`macval(checkpoint)'"', "^[0-9]+$")
    forvalues row = 1/`rows' {
        local match = 0
        if `numeric' == 1 {
            local match = n[`row'] == real(`"`macval(checkpoint)'"')
        }
        else {
            local named = inlist(`"`macval(checkpoint)'"', "run-in", "final")
            local match = type[`row'] == `"`macval(checkpoint)'"' & `named' == 1
        }
        if `match' == 1 {
            local total = n[`row']
        }
    }
    if missing(`total') {
        display as error `"gracedr: unknown checkpoint `macval(checkpoint)'"'
        exit 198
    }
    return scalar total = `total'
end

program define _gracedr_filters_records
    syntax , N(string) RATIO(string) RUNIN(string) [FORCEDAT(string) FROM(string) ///
        TO(string) CHECKPOINT(string)]
    _gracedr_filters_whole, name(from) value(`"`macval(from)'"')
    local lower = r(number)
    _gracedr_filters_whole, name(to) value(`"`macval(to)'"')
    local upper = r(number)
    local has_range = !missing(`"`macval(from)'"') | !missing(`"`macval(to)'"')
    if !missing(`"`macval(checkpoint)'"') & `has_range' == 1 {
        display as error "gracedr: checkpoint() cannot be combined with from() or to()"
        exit 198
    }
    local reversed = !missing(`lower') & !missing(`upper') & inrange(`lower', `upper' + 1, 1e15)
    if `reversed' == 1 {
        display as error "gracedr: from() (`macval(from)') must not be greater than " ///
            "to() (`macval(to)')"
        exit 198
    }
    local enrolled = _N
    if !missing(`"`macval(checkpoint)'"') {
        tempfile enrolled_data
        quietly save `"`enrolled_data'"'
        _gracedr_filters_resolve, ///
            checkpoint(`"`macval(checkpoint)'"') ///
            n(`n') ///
            ratio(`ratio') ///
            runin(`runin') ///
            forcedat(`"`forcedat'"')
        local upper = r(total)
        quietly use `"`enrolled_data'"', clear
        local reached = inrange(`upper', 0, `enrolled')
        if `reached' == 0 {
            local noun = cond(`enrolled' == 1, "participant", "participants")
            display as error "gracedr: checkpoint `upper' has not been reached: " ///
                "`enrolled' `noun' randomized"
            exit 198
        }
    }
    if !missing(`lower') {
        quietly keep if inrange(seq, `lower', 1e15)
    }
    if !missing(`upper') {
        quietly keep if inrange(seq, 0, `upper')
    }
end

program define _gracedr_filters_positions, rclass
    syntax , VARNAMES(string) [VARS(string)]
    local count : word count `varnames'
    local positions ""
    if missing(`"`macval(vars)'"') {
        forvalues position = 1/`count' {
            local positions "`positions' `position'"
        }
    }
    else {
        foreach name of local vars {
            local known : list posof `"`macval(name)'"' in varnames
            if `known' == 0 {
                display as error `"gracedr: unknown balance variable `macval(name)'"'
                exit 198
            }
        }
        forvalues position = 1/`count' {
            local name : word `position' of `varnames'
            local wanted : list posof `"`macval(name)'"' in vars
            if inrange(`wanted', 1, 1e9) {
                local positions "`positions' `position'"
            }
        }
    }
    return local positions = strtrim("`positions'")
end
