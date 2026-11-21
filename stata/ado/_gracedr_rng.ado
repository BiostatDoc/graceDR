*! version 1.0.0  15nov2026
program define _gracedr_rng
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known init draw replay commit check_seed
    local is_known : list subcommand in known
    if `is_known' == 0 | missing("`subcommand'") {
        display as error "gracedr: unknown rng subcommand `subcommand'"
        exit 198
    }
    _gracedr_rng_`subcommand' `macval(0)'
end

program define _gracedr_rng_check_seed
    syntax , SEED(string)
    local whole = regexm(`"`seed'"', "^[0-9]+$")
    if `whole' == 1 {
        local whole = inrange(real(`"`seed'"'), 0, 2147483647)
    }
    if `whole' == 0 {
        display as error "gracedr: seed() must be a whole number from 0 to 2147483647"
        exit 198
    }
end

program define _gracedr_rng_init
    syntax , STUDY(string) SEED(string)
    _gracedr_rng_check_seed, seed(`"`seed'"')
    _gracedr_study exists, study(`"`macval(study)'"')
    if r(exists) == 0 {
        display as error `"gracedr: no study found in `macval(study)'"'
        exit 601
    }
    _gracedr_study has, study(`"`macval(study)'"') name(state)
    if r(has) == 1 {
        display as error `"gracedr: state.dta already exists in `macval(study)'"'
        exit 602
    }
    local user_rng = c(rng)
    local user_state = c(rngstate)
    set rng mt64
    set seed `seed'
    local state = c(rngstate)
    set rng `user_rng'
    set rngstate `user_state'
    preserve
    _gracedr_study empty, name(state)
    quietly set obs 1
    mata: st_sstore(1, "state", st_local("state"))
    quietly replace seed = `seed'
    quietly replace generator = "mt64"
    quietly replace format_version = 1
    _gracedr_study write, study(`"`macval(study)'"') name(state)
    restore
end

program define _gracedr_rng_commit
    syntax , STUDY(string) STATE(string) [FROM(string)]
    local well_formed = regexm(`"`macval(state)'"', "^[0-9A-Za-z]+$")
    if `well_formed' == 0 {
        display as error "gracedr: state is not a valid random number state"
        exit 198
    }
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(state)
    if _N == 1 {
        local current = state[1]
        local stale = !missing("`from'") & ("`current'" == "`from'") == 0
        if `stale' == 1 {
            display as error "gracedr: state.dta changed since the draw"
            exit 198
        }
        mata: st_sstore(1, "state", st_local("state"))
        _gracedr_study write, study(`"`macval(study)'"') name(state)
        restore
    }
    else {
        display as error `"gracedr: state.dta must have exactly one row in `macval(study)'"'
        exit 198
    }
end

program define _gracedr_rng_draw, rclass
    syntax , STUDY(string) PROBS(string) ARMS(string) [NOSTORE CODECOUNTS(string)]
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(state)
    if _N == 1 {
        local state = state[1]
        local generator = generator[1]
        _gracedr_rng_pick, ///
            state(`"`macval(state)'"') ///
            generator(`"`macval(generator)'"') ///
            probs(`"`macval(probs)'"') ///
            arms(`"`macval(arms)'"') ///
            codecounts(`"`macval(codecounts)'"')
        mata: st_local("arm", st_global("r(arm)"))
        mata: st_local("new_state", st_global("r(new_state)"))
        local code_index = r(code_index)
        if missing("`nostore'") {
            mata: st_sstore(1, "state", st_local("new_state"))
            _gracedr_study write, study(`"`macval(study)'"') name(state)
        }
        restore
        return local arm `"`arm'"'
        return local state_before `"`macval(state)'"'
        if !missing(`code_index') {
            return scalar code_index = `code_index'
        }
        if !missing("`nostore'") {
            return local new_state `"`new_state'"'
        }
    }
    else {
        display as error `"gracedr: state.dta must have exactly one row in `macval(study)'"'
        exit 198
    }
end

