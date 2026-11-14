program define _gracedr_balance
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known vote row
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown balance subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_balance_`subcommand' `macval(0)'
end

program define _gracedr_balance_vote, rclass
    syntax , NAME(string) TYPE(string) ARMS(string asis) PSTAR(string) ///
        [LEVELS(string asis) VALUE(string) NUMBER(string)]
    local arm_count : word count `macval(arms)'
    if "`type'" == "categorical" {
        local level_count : word count `macval(levels)'
        local table ""
        forvalues level = 1/`level_count' {
            local level_text : word `level' of `macval(levels)'
            forvalues arm = 1/`arm_count' {
                local label : word `arm' of `macval(arms)'
                quietly count if `name' == `"`macval(level_text)'"' & ///
                    arm == `"`macval(label)'"'
                local table "`table' `r(N)'"
            }
        }
        local row_index = 0
        if !missing(`"`macval(value)'"') {
            local row_index : list posof `"`macval(value)'"' in levels
        }
        _gracedr_votes categorical, ///
            table(`table') ///
            arms(`arm_count') ///
            row(`row_index') ///
            pstar(`pstar')
    }
    else {
        local n_text ""
        local sum_text ""
        local square_text ""
        tempvar square
        quietly generate double `square' = `name' * `name'
        forvalues arm = 1/`arm_count' {
            local label : word `arm' of `macval(arms)'
            quietly summarize `name' if arm == `"`macval(label)'"'
            local piece_count = r(N)
            local sum_piece = string(r(sum), "%21.17g")
            if `piece_count' == 0 {
                local sum_piece = 0
            }
            quietly summarize `square' if arm == `"`macval(label)'"'
            local square_piece = string(r(sum), "%21.17g")
            if `piece_count' == 0 {
                local square_piece = 0
            }
            local n_text "`n_text' `piece_count'"
            local sum_text "`sum_text' `sum_piece'"
            local square_text "`square_text' `square_piece'"
        }
        _gracedr_votes continuous, ///
            n(`n_text') ///
            sum(`sum_text') ///
            ss(`square_text') ///
            x(`number') ///
            pstar(`pstar')
    }
    return scalar vote = r(vote)
end

program define _gracedr_balance_row, rclass
    syntax , NAME(string) TYPE(string) ARMS(string asis) [LEVEL(string) NUMBER(string) ///
        BREAKS(string)]
    local arm_count : word count `macval(arms)'
    tempvar bin
    if "`type'" == "continuous" {
        quietly generate long `bin' = 0 if !missing(`name')
        local target = 0
        foreach cut of local breaks {
            quietly replace `bin' = `bin' + inrange(`name', `cut', 1e300) if !missing(`name')
            local target = `target' + inrange(`number', `cut', 1e300)
        }
    }
    local counts ""
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        if "`type'" == "categorical" {
            quietly count if `name' == `"`macval(level)'"' & arm == `"`macval(label)'"'
        }
        else {
            quietly count if `bin' == `target' & arm == `"`macval(label)'"'
        }
        local counts "`counts' `r(N)'"
    }
    return local counts = strtrim("`counts'")
end
