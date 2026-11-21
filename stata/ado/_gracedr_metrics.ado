*! version 1.0.0  15nov2026
program define _gracedr_metrics
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known load trial
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown metrics subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_metrics_`subcommand' `macval(0)'
end

program define _gracedr_metrics_load
    version 19
    _gracedr_core load
    capture mata: gd_metrics_version()
    local ready = _rc == 0
    if `ready' == 0 {
        quietly findfile _gracedr_metrics.mata
        quietly do "`r(fn)'"
    }
end

program define _gracedr_metrics_trial
    syntax , STUDY(string)
    _gracedr_metrics load
    preserve
    _gracedr_settings load, study(`"`macval(study)'"') designonly
    local d_n "`r(n)'"
    mata: st_local("d_arms", st_global("r(arms)"))
    local d_ratio "`r(ratio)'"
    local d_runin "`r(runin)'"
    local d_forcedat "`r(forcedat)'"
    local d_nvars "`r(nvars)'"
    local d_varnames "`r(varnames)'"
    local d_vartypes "`r(vartypes)'"
    forvalues position = 1/`d_nvars' {
        mata: st_local("d_levels`position'", st_global("r(levels`position')"))
    }
    mata: gd_metrics_from_data()
    clear
    quietly set obs `metric_rows'
    quietly generate str12 point = ""
    quietly generate strL metric = ""
    quietly generate double value = .
    mata: gd_metrics_to_data()
    restore, not
end
