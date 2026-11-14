program define _gracedr_mmsb
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known probs
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown mmsb subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_mmsb_`subcommand' `macval(0)'
end

program define _gracedr_mmsb_probs, rclass
    syntax , STUDY(string) ID(string) [OPTIONS(string)]
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
        return local value`position' `"`macval(cleaned`position')'"'
        return scalar number`position' = r(number`position')
    }
    foreach setting in n arms ratio weights pstar xi runin runinmethod forcedat sizebound {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
    }
    forvalues position = 1/`variable_count' {
        _gracedr_study setting, study(`"`macval(study)'"') name(levels`position')
        mata: st_local("levels`position'", st_global("r(value)"))
    }
    foreach setting in n runin sizebound pstar xi {
        local number = real(`"`macval(`setting')'"')
        if missing(`number') {
            display as error "gracedr: design.dta setting `setting' is not a number"
            exit 198
        }
    }
    local arm_count : word count `macval(arms)'
    return local missingvars = strtrim(`"`macval(missing_names)'"')

    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    local total = _N
    local sequence = `total' + 1
    local full = inrange(`sequence', `macval(n)' + 1, 1e15)
    if `full' == 1 {
        display as error "gracedr: the study already has `macval(n)' participants"
        exit 198
    }
    local counts ""
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        quietly count if arm == `"`macval(label)'"'
        local count`arm' = r(N)
        local counts "`counts' `count`arm''"
    }

    if missing(`"`macval(forcedat)'"') {
        _gracedr_design checkpoints, ///
            n(`macval(n)') ///
            ratio(`macval(ratio)') ///
            runin(`macval(runin)')
    }
    else {
        _gracedr_design checkpoints, ///
            n(`macval(n)') ///
            ratio(`macval(ratio)') ///
            runin(`macval(runin)') ///
            forcedat(`macval(forcedat)')
    }
    local checkpoint = 0
    local checkpoint_rows = _N
    forvalues row = 1/`checkpoint_rows' {
        local row_size = n[`row']
        local reached = inrange(`row_size', `sequence', 1e15)
        if `reached' == 1 & `checkpoint' == 0 {
            local checkpoint = `row'
        }
    }
    local checkpoint_total = n[`checkpoint']
    local remaining = `checkpoint_total' - `total'
    local base_list ""
    local largest_base = 0
    forvalues arm = 1/`arm_count' {
        local target = target`arm'[`checkpoint']
        local short = max(`target' - `count`arm'', 0)
        local base`arm' = `short' / `remaining'
        local largest_base = max(`largest_base', `base`arm'')
        local text = string(`base`arm'', "%21.17g")
        local base_list "`base_list' `text'"
    }
    local in_run_in = `sequence' <= `macval(runin)'
    local forced = inrange(`largest_base', 1 - 0.000000000001, 1e300)
    return local votes ""
    return scalar winner = 0
    if `forced' == 1 {
        return local probs = strtrim("`base_list'")
        if `in_run_in' == 1 {
            return local phase "runin"
        }
        else {
            return local phase "quota"
        }
        exit
    }
    if `in_run_in' == 1 & "`macval(runinmethod)'" == "rar" {
        return local probs = strtrim("`base_list'")
        return local phase "runin"
        exit
    }

    if `in_run_in' == 0 {
        local ratio_total = 0
        foreach value of local ratio {
            local ratio_total = `ratio_total' + `value'
        }
        local behind_total = 0
        local allowed_total = 0
        local any_blocked = 0
        local forced_list ""
        local allowed_list ""
        local tolerance = 0.000000001
        forvalues arm = 1/`arm_count' {
            local proportion = real(word("`macval(ratio)'", `arm')) / `ratio_total'
            local gap = `count`arm'' - `proportion' * `total'
            local behind = inrange(`gap', 0 - 1e300, 0 - `macval(sizebound)' + `tolerance')
            local blocked = inrange(`gap', `macval(sizebound)' - `tolerance', 1e300)
            local pull = 0
            if `behind' == 1 {
                local pull = 0 - `gap'
            }
            local behind_total = `behind_total' + `behind'
            local forced_list "`forced_list' `pull'"
            local allowed = `base`arm''
            if `blocked' == 1 {
                local allowed = 0
                local any_blocked = `any_blocked' | !inrange(`base`arm'', 0, 0)
            }
            local allowed_total = `allowed_total' + `allowed'
            local allowed_list "`allowed_list' `allowed'"
        }
        local bounded = 0
        local bound_list ""
        local pull_total = 0
        foreach value of local forced_list {
            local pull_total = `pull_total' + `value'
        }
        if inrange(`behind_total', 1, 1e9) {
            local bounded = 1
            foreach value of local forced_list {
                local share = `value' / `pull_total'
                local text = string(`share', "%21.17g")
                local bound_list "`bound_list' `text'"
            }
        }
        else if `any_blocked' == 1 & !inrange(`allowed_total', 0, 0) {
            local bounded = 1
            foreach value of local allowed_list {
                local share = `value' / `allowed_total'
                local text = string(`share', "%21.17g")
                local bound_list "`bound_list' `text'"
            }
        }
        if `bounded' == 1 {
            return local probs = strtrim("`bound_list'")
            return local phase "bound"
            exit
        }
    }

    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    local votes ""
    local weight_list ""
    forvalues position = 1/`variable_count' {
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        local weight : word `position' of `macval(weights)'
        local weight_list "`weight_list' `weight'"
        if "`type'" == "categorical" {
            local level_count : word count `macval(levels`position')'
            local table ""
            forvalues level = 1/`level_count' {
                local level_text : word `level' of `macval(levels`position')'
                forvalues arm = 1/`arm_count' {
                    local label : word `arm' of `macval(arms)'
                    quietly count if `name' == `"`macval(level_text)'"' & ///
                        arm == `"`macval(label)'"'
                    local table "`table' `r(N)'"
                }
            }
            local row_index = 0
            if !missing(`"`macval(cleaned`position')'"') {
                local row_index : list posof `"`macval(cleaned`position')'"' in levels`position'
            }
            _gracedr_votes categorical, ///
                table(`table') ///
                arms(`arm_count') ///
                row(`row_index') ///
                pstar(`macval(pstar)')
        }
        else {
            local n_text ""
            local sum_text ""
            local square_text ""
            tempvar square
            quietly generate double `square' = `name' * `name'
            forvalues arm = 1/`arm_count' {
                local label : word `arm' of `macval(arms)'
                quietly summarize `name' if arm == `"`macval(label)'"'
                local piece_count = r(N)
                local sum_piece = string(r(sum), "%21.17g")
                if `piece_count' == 0 {
                    local sum_piece = 0
                }
                quietly summarize `square' if arm == `"`macval(label)'"'
                local square_piece = string(r(sum), "%21.17g")
                if `piece_count' == 0 {
                    local square_piece = 0
                }
                local n_text "`n_text' `piece_count'"
                local sum_text "`sum_text' `sum_piece'"
                local square_text "`square_text' `square_piece'"
            }
            _gracedr_votes continuous, ///
                n(`n_text') ///
                sum(`sum_text') ///
                ss(`square_text') ///
                x(`number`position'') ///
                pstar(`macval(pstar)')
        }
        local vote`position' = r(vote)
        local votes "`votes' `vote`position''"
    }
    if `in_run_in' == 0 {
        _gracedr_votes size, n(`counts') ratio(`macval(ratio)')
        local votes "`votes' `r(vote)'"
        local weight_list "`weight_list' 1"
    }
    local votes = strtrim("`votes'")
    _gracedr_votes tally, votes(`votes') weights(`weight_list') arms(`arm_count')
    local winner = r(winner)
    _gracedr_votes tilt, base(`base_list') winner(`winner') xi(`macval(xi)')
    mata: st_local("tilted", st_global("r(probs)"))
    return local probs = strtrim(`"`macval(tilted)'"')
    return local votes "`votes'"
    return scalar winner = `winner'
    if `in_run_in' == 1 {
        return local phase "runin"
    }
    else if `winner' == 0 {
        return local phase "msb-random"
    }
    else {
        return local phase "msb-biased"
    }
end
