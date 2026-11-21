*! version 1.0.0  15nov2026
program define _gracedr_smd
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known binary continuous variable
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown smd subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_smd_`subcommand' `macval(0)'
end

program define _gracedr_smd_scaled, rclass
    args difference denominator
    local usable = !missing(`difference') & !missing(`denominator')
    if `usable' == 1 {
        local usable = (`denominator' == 0) == 0
    }
    local value = 0
    if `usable' == 1 {
        local value = `difference' / `denominator'
    }
    return scalar smd = `value'
end

program define _gracedr_smd_binary, rclass
    syntax , P1(real) P2(real)
    local spread = sqrt((`p1' * (1 - `p1') + `p2' * (1 - `p2')) / 2)
    local difference = `p1' - `p2'
    _gracedr_smd_scaled `difference' `spread'
    return scalar smd = r(smd)
end

program define _gracedr_smd_continuous, rclass
    syntax , M1(real) M2(real) S1(string) S2(string)
    local first = real("`s1'")
    local second = real("`s2'")
    local spread = sqrt((`first' * `first' + `second' * `second') / 2)
    local difference = `m1' - `m2'
    _gracedr_smd_scaled `difference' `spread'
    return scalar smd = r(smd)
end

program define _gracedr_smd_variable, rclass
    syntax , NAME(string) TYPE(string) ARMS(string asis) [LEVELS(string asis)]
    local arm_count : word count `macval(arms)'
    forvalues arm = 1/`arm_count' {
        local label : word `arm' of `macval(arms)'
        quietly count if arm == `"`macval(label)'"' & !missing(`name')
        local present`arm' = r(N)
        if `present`arm'' == 0 {
            return scalar smd = .
            exit
        }
    }
    local level_count = 1
    if "`type'" == "categorical" {
        local level_count : word count `macval(levels)'
    }
    local largest = 0
    forvalues level = 1/`level_count' {
        forvalues arm = 1/`arm_count' {
            local label : word `arm' of `macval(arms)'
            if "`type'" == "categorical" {
                local level_text : word `level' of `macval(levels)'
                quietly count if arm == `"`macval(label)'"' & ///
                    `name' == `"`macval(level_text)'"'
                local first`arm' = r(N) / `present`arm''
                local second`arm' = .
            }
            else {
                quietly summarize `name' if arm == `"`macval(label)'"'
                local first`arm' = r(mean)
                local second`arm' = r(sd)
            }
        }
        forvalues left = 1/`arm_count' {
            local start = `left' + 1
            forvalues right = `start'/`arm_count' {
                if "`type'" == "categorical" {
                    _gracedr_smd_binary, p1(`first`left'') p2(`first`right'')
                }
                else {
                    _gracedr_smd_continuous, ///
                        m1(`first`left'') ///
                        m2(`first`right'') ///
                        s1(`second`left'') ///
                        s2(`second`right'')
                }
                local largest = max(`largest', abs(r(smd)))
            }
        }
    }
    return scalar smd = `largest'
end
