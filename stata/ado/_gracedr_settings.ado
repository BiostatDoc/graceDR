*! version 1.0.0  15nov2026
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
    syntax , STUDY(string) [FROM(string) TO(string) CHECKPOINT(string) VARS(string) ///
        DESIGNONLY]
    local settings n arms ratio runin forcedat nvars varnames vartypes
    local settings `settings' weights pstar xi runinmethod sizebound
    foreach setting of local settings {
        _gracedr_study setting, study(`"`macval(study)'"') name(`setting')
        mata: st_local("`setting'", st_global("r(value)"))
    }
    local variable_count = real(`"`macval(nvars)'"')
    forvalues position = 1/`variable_count' {
        _gracedr_study setting, study(`"`macval(study)'"') name(levels`position')
        mata: st_local("levels`position'", st_global("r(value)"))
    }
    _gracedr_filters positions, varnames(`"`macval(varnames)'"') vars(`"`macval(vars)'"')
    local positions "`r(positions)'"
    if missing("`designonly'") {
        _gracedr_study read, study(`"`macval(study)'"') name(participants)
        _gracedr_filters records, ///
            n(`n') ///
            ratio(`ratio') ///
            runin(`runin') ///
            forcedat(`"`forcedat'"') ///
            from(`"`macval(from)'"') ///
            to(`"`macval(to)'"') ///
            checkpoint(`"`macval(checkpoint)'"')
    }
    foreach setting in n arms ratio runin forcedat weights pstar xi runinmethod sizebound {
        return local `setting' `"`macval(`setting')'"'
    }
    local kept : word count `positions'
    local names ""
    local types ""
    forvalues index = 1/`kept' {
        local position : word `index' of `positions'
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        local names "`names' `name'"
        local types "`types' `type'"
        return local levels`index' `"`macval(levels`position')'"'
    }
    return local nvars "`kept'"
    return local varnames = strtrim("`names'")
    return local vartypes = strtrim("`types'")
end
