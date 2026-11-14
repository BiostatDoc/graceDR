program define _gracedr_save
    version 19
    syntax , STUDY(string) STEP(string) [WRITTEN(string) ID(string) ARM(string) ///
        CODE(string) STATE(string) FROM(string)]
    if "`step'" == "audit" {
        capture _gracedr_study append_audit, ///
            study(`"`macval(study)'"') ///
            action(randomize) ///
            id(`"`macval(id)'"') ///
            new(`"`macval(arm)'"') ///
            newcode(`"`macval(code)'"')
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
        c_local written "`written' `step'.dta"
        exit
    }
    display as error `"gracedr: could not write `step'.dta in `macval(study)'"'
    local files = strtrim("`written'")
    if missing("`files'") {
        display as error "gracedr: no study files were changed"
    }
    else {
        display as error "gracedr: files already written: `files'; state.dta was not advanced"
        display as error "gracedr: fix the cause and check participants, codes and audit " ///
            "before the next participant"
    }
    exit `failure'
end
