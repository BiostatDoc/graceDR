program define gracedr_audit, rclass
    version 19
    syntax , STUDY(string)
    preserve
    _gracedr_study read, study(`"`macval(study)'"') name(audit)
    local rows = _N
    display as text "Audit log: " as result "`rows'" as text " rows"
    if inrange(`rows', 1, 1e15) {
        format time %tc
        list time action id old new old_code new_code reason, ///
            noobs ///
            separator(0) ///
            abbreviate(20)
    }
    return scalar rows = `rows'
end
