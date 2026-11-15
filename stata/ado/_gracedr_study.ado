program define _gracedr_study
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known read write exists folder setting check_id reserved_id append_audit empty
    local known `known' has extension
    local is_known : list subcommand in known
    if `is_known' == 0 | missing("`subcommand'") {
        display as error "gracedr: unknown study subcommand `subcommand'"
        exit 198
    }
    _gracedr_study_`subcommand' `macval(0)'
end

program define _gracedr_study_folder, rclass
    syntax , STUDY(string)
    if regexm(`"`macval(study)'"', char(34)) == 1 {
        display as error "gracedr: study() must not contain a double quote"
        exit 198
    }
    local folder = subinstr(`"`macval(study)'"', char(92), "/", .)
    local trailing = substr(`"`macval(folder)'"', -1, 1) == "/"
    local trailing = `trailing' & !inlist(length(`"`macval(folder)'"'), 0, 1)
    while `trailing' == 1 {
        local folder = substr(`"`macval(folder)'"', 1, length(`"`macval(folder)'"') - 1)
        local trailing = substr(`"`macval(folder)'"', -1, 1) == "/"
        local trailing = `trailing' & !inlist(length(`"`macval(folder)'"'), 0, 1)
    }
    if substr(`"`macval(folder)'"', -1, 1) == ":" {
        local folder `"`macval(folder)'/"'
    }
    mata: st_local("folder_found", strofreal(direxists(st_local("folder"))))
    return scalar found = `folder_found'
    return local folder `"`macval(folder)'"'
end

program define _gracedr_study_reserved_id, rclass
    return local id "(study)"
end

program define _gracedr_study_check_id, rclass
    syntax , ID(string)
    if missing(ustrtrim(`"`macval(id)'"')) {
        display as error "gracedr: id() must not be empty"
        exit 198
    }
    if inrange(strlen(`"`macval(id)'"'), 245, 1e15) {
        display as error "gracedr: id() must be at most 244 bytes"
        exit 198
    }
    _gracedr_study_reserved_id
    mata: st_local("reserved", st_global("r(id)"))
    if ustrlower(ustrtrim(`"`macval(id)'"')) == ustrlower(`"`reserved'"') {
        display as error `"gracedr: `reserved' is reserved and cannot be a participant id"'
        exit 198
    }
    return local id `"`macval(id)'"'
end

program define _gracedr_study_checkname
    args name
    if !inlist("`macval(name)'", "design", "participants", "codes", "audit", "state") {
        display as error "gracedr: unknown study dataset `macval(name)'"
        exit 198
    }
end

program define _gracedr_study_kind, rclass
    args folder requested
    local encrypted = 0
    foreach name in design participants codes audit state {
        if fileexists(`"`macval(folder)'/`name'.zip"') == 1 {
            local encrypted = 1
        }
    }
    if "`requested'" == "1" {
        local encrypted = 1
    }
    return scalar encrypted = `encrypted'
    return local extension = cond(`encrypted' == 1, "zip", "dta")
end

program define _gracedr_study_extension, rclass
    syntax , STUDY(string)
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study_kind "`macval(folder)'" 0
    return scalar encrypted = r(encrypted)
    return local extension "`r(extension)'"
end

program define _gracedr_study_has, rclass
    syntax , STUDY(string) NAME(string)
    _gracedr_study_checkname "`macval(name)'"
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study_kind "`macval(folder)'" 0
    local file `"`macval(folder)'/`macval(name)'.`r(extension)'"'
    return scalar has = fileexists(`"`macval(file)'"')
end

program define _gracedr_study_require
    args folder shown
    local plain_found = fileexists("`macval(folder)'/design.dta")
    local zipped_found = fileexists("`macval(folder)'/design.zip")
    if max(`plain_found', `zipped_found') == 0 {
        display as error `"gracedr: no study found in `macval(shown)'"'
        exit 601
    }
end

