program define _gracedr_core
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known load probs
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown core subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_core_`subcommand' `macval(0)'
end

program define _gracedr_core_load
    version 19
    capture mata: gd_core_version()
    local ready = _rc == 0
    if `ready' == 0 {
        quietly findfile _gracedr_core.mata
        quietly do "`r(fn)'"
    }
end

program define _gracedr_core_probs, rclass
    syntax ,                    ///
        STUDY(string)           ///
        METHOD(string)          ///
        [                       ///
        ID(string)              ///
        OPTIONS(string)         ///
        BREAKS(string)          ///
        PHIGH(string)           ///
        ]
    _gracedr_core load
    preserve
    _gracedr_values parse, ///
        study(`"`macval(study)'"') ///
        id(`"`macval(id)'"') ///
        options(`"`macval(options)'"')
    local variable_count = r(nvars)
    forvalues position = 1/`variable_count' {
        mata: st_local("cleaned`position'", st_global("r(value`position')"))
        local number`position' = string(r(number`position'), "%21.17g")
    }
    _gracedr_settings load, study(`"`macval(study)'"')
    local d_n "`r(n)'"
    mata: st_local("d_arms", st_global("r(arms)"))
    local d_ratio "`r(ratio)'"
    local d_weights "`r(weights)'"
    local d_pstar "`r(pstar)'"
    local d_xi "`r(xi)'"
    local d_runin "`r(runin)'"
    local d_runinmethod "`r(runinmethod)'"
    local d_forcedat "`r(forcedat)'"
    local d_sizebound "`r(sizebound)'"
    local d_nvars "`r(nvars)'"
    local d_varnames "`r(varnames)'"
    local d_vartypes "`r(vartypes)'"
    forvalues position = 1/`variable_count' {
        mata: st_local("d_levels`position'", st_global("r(levels`position')"))
    }
    local d_phigh "`phigh'"
    _gracedr_rules breaks, ///
        varnames(`d_varnames') ///
        vartypes(`d_vartypes') ///
        breaks(`"`macval(breaks)'"')
    forvalues position = 1/`variable_count' {
        local d_cuts`position' "`r(breaks`position')'"
    }
    mata: gd_probs_from_data()
    return local probs "`core_probs'"
    local phase_names "none quota runin bound msb-biased msb-random"
    local phase_number = real("`core_phase'")
    local phase_name "`method'"
    if "`method'" == "mmsb" {
        local phase_index = `phase_number' + 1
        local phase_name : word `phase_index' of `phase_names'
    }
    return local phase "`phase_name'"
end