program define _gracedr_rng_replay, rclass
    syntax , STATE(string) PROBS(string) ARMS(string) [GENERATOR(string) CODECOUNTS(string)]
    if missing("`macval(generator)'") {
        local generator mt64
    }
    _gracedr_rng_pick, ///
        state(`"`macval(state)'"') ///
        generator(`"`macval(generator)'"') ///
        probs(`"`macval(probs)'"') ///
        arms(`"`macval(arms)'"') ///
        codecounts(`"`macval(codecounts)'"')
    mata: st_local("replayed_arm", st_global("r(arm)"))
    local code_index = r(code_index)
    return local arm `"`macval(replayed_arm)'"'
    if !missing(`code_index') {
        return scalar code_index = `code_index'
    }
end

program define _gracedr_rng_pick, rclass
    syntax , STATE(string) GENERATOR(string) PROBS(string) ARMS(string) [CODECOUNTS(string)]
    local count : word count `macval(probs)'
    local arm_count : word count `macval(arms)'
    local consistent = inrange(`count', 1, 1000) & `count' == `arm_count'
    if `consistent' == 0 {
        display as error "gracedr: probs() and arms() must have the same number of items"
        exit 198
    }
    local total = 0
    forvalues position = 1/`count' {
        local value = real(word(`"`macval(probs)'"', `position'))
        if !inrange(`value', 0, 1e300) {
            display as error "gracedr: probs() must be numbers that are not negative"
            exit 198
        }
        local total = `total' + `value'
    }
    if `total' == 0 {
        display as error "gracedr: probs() must add up to more than zero"
        exit 198
    }
    local with_codes = !missing(`"`macval(codecounts)'"')
    if `with_codes' == 1 {
        local code_words : word count `macval(codecounts)'
        local counts_ok = `code_words' == `count'
        foreach value of local codecounts {
            local number = real(`"`value'"')
            local counts_ok = `counts_ok' & !missing(`number')
            if `counts_ok' == 1 {
                local counts_ok = inrange(`number', 0, 1e15) & `number' == floor(`number')
            }
        }
        if `counts_ok' == 0 {
            display as error "gracedr: codecounts() must be one whole number per arm"
            exit 198
        }
    }
    local well_formed = regexm(`"`macval(state)'"', "^[0-9A-Za-z]+$")
    if `well_formed' == 1 {
        local well_formed = regexm(`"`macval(generator)'"', "^[0-9A-Za-z]+$")
    }
    if `well_formed' == 0 {
        display as error "gracedr: state is not a valid random number state"
        exit 198
    }
    local partial = 0
    forvalues position = 1/`count' {
        local partial = `partial' + real(word(`"`macval(probs)'"', `position'))
        local cumulative`position' = `partial' / `total'
    }
    local user_rng = c(rng)
    local user_state = c(rngstate)
    capture set rng `macval(generator)'
    local failure = _rc
    if `failure' == 0 {
        capture set rngstate `macval(state)'
        local failure = _rc
    }
    if `failure' == 0 {
        local uniform = runiform()
        if `with_codes' == 1 {
            local code_uniform = runiform()
        }
        local new_state = c(rngstate)
    }
    set rng `user_rng'
    set rngstate `user_state'
    if `failure' == 0 {
        local chosen = 0
        forvalues position = 1/`count' {
            local below = !missing(`uniform') & `uniform' < `cumulative`position''
            if `chosen' == 0 & `below' == 1 {
                local chosen = `position'
            }
        }
        local arm : word `chosen' of `macval(arms)'
        if `with_codes' == 1 {
            local pool : word `chosen' of `codecounts'
            if `pool' == 0 {
                display as error `"gracedr: no unused codes are left for arm `macval(arm)'"'
                exit 198
            }
            return scalar code_index = floor(`code_uniform' * `pool') + 1
        }
        return local arm `"`arm'"'
        return local new_state `"`new_state'"'
    }
    else {
        display as error "gracedr: state is not a valid random number state"
        exit 198
    }
end
