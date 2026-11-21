*! version 1.0.0  15nov2026
program define gracedr_override, rclass
    version 19
    syntax , STUDY(string) ID(string) ARM(string) REASON(string)
    preserve
    _gracedr_study setting, study(`"`macval(study)'"') name(arms)
    mata: st_local("arms", st_global("r(value)"))
    _gracedr_study check_id, id(`"`macval(id)'"')
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    quietly count if id == `"`macval(id)'"'
    local found = inrange(r(N), 1, 1e15)
    if `found' == 0 {
        display as error `"gracedr: participant `macval(id)' has not been randomized"'
        exit 198
    }
    local known : list posof `"`macval(arm)'"' in arms
    if `known' == 0 {
        display as error `"gracedr: unknown arm `macval(arm)'"'
        exit 198
    }
    tempvar position
    quietly generate long `position' = _n if id == `"`macval(id)'"'
    quietly summarize `position'
    local row = r(min)
    quietly drop `position'
    local old_arm = arm[`row']
    local old_code = code[`row']
    if `"`macval(old_arm)'"' == `"`macval(arm)'"' {
        display as error `"gracedr: participant `macval(id)' is already in arm `macval(arm)'"'
        exit 198
    }
    if missing(ustrtrim(`"`macval(reason)'"')) {
        display as error "gracedr: reason() must not be empty"
        exit 198
    }

    _gracedr_codepool counts, study(`"`macval(study)'"') arms(`macval(arms)')
    local in_use = r(in_use)
    mata: st_local("code_counts", st_global("r(counts)"))
    local code ""
    if `in_use' == 1 {
        _gracedr_override_draw, ///
            study(`"`macval(study)'"') ///
            arms(`"`macval(arms)'"') ///
            arm(`"`macval(arm)'"') ///
            counts(`"`code_counts'"')
        local code_index = r(code_index)
        mata: st_local("state_before", st_global("r(state_before)"))
        mata: st_local("new_state", st_global("r(new_state)"))
        _gracedr_study read, study(`"`macval(study)'"') name(codes)
        _gracedr_codepool void, code(`"`macval(old_code)'"')
        _gracedr_codepool claim, ///
            arm(`"`macval(arm)'"') ///
            index(`code_index') ///
            id(`"`macval(id)'"')
        mata: st_local("code", st_global("r(code)"))
        _gracedr_study read, study(`"`macval(study)'"') name(participants)
    }
    mata: st_sstore(`row', "arm", st_local("arm"))
    mata: st_sstore(`row', "code", st_local("code"))

    local written ""
    _gracedr_save, study(`"`macval(study)'"') step(participants) written(`"`written'"')
    if `in_use' == 1 {
        _gracedr_study read, study(`"`macval(study)'"') name(codes)
        _gracedr_codepool void, code(`"`macval(old_code)'"')
        _gracedr_codepool claim, ///
            arm(`"`macval(arm)'"') ///
            index(`code_index') ///
            id(`"`macval(id)'"')
        _gracedr_save, study(`"`macval(study)'"') step(codes) written(`"`written'"')
    }
    _gracedr_save, ///
        study(`"`macval(study)'"') ///
        step(audit) ///
        action(override) ///
        id(`"`macval(id)'"') ///
        old(`"`macval(old_arm)'"') ///
        arm(`"`macval(arm)'"') ///
        oldcode(`"`macval(old_code)'"') ///
        code(`"`macval(code)'"') ///
        reason(`"`macval(reason)'"') ///
        written(`"`written'"')
    if `in_use' == 1 {
        _gracedr_save, ///
            study(`"`macval(study)'"') ///
            step(state) ///
            state(`new_state') ///
            from(`state_before') ///
            written(`"`written'"')
    }

    display as text "Participant " as result `"`macval(id)'"' as text " changed from arm " ///
        as result `"`macval(old_arm)'"' as text " to arm " as result `"`macval(arm)'"'
    if `in_use' == 1 {
        display as text "Code " as result `"`macval(old_code)'"' as text " voided, new code " ///
            as result `"`macval(code)'"'
    }
    return local id `"`macval(id)'"'
    return local old_arm `"`macval(old_arm)'"'
    return local arm `"`macval(arm)'"'
    return local old_code `"`macval(old_code)'"'
    return local code `"`macval(code)'"'
end

program define _gracedr_override_draw, rclass
    syntax , STUDY(string) ARMS(string) ARM(string) COUNTS(string)
    local arm_count : word count `macval(arms)'
    local probs ""
    forvalues position = 1/`arm_count' {
        local label : word `position' of `macval(arms)'
        local share = `"`macval(label)'"' == `"`macval(arm)'"'
        local probs "`probs' `share'"
    }
    _gracedr_rng draw, ///
        study(`"`macval(study)'"') ///
        probs(`"`probs'"') ///
        arms(`"`macval(arms)'"') ///
        codecounts(`"`counts'"') ///
        nostore
    mata: st_local("state_before", st_global("r(state_before)"))
    mata: st_local("new_state", st_global("r(new_state)"))
    return scalar code_index = r(code_index)
    return local state_before `"`macval(state_before)'"'
    return local new_state `"`macval(new_state)'"'
end
