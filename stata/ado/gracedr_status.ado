program define gracedr_status, rclass
    version 19
    syntax , STUDY(string) [FROM(string) TO(string) CHECKPOINT(string) VARS(string) ///
        GRAPHS SAVING(string)]
    preserve
    quietly _gracedr_tables groupsize, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    local total = r(total)
    local noun = cond(`total' == 1, "participant", "participants")
    display as text "Study status: " as result "`total'" as text " `noun' randomized"
    _gracedr_tables groupsize, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    tempname sizes
    matrix `sizes' = r(groupsize)
    _gracedr_tables balance, ///
        study(`"`macval(study)'"') ///
        from(`"`macval(from)'"') ///
        to(`"`macval(to)'"') ///
        checkpoint(`"`macval(checkpoint)'"') ///
        vars(`"`macval(vars)'"')
    tempname smd_values
    matrix `smd_values' = r(smd)
    local varnames "`r(varnames)'"
    if !missing("`graphs'") {
        local imbalance_file ""
        local smd_file ""
        if !missing(`"`macval(saving)'"') {
            local imbalance_file `"`macval(saving)'_imbalance"'
            local smd_file `"`macval(saving)'_smd"'
        }
        _gracedr_graphs imbalance, ///
            study(`"`macval(study)'"') ///
            from(`"`macval(from)'"') ///
            to(`"`macval(to)'"') ///
            checkpoint(`"`macval(checkpoint)'"') ///
            saving(`"`macval(imbalance_file)'"')
        _gracedr_graphs smd, ///
            study(`"`macval(study)'"') ///
            from(`"`macval(from)'"') ///
            to(`"`macval(to)'"') ///
            checkpoint(`"`macval(checkpoint)'"') ///
            vars(`"`macval(vars)'"') ///
            saving(`"`macval(smd_file)'"')
    }
    return scalar n_randomized = `total'
    return matrix groupsize = `sizes'
    return matrix smd = `smd_values'
    return local varnames "`varnames'"
end
