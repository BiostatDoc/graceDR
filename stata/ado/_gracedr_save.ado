*! version 1.0.0  15nov2026
program define _gracedr_save
    version 19
    syntax , STUDY(string) STEP(string) [WRITTEN(string) ID(string) ARM(string) ///
        CODE(string) STATE(string) FROM(string) ACTION(string) OLD(string) ///
        OLDCODE(string) REASON(string)]
    if missing("`action'") {
        local action randomize
    }
    _gracedr_study extension, study(`"`macval(study)'"')
    local extension "`r(extension)'"
    if "`step'" == "audit" {
        capture _gracedr_study append_audit, ///
            study(`"`macval(study)'"') ///
            action(`action') ///
            id(`"`macval(id)'"') ///
            old(`"`macval(old)'"') ///
            new(`"`macval(arm)'"') ///
            oldcode(`"`macval(oldcode)'"') ///
            newcode(`"`macval(code)'"') ///
            reason(`"`macval(reason)'"')
    }
    else if "`step'" == "state" {
        capture _gracedr_rng commit, ///
            study(`"`macval(study)'"') ///
            state(`state') ///
            from(`from')
    }
    else {
        capture _gracedr_study write, study(`"`macval(study)'"') name(`step')
    }
    local failure = _rc
    if `failure' == 0 {
        c_local written "`written' `step'.`extension'"
        exit
    }
    display as error `"gracedr: could not write `step'.`extension' in `macval(study)'"'
    local files = strtrim("`written'")
    if missing("`files'") {
        display as error "gracedr: no study files were changed"
    }
    else {
        display as error "gracedr: files already written: `files'; " ///
            "the random number state was not changed"
        display as error "gracedr: fix the cause and check participants, codes and audit " ///
            "before continuing"
    }
    exit `failure'
end
