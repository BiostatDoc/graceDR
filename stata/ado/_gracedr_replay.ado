*! version 1.0.0  15nov2026
program define _gracedr_replay
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known original pool
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown replay subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_replay_`subcommand' `macval(0)'
end

program define _gracedr_replay_original, rclass
    syntax , STUDY(string) ID(string) ARM(string) [CODE(string)]
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(audit)
    local original_arm `"`macval(arm)'"'
    local original_code `"`macval(code)'"'
    local rows = _N
    local found = 0
    forvalues row = 1/`rows' {
        local first = action[`row'] == "override" & id[`row'] == `"`macval(id)'"'
        if `first' == 1 & `found' == 0 {
            local found = `row'
            local original_arm = old[`row']
            local original_code = old_code[`row']
        }
    }
    return local arm `"`macval(original_arm)'"'
    return local code `"`macval(original_code)'"'
end

program define _gracedr_replay_pool, rclass
    syntax , STUDY(string) ID(string) ARMS(string) [ARM(string) INDEX(integer 0)]
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(audit)
    quietly generate long position = _n
    quietly generate str244 code = new_code
    quietly summarize position if action == "randomize" & id == `"`macval(id)'"'
    local moment = r(min)
    quietly keep if inrange(position, 1, `moment' - 1) & !missing(code)
    quietly keep code
    tempfile drawn
    quietly save `"`drawn'"'
    _gracedr_study read, study(`"`macval(study)'"') name(codes)
    quietly generate long order = _n
    quietly merge 1:1 code using `"`drawn'"', keep(master) nogenerate
    quietly sort order
    if `index' == 0 {
        local counts ""
        local arm_count : word count `macval(arms)'
        forvalues position = 1/`arm_count' {
            local label : word `position' of `macval(arms)'
            quietly count if arm == `"`macval(label)'"'
            local counts "`counts' `r(N)'"
        }
        return local counts = strtrim("`counts'")
    }
    else {
        quietly keep if arm == `"`macval(arm)'"'
        local code = code[`index']
        return local code `"`macval(code)'"'
    }
end
