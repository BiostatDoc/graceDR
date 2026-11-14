program define _gracedr_rules
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known srs blocks minimization msb breaks
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown rules subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_rules_`subcommand' `macval(0)'
end

program define _gracedr_rules_shares, rclass
    local ratio `0'
    local total = 0
    foreach value of local ratio {
        local total = `total' + `value'
    }
    local shares ""
    foreach value of local ratio {
        local share = string(`value' / `total', "%21.17g")
        local shares "`shares' `share'"
    }
    return local shares = strtrim("`shares'")
end

program define _gracedr_rules_srs, rclass
    syntax , STUDY(string) [ID(string) OPTIONS(string) BREAKS(string) PHIGH(string)]
    _gracedr_study setting, study(`"`macval(study)'"') name(ratio)
    mata: st_local("ratio", st_global("r(value)"))
    _gracedr_rules_shares `ratio'
    return local probs "`r(shares)'"
    return local phase "srs"
end

program define _gracedr_rules_blocks, rclass
    syntax , STUDY(string) [ID(string) OPTIONS(string) BREAKS(string) PHIGH(string)]
    foreach setting in arms ratio {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
    }
    foreach value of local ratio {
        local whole = `value' == round(`value')
        if `whole' == 0 {
            display as error "gracedr: blocks needs whole-number ratio values"
            exit 198
        }
    }
    local arm_count : word count `macval(arms)'
    local ratio_total = 0
    foreach value of local ratio {
        local ratio_total = `ratio_total' + `value'
    }
    local block_size = 2 * `ratio_total'
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    local enrolled = _N
    local completed = floor(`enrolled' / `block_size')
    local left_total = 0
    forvalues position = 1/`arm_count' {
        local label : word `position' of `macval(arms)'
        local quota = 2 * real(word("`ratio'", `position'))
        quietly count if arm == `"`macval(label)'"'
        local left`position' = `quota' - (r(N) - `completed' * `quota')
        local left_total = `left_total' + `left`position''
    }
    local probs ""
    forvalues position = 1/`arm_count' {
        local share = string(`left`position'' / `left_total', "%21.17g")
        local probs "`probs' `share'"
    }
    return local probs = strtrim("`probs'")
    return local phase "blocks"
end

program define _gracedr_rules_breaks, rclass
    syntax , VARNAMES(string) VARTYPES(string) [BREAKS(string)]
    local remaining `"`macval(breaks)'"'
    while !missing(ustrtrim(`"`macval(remaining)'"')) {
        gettoken piece remaining : remaining, parse("|")
        if `"`macval(piece)'"' == "|" {
            continue
        }
        local colon = strpos(`"`macval(piece)'"', ":")
        local name = ustrtrim(substr(`"`macval(piece)'"', 1, `colon' - 1))
        local numbers = ustrtrim(substr(`"`macval(piece)'"', `colon' + 1, .))
        if `colon' == 0 | missing(`"`macval(numbers)'"') {
            display as error "gracedr: breaks() must look like name: number number"
            exit 198
        }
        local first = 1
        local previous = 0
        foreach cut of local numbers {
            local value = real(`"`macval(cut)'"')
            if missing(`value') {
                display as error "gracedr: breaks() must look like name: number number"
                exit 198
            }
            local decreasing = `first' == 0 & inrange(`value', -1e300, `previous')
            if `decreasing' == 1 {
                display as error "gracedr: breaks() numbers must strictly increase"
                exit 198
            }
            local first = 0
            local previous = `value'
        }
        local position : list posof `"`macval(name)'"' in varnames
        if `position' == 0 {
            display as error `"gracedr: breaks() names an unknown balance variable `macval(name)'"'
            exit 198
        }
        local type : word `position' of `vartypes'
        if "`type'" == "categorical" {
            display as error `"gracedr: breaks() names a categorical variable `macval(name)'"'
            exit 198
        }
        return local breaks`position' "`numbers'"
    }
end

program define _gracedr_rules_minimization
    syntax , STUDY(string) [ID(string) OPTIONS(string) BREAKS(string) PHIGH(string)]
    _gracedr_rules_balanced, ///
        rule(minimization) ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        options(`"`macval(options)'"') ///
        breaks(`"`macval(breaks)'"') ///
        phigh(`"`macval(phigh)'"')
end

program define _gracedr_rules_msb
    syntax , STUDY(string) [ID(string) OPTIONS(string) BREAKS(string) PHIGH(string)]
    _gracedr_rules_balanced, ///
        rule(msb) ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        options(`"`macval(options)'"')
end