program define _gracedr_study_exists, rclass
    syntax , STUDY(string)
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    local plain_found = fileexists(`"`macval(folder)'/design.dta"')
    local zipped_found = fileexists(`"`macval(folder)'/design.zip"')
    return scalar exists = max(`plain_found', `zipped_found')
end

program define _gracedr_study_setting, rclass
    syntax , STUDY(string) NAME(string)
    local words : word count `macval(name)'
    capture confirm name `macval(name)'
    local valid_name = `words' == 1 & _rc == 0
    if `valid_name' == 0 {
        display as error "gracedr: setting names must be valid Stata names"
        exit 198
    }
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study_require "`macval(folder)'" "`macval(study)'"
    preserve
    quietly _gracedr_study_read, study(`"`macval(study)'"') name(design)
    capture confirm variable name value
    local intact = _rc == 0
    if `intact' == 0 {
        display as error "gracedr: design.dta is damaged: it needs the columns name and value"
        exit 459
    }
    quietly keep if name == `"`macval(name)'"'
    if _N == 1 {
        mata: st_local("value", st_sdata(1, "value"))
        restore
        return local value `"`value'"'
    }
    else if _N == 0 {
        display as error `"gracedr: design.dta has no setting named `macval(name)'"'
        exit 111
    }
    else {
        display as error `"gracedr: design.dta has more than one setting named `macval(name)'"'
        exit 459
    }
end

program define _gracedr_study_read
    syntax , STUDY(string) NAME(string)
    _gracedr_study_checkname "`macval(name)'"
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study_require "`macval(folder)'" "`macval(study)'"
    _gracedr_study_kind "`macval(folder)'" 0
    local extension "`r(extension)'"
    local file "`macval(folder)'/`macval(name)'.`extension'"
    if fileexists("`macval(file)'") == 0 {
        display as error `"gracedr: `macval(name)'.`extension' is missing from `macval(study)'"'
        exit 601
    }
    if "`extension'" == "zip" {
        encuse using "`macval(file)'", clear session
    }
    else {
        use "`macval(file)'", clear
    }
end

program define _gracedr_study_write
    syntax , STUDY(string) NAME(string) [ENCRYPT]
    _gracedr_study_checkname "`macval(name)'"
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    if r(found) == 0 {
        display as error `"gracedr: study folder `macval(study)' does not exist"'
        exit 601
    }
    local requested = cond("`encrypt'" == "", 0, 1)
    _gracedr_study_kind "`macval(folder)'" `requested'
    local extension "`r(extension)'"
    local current "`macval(folder)'/`macval(name)'.`extension'"
    local pending "`macval(folder)'/`macval(name)'.tmp"
    local backup "`macval(folder)'/`macval(name)'.bak"
    if "`extension'" == "zip" {
        local pending "`macval(folder)'/`macval(name)'.tmp.zip"
        local backup "`macval(folder)'/`macval(name)'.bak.zip"
        capture noisily _gracedr_study_verify, current("`macval(current)'")
        local refused = _rc
        local verified = `refused' == 0
        if `verified' == 0 {
            display as error ///
                `"gracedr: could not write `macval(name)'.`extension' in `macval(study)'"'
            exit `refused'
        }
        capture noisily encsave using "`macval(pending)'", replace session
    }
    else {
        capture quietly save "`macval(pending)'", replace
    }
    if _rc == 0 {
        if fileexists("`macval(current)'") == 1 {
            copy "`macval(current)'" "`macval(backup)'", replace
        }
        copy "`macval(pending)'" "`macval(current)'", replace
        erase "`macval(pending)'"
    }
    else {
        local failure = _rc
        capture erase "`macval(pending)'"
        display as error `"gracedr: could not write `macval(name)'.`extension' in `macval(study)'"'
        exit `failure'
    }
end

program define _gracedr_study_verify
    syntax , CURRENT(string)
    if fileexists("`macval(current)'") == 0 {
        exit
    }
    tempfile held
    quietly save `"`held'"'
    capture noisily encuse using "`macval(current)'", clear session
    local failure = _rc
    local verified = `failure' == 0
    quietly use `"`held'"', clear
    if `verified' == 0 {
        exit `failure'
    }
