program define gracedr_randomize, rclass
    version 19
    syntax , STUDY(string) ID(string) [GRAPHS *]
    preserve
    foreach setting in arms nvars varnames vartypes {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
    }
    _gracedr_randomize_check_new, study(`"`macval(study)'"') id(`"`macval(id)'"')
    _gracedr_mmsb probs, ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        options(`"`macval(options)'"')
    mata: st_local("probs", st_global("r(probs)"))
    mata: st_local("phase", st_global("r(phase)"))
    mata: st_local("missing_names", st_global("r(missingvars)"))
    forvalues position = 1/`nvars' {
        mata: st_local("value`position'", st_global("r(value`position')"))
        local number`position' = string(r(number`position'), "%21.17g")
    }
    _gracedr_codepool counts, study(`"`macval(study)'"') arms(`macval(arms)')
    local in_use = r(in_use)
    mata: st_local("code_counts", st_global("r(counts)"))
    _gracedr_rng draw, ///
        study(`"`macval(study)'"') ///
        probs(`"`probs'"') ///
        arms(`"`macval(arms)'"') ///
        codecounts(`"`code_counts'"') ///
        nostore
    mata: st_local("arm", st_global("r(arm)"))
    mata: st_local("state_before", st_global("r(state_before)"))
    mata: st_local("new_state", st_global("r(new_state)"))
    local code_index = r(code_index)

    local code ""
    if `in_use' == 1 {
        _gracedr_study read, study(`"`macval(study)'"') name(codes)
        _gracedr_codepool claim, ///
            arm(`"`macval(arm)'"') ///
            index(`code_index') ///
            id(`"`macval(id)'"')
        mata: st_local("code", st_global("r(code)"))
    }
    _gracedr_utc
    local stamp = r(time)
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    local row = _N + 1
    quietly set obs `row'
    quietly replace seq = `row' in `row'
    mata: st_sstore(`row', "id", st_local("id"))
    forvalues position = 1/`nvars' {
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        if "`type'" == "categorical" {
            mata: st_sstore(`row', "`name'", st_local("value`position'"))
        }
        else {
            quietly replace `name' = `number`position'' in `row'
        }
    }
    mata: st_sstore(`row', "arm", st_local("arm"))
    mata: st_sstore(`row', "code", st_local("code"))
    local arm_count : word count `macval(arms)'
    forvalues position = 1/`arm_count' {
        local share = real(word("`probs'", `position'))
        quietly replace prob`position' = `share' in `row'
    }
    mata: st_sstore(`row', "phase", st_local("phase"))
    mata: st_sstore(`row', "rngstate", st_local("state_before"))
    quietly replace time = `stamp' in `row'

    local written ""
    _gracedr_save, study(`"`macval(study)'"') step(participants) written(`"`written'"')
    if `in_use' == 1 {
        _gracedr_study read, study(`"`macval(study)'"') name(codes)
        _gracedr_codepool claim, ///
            arm(`"`macval(arm)'"') ///
            index(`code_index') ///
            id(`"`macval(id)'"')
        _gracedr_save, study(`"`macval(study)'"') step(codes) written(`"`written'"')
    }
    _gracedr_save, ///
        study(`"`macval(study)'"') ///
        step(audit) ///
        id(`"`macval(id)'"') ///
        arm(`"`macval(arm)'"') ///
        code(`"`macval(code)'"') ///
        written(`"`written'"')
    _gracedr_save, ///
        study(`"`macval(study)'"') ///
        step(state) ///
        state(`new_state') ///
        from(`state_before') ///
        written(`"`written'"')

    if !missing(`"`macval(missing_names)'"') {
        display as text "gracedr: warning: missing value for `macval(missing_names)'"
    }
    display as text "Participant " as result `"`macval(id)'"' as text " randomized to arm " ///
        as result `"`macval(arm)'"'
    if !missing(`"`macval(code)'"') {
        display as text "Treatment code: " as result `"`macval(code)'"'
    }
    _gracedr_tables groupsize, study(`"`macval(study)'"')
    if !missing("`graphs'") {
        _gracedr_graphs imbalance, study(`"`macval(study)'"')
        _gracedr_graphs smd, study(`"`macval(study)'"')
    }
    return local id `"`macval(id)'"'
    return local arm `"`macval(arm)'"'
    return local code `"`macval(code)'"'
    return local phase "`phase'"
    return local probs "`probs'"
    return local missingvars "`macval(missing_names)'"
    return scalar n_randomized = `row'
end

program define _gracedr_randomize_check_new
    syntax , STUDY(string) ID(string)
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    quietly count if id == `"`macval(id)'"'
    local repeated = inrange(r(N), 1, 1e15)
    if `repeated' == 1 {
        display as error `"gracedr: participant `macval(id)' has already been randomized"'
        exit 198
    }
end
