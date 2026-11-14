program define gracedr_replay, rclass
    version 19
    syntax , STUDY(string) ID(string)
    preserve
    _gracedr_study setting, study(`"`macval(study)'"') name(arms)
    mata: st_local("arms", st_global("r(value)"))
    _gracedr_study check_id, id(`"`macval(id)'"')
    _gracedr_study read, study(`"`macval(study)'"') name(state)
    local generator = generator[1]
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
    tempvar position
    quietly generate long `position' = _n if id == `"`macval(id)'"'
    quietly summarize `position'
    local found = inrange(r(N), 1, 1e15)
    if `found' == 0 {
        display as error `"gracedr: participant `macval(id)' has not been randomized"'
        exit 198
    }
    local row = r(min)
    local arm_count : word count `macval(arms)'
    local probs ""
    forvalues arm = 1/`arm_count' {
        local share = string(prob`arm'[`row'], "%21.17g")
        local probs "`probs' `share'"
    }
    local state_before = rngstate[`row']
    local recorded_arm = arm[`row']
    local recorded_code = code[`row']

    _gracedr_codepool counts, study(`"`macval(study)'"') arms(`macval(arms)')
    local in_use = r(in_use)
    _gracedr_replay original, ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        arm(`"`macval(recorded_arm)'"') ///
        code(`"`macval(recorded_code)'"')
    mata: st_local("original_arm", st_global("r(arm)"))
    mata: st_local("original_code", st_global("r(code)"))
    local replayed_code ""
    if `in_use' == 1 {
        _gracedr_replay pool, ///
            study(`"`macval(study)'"') ///
            id(`"`macval(id)'"') ///
            arms(`"`macval(arms)'"')
        mata: st_local("counts", st_global("r(counts)"))
        _gracedr_rng replay, ///
            state(`state_before') ///
            probs(`"`probs'"') ///
            arms(`"`macval(arms)'"') ///
            generator(`generator') ///
            codecounts(`"`counts'"')
        local code_index = r(code_index)
        mata: st_local("replayed_arm", st_global("r(arm)"))
        _gracedr_replay pool, ///
            study(`"`macval(study)'"') ///
            id(`"`macval(id)'"') ///
            arms(`"`macval(arms)'"') ///
            arm(`"`macval(replayed_arm)'"') ///
            index(`code_index')
        mata: st_local("replayed_code", st_global("r(code)"))
    }
    else {
        _gracedr_rng replay, ///
            state(`state_before') ///
            probs(`"`probs'"') ///
            arms(`"`macval(arms)'"') ///
            generator(`generator')
        mata: st_local("replayed_arm", st_global("r(arm)"))
    }
    local same_arm = `"`macval(original_arm)'"' == `"`macval(replayed_arm)'"'
    local same_code = `"`macval(original_code)'"' == `"`macval(replayed_code)'"'
    local match = `same_arm' & `same_code'
    display as text "Participant " as result `"`macval(id)'"' as text ": arm " ///
        as result `"`macval(original_arm)'"' as text ", replayed arm " ///
        as result `"`macval(replayed_arm)'"'
    if `in_use' == 1 {
        display as text "Code " as result `"`macval(original_code)'"' ///
            as text ", replayed code " as result `"`macval(replayed_code)'"'
    }
    if `match' == 1 {
        display as text "The replay matches the recorded assignment."
    }
    else {
        display as error "The replay does not match the recorded assignment."
    }
    return local id `"`macval(id)'"'
    return local arm `"`macval(original_arm)'"'
    return local arm_replayed `"`macval(replayed_arm)'"'
    return local code `"`macval(original_code)'"'
    return local code_replayed `"`macval(replayed_code)'"'
    return scalar match = `match'
end