program define _gracedr_rules_balanced, rclass
    syntax , RULE(string) STUDY(string) [ID(string) OPTIONS(string) BREAKS(string) ///
        PHIGH(string)]
    if missing(`"`macval(id)'"') {
        display as error "gracedr: the participant values need id()"
        exit 198
    }
    if missing(`"`macval(phigh)'"') {
        local phigh 0.8
    }
    local high = real(`"`macval(phigh)'"')
    local valid_high = !missing(`high') & inrange(`high', 0.0000000001, 0.9999999999)
    if `valid_high' == 0 {
        display as error "gracedr: phigh() must be a number greater than 0 and less than 1"
        exit 198
    }
    preserve
    _gracedr_values parse, ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        options(`"`macval(options)'"')
    local variable_count = r(nvars)
    mata: st_local("varnames", st_global("r(varnames)"))
    mata: st_local("vartypes", st_global("r(vartypes)"))
    mata: st_local("missing_names", st_global("r(missingvars)"))
    forvalues position = 1/`variable_count' {
        mata: st_local("cleaned`position'", st_global("r(value`position')"))
        local number`position' = string(r(number`position'), "%21.17g")
    }
    foreach setting in arms ratio weights pstar xi {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
    }
    forvalues position = 1/`variable_count' {
        _gracedr_study setting, study(`"`macval(study)'"') name(levels`position')
        mata: st_local("levels`position'", st_global("r(value)"))
    }
    _gracedr_rules_breaks, ///
        varnames(`macval(varnames)') ///
        vartypes(`macval(vartypes)') ///
        breaks(`"`macval(breaks)'"')
    forvalues position = 1/`variable_count' {
        local cuts`position' "`r(breaks`position')'"
    }
    _gracedr_rules_shares `ratio'
    local shares "`r(shares)'"
    local arm_count : word count `macval(arms)'
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    return local missingvars = strtrim(`"`macval(missing_names)'"')
    if "`rule'" == "msb" {
        local votes ""
        forvalues position = 1/`variable_count' {
            local name : word `position' of `varnames'
            local type : word `position' of `vartypes'
            _gracedr_balance vote, ///
                name(`name') ///
                type(`type') ///
                arms(`macval(arms)') ///
                pstar(`macval(pstar)') ///
                levels(`macval(levels`position')') ///
                value(`"`macval(cleaned`position')'"') ///
                number(`number`position'')
            local votes "`votes' `r(vote)'"
        }
        local votes = strtrim("`votes'")
        _gracedr_votes tally, votes(`votes') weights(`macval(weights)') arms(`arm_count')
        local winner = r(winner)
        _gracedr_votes tilt, base(`shares') winner(`winner') xi(`macval(xi)')
        mata: st_local("tilted", st_global("r(probs)"))
        return local probs = strtrim(`"`macval(tilted)'"')
        return local phase "msb"
        return local votes "`votes'"
        return scalar winner = `winner'
        exit
    }
    forvalues arm = 1/`arm_count' {
        local share`arm' = real(word("`shares'", `arm'))
    }
    local used = 0
    forvalues position = 1/`variable_count' {
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        if "`type'" == "continuous" & missing("`cuts`position''") {
            display as error "gracedr: minimization needs breaks() for the continuous " ///
                "variable `name'"
            exit 198
        }
        local present = !missing(`"`macval(cleaned`position')'"')
        if "`type'" == "continuous" {
            local present = !missing(real("`number`position''"))
        }
        if `present' == 1 {
            _gracedr_balance row, ///
                name(`name') ///
                type(`type') ///
                arms(`macval(arms)') ///
                level(`"`macval(cleaned`position')'"') ///
                number(`number`position'') ///
                breaks(`cuts`position'')
            local used = `used' + 1
            local weight`used' = real(word(`"`macval(weights)'"', `position'))
            forvalues arm = 1/`arm_count' {
                local count`used'_`arm' = real(word("`r(counts)'", `arm'))
            }
        }
    }
    local smallest = 1e300
    forvalues candidate = 1/`arm_count' {
        local imbalance`candidate' = 0
        forvalues row = 1/`used' {
            local low = 1e300
            local top = -1e300
            forvalues arm = 1/`arm_count' {
                local added = `arm' == `candidate'
                local scaled = (`count`row'_`arm'' + `added') / `share`arm''
                local low = min(`low', `scaled')
                local top = max(`top', `scaled')
            }
            local imbalance`candidate' = `imbalance`candidate'' + `weight`row'' * (`top' - `low')
        }
        local smallest = min(`smallest', `imbalance`candidate'')
    }
    local best_count = 0
    local rest_share = 0
    forvalues arm = 1/`arm_count' {
        local gap = abs(`imbalance`arm'' - `smallest')
        local best`arm' = inrange(`gap', 0, 0.000000000999999999)
        local best_count = `best_count' + `best`arm''
        local rest_share = `rest_share' + `share`arm'' * (`best`arm'' == 0)
    }
    local probs ""
    forvalues arm = 1/`arm_count' {
        local value = `share`arm''
        if `best_count' < `arm_count' & `best`arm'' == 1 {
            local value = `high' / `best_count'
        }
        else if `best_count' < `arm_count' {
            local value = (1 - `high') * `share`arm'' / `rest_share'
        }
        local text = string(`value', "%21.17g")
        local probs "`probs' `text'"
    }
    return local probs = strtrim("`probs'")
    return local phase "minimization"
end
