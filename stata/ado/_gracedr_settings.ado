program define _gracedr_settings
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known load
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown settings subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_settings_`subcommand' `macval(0)'
end

program define _gracedr_settings_load, rclass
    syntax , STUDY(string)
    foreach setting in n arms ratio runin forcedat nvars varnames vartypes {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
        return local `setting' `"`macval(`setting')'"'
    }
    local variable_count = real(`"`macval(nvars)'"')
    forvalues position = 1/`variable_count' {
        _gracedr_study setting, study(`"`macval(study)'"') name(levels`position')
        mata: st_local("levels", st_global("r(value)"))
        return local levels`position' `"`macval(levels)'"'
    }
    _gracedr_study read, study(`"`macval(study)'"') name(participants)
end
