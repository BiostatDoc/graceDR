program define _gracedr_codepool
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known counts claim void
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown codepool subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_codepool_`subcommand' `macval(0)'
end

program define _gracedr_codepool_counts, rclass
    syntax , STUDY(string) ARMS(string asis)
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(codes)
    local in_use = inrange(_N, 1, 1e15)
    local counts ""
    if `in_use' == 1 {
        local arm_count : word count `macval(arms)'
        forvalues arm = 1/`arm_count' {
            local label : word `arm' of `macval(arms)'
            quietly count if arm == `"`macval(label)'"' & status == "unused"
            local counts "`counts' `r(N)'"
        }
    }
    return scalar in_use = `in_use'
    return local counts = strtrim("`counts'")
end

program define _gracedr_codepool_claim, rclass
    syntax , ARM(string) INDEX(integer) ID(string)
    local rows = _N
    local seen = 0
    local found = 0
    forvalues row = 1/`rows' {
        local match = arm[`row'] == `"`macval(arm)'"' & status[`row'] == "unused"
        if `match' == 1 {
            local seen = `seen' + 1
            if `seen' == `index' {
                local found = `row'
            }
        }
    }
    if `found' == 0 {
        display as error `"gracedr: no unused code number `index' for arm `macval(arm)'"'
        exit 198
    }
    quietly replace status = "used" in `found'
    mata: st_sstore(`found', "id", st_local("id"))
    local code = code[`found']
    return local code `"`macval(code)'"'
end

program define _gracedr_codepool_void
    syntax , CODE(string)
    local rows = _N
    local found = 0
    forvalues row = 1/`rows' {
        local match = code[`row'] == `"`macval(code)'"' & status[`row'] == "used"
        if `match' == 1 {
            local found = `row'
        }
    }
    if `found' == 0 {
        display as error `"gracedr: code `macval(code)' is not a used code, "' ///
            "so it cannot be voided"
        exit 198
    }
    quietly replace status = "voided" in `found'
end