end

program define _gracedr_study_empty
    syntax , NAME(string) [STUDY(string)]
    if "`macval(name)'" == "participants" & missing(`"`macval(study)'"') {
        display as error "gracedr: empty participants needs study()"
        exit 198
    }
    clear
    if "`macval(name)'" == "design" {
        generate str244 name = ""
        generate strL value = ""
        generate double order = .
    }
    else if "`macval(name)'" == "codes" {
        generate str244 code = ""
        generate str244 arm = ""
        generate str8 status = ""
        generate str244 id = ""
    }
    else if "`macval(name)'" == "audit" {
        generate double time = .
        format time %tc
        generate str16 action = ""
        generate strL id = ""
        generate strL old = ""
        generate strL new = ""
        generate strL old_code = ""
        generate strL new_code = ""
        generate strL reason = ""
    }
    else if "`macval(name)'" == "participants" {
        _gracedr_study_setting, study(`"`macval(study)'"') name(varnames)
        mata: st_local("varnames", st_global("r(value)"))
        _gracedr_study_setting, study(`"`macval(study)'"') name(vartypes)
        mata: st_local("vartypes", st_global("r(value)"))
        _gracedr_study_setting, study(`"`macval(study)'"') name(arms)
        local arm_count : word count `r(value)'
        _gracedr_study_participants, ///
            varnames(`macval(varnames)') ///
            vartypes(`macval(vartypes)') ///
            arms(`arm_count')
    }
    else if "`macval(name)'" == "state" {
        generate strL state = ""
        generate double seed = .
        generate str16 generator = ""
        generate double format_version = .
    }
    else {
        display as error "gracedr: no empty schema for `macval(name)'"
        exit 198
    }
end

program define _gracedr_study_append_audit
    syntax ,                ///
        STUDY(string)       ///
        ACTION(string)      ///
        ID(string)          ///
        [                   ///
        OLD(string)         ///
        NEW(string)         ///
        OLDCODE(string)     ///
        NEWCODE(string)     ///
        REASON(string)      ///
        ]
    if !inlist("`action'", "create", "randomize", "override") {
        display as error "gracedr: unknown audit action `action'"
        exit 198
    }
    _gracedr_study_folder, study(`"`macval(study)'"')
    mata: st_local("folder", st_global("r(folder)"))
    _gracedr_study_require "`macval(folder)'" "`macval(study)'"
    _gracedr_utc
    local stamp = r(time)
    preserve
    _gracedr_study_has, study(`"`macval(study)'"') name(audit)
    if r(has) == 1 {
        _gracedr_study_read, study(`"`macval(study)'"') name(audit)
    }
    else {
        _gracedr_study_empty, name(audit)
    }
    local row = _N + 1
    quietly set obs `macval(row)'
    mata: st_store(`macval(row)', "time", `macval(stamp)')
    local variables action id old new old_code new_code reason
    local options action id old new oldcode newcode reason
    forvalues position = 1/7 {
        local variable : word `position' of `variables'
        local option : word `position' of `macval(options)'
        mata: st_sstore(`macval(row)', "`variable'", st_local("`option'"))
    }
    _gracedr_study_write, study(`"`macval(study)'"') name(audit)
    restore
end

program define _gracedr_study_participants
    syntax , VARNAMES(string) VARTYPES(string) ARMS(integer)
    generate long seq = .
    generate str244 id = ""
    local count : word count `macval(varnames)'
    forvalues position = 1/`count' {
        local name : word `position' of `macval(varnames)'
        local type : word `position' of `macval(vartypes)'
        if "`type'" == "categorical" {
            generate str244 `macval(name)' = ""
        }
        else {
            generate double `macval(name)' = .
        }
    }
    generate str244 arm = ""
    generate str244 code = ""
    forvalues position = 1/`macval(arms)' {
        generate double prob`position' = .
    }
    generate str16 phase = ""
    generate strL rngstate = ""
    generate double time = .
    format time %tc
end
