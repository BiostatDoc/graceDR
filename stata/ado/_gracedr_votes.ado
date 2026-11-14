program define _gracedr_votes
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known categorical continuous size tally tilt
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown votes subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_votes_`subcommand' `macval(0)'
end

program define _gracedr_votes_check_pstar
    args pstar
    local valid = !missing(`pstar') & `pstar' > 0 & `pstar' < 1
    if `valid' == 0 {
        display as error "gracedr: pstar() must be a number between 0 and 1"
        exit 198
    }
end

program define _gracedr_votes_check_xi
    args xi
    local valid = !missing(`xi') & `xi' > 0.5 & `xi' < 1
    if `valid' == 0 {
        display as error "gracedr: xi() must be a number between 0.5 and 1"
        exit 198
    }
end

program define _gracedr_votes_check_arms
    args arms
    local valid = inrange(`arms', 2, 1000)
    if `valid' == 0 {
        display as error "gracedr: arms() must be a whole number from 2 to 1000"
        exit 198
    }
end

program define _gracedr_votes_whole_list, rclass
    args values upper
    local valid = 1
    foreach value of local values {
        local number = real("`value'")
        local fits = !missing(`number') & inrange(`number', 0, `upper')
        if `fits' == 1 {
            local fits = `number' == floor(`number')
        }
        local valid = `valid' & `fits'
    }
    return scalar valid = `valid'
end

program define _gracedr_votes_extreme, rclass
    syntax , VALUES(string) WHICH(string)
    local count : word count `values'
    local target = real(word("`values'", 1))
    forvalues position = 2/`count' {
        local value = real(word("`values'", `position'))
        if "`which'" == "min" {
            local target = min(`target', `value')
        }
        else {
            local target = max(`target', `value')
        }
    }
    local hits = 0
    local index = 0
    forvalues position = 1/`count' {
        local value = real(word("`values'", `position'))
        local near = inrange(abs(`value' - `target'), 0, 0.000000000001)
        if `near' == 1 {
            local hits = `hits' + 1
            local index = `position'
        }
    }
    local unique = `hits' == 1
    return scalar index = `index' * `unique'
end

program define _gracedr_votes_categorical, rclass
    syntax , TABLE(numlist) ARMS(integer) ROW(string) PSTAR(real)
    _gracedr_votes_check_pstar `pstar'
    _gracedr_votes_check_arms `arms'
    local cells : word count `table'
    local levels = `cells' / `arms'
    _gracedr_votes_whole_list "`table'" 1e15
    local valid = r(valid) & `levels' == floor(`levels')
    if `valid' == 0 {
        display as error "gracedr: table() must hold one non-negative count for each level and arm"
        exit 198
    }
    local row_number = real(`"`macval(row)'"')
    local row_ok = !missing(`row_number') & inrange(`row_number', 0, `levels')
    if `row_ok' == 1 {
        local row_ok = `row_number' == floor(`row_number')
    }
    if `row_ok' == 0 {
        display as error "gracedr: row() must be a whole number from 0 to the number of levels"
        exit 198
    }
    return scalar vote = 0
    return scalar pvalue = .
    if `row_number' == 0 {
        exit
    }
    local total = 0
    forvalues arm = 1/`arms' {
        local colsum`arm' = 0
    }
    forvalues level = 1/`levels' {
        local rowsum`level' = 0
        forvalues arm = 1/`arms' {
            local position = (`level' - 1) * `arms' + `arm'
            local cell`level'_`arm' = real(word("`table'", `position'))
            local rowsum`level' = `rowsum`level'' + `cell`level'_`arm''
            local colsum`arm' = `colsum`arm'' + `cell`level'_`arm''
            local total = `total' + `cell`level'_`arm''
        }
    }
    local kept = 0
    forvalues level = 1/`levels' {
        local kept = `kept' + inrange(`rowsum`level'', 1, 1e15)
    }
    local row_has_counts = inrange(`rowsum`row_number'', 1, 1e15)
    local enough_levels = inrange(`kept', 2, 1e9)
    local columns_have_counts = 1
    forvalues arm = 1/`arms' {
        local columns_have_counts = `columns_have_counts' & inrange(`colsum`arm'', 1, 1e15)
    }
    local testable = `row_has_counts' & `enough_levels' & `columns_have_counts'
    if `testable' == 0 {
        exit
    }
    local chi_square = 0
    forvalues level = 1/`levels' {
        if inrange(`rowsum`level'', 1, 1e15) {
            forvalues arm = 1/`arms' {
                local expected = `rowsum`level'' * `colsum`arm'' / `total'
                local difference = `cell`level'_`arm'' - `expected'
                local chi_square = `chi_square' + `difference' * `difference' / `expected'
            }
        }
    }
    local degrees = (`kept' - 1) * (`arms' - 1)
    local p_value = chi2tail(`degrees', `chi_square')
    return scalar pvalue = `p_value'
    local not_significant = inrange(`p_value', `pstar', 1)
    if `not_significant' == 1 {
        exit
    }
    local shares ""
    forvalues arm = 1/`arms' {
        local share = `cell`row_number'_`arm'' / `colsum`arm''
        local shares "`shares' `share'"
    }
    _gracedr_votes_extreme, values(`shares') which(min)
    return scalar vote = r(index)
end

program define _gracedr_votes_continuous, rclass
    syntax , N(numlist) SUM(numlist) SS(numlist) X(string) PSTAR(real)
    _gracedr_votes_check_pstar `pstar'
    local arms : word count `n'
    local sum_count : word count `sum'
    local ss_count : word count `ss'
    local same_count = `arms' == `sum_count' & `arms' == `ss_count' & inrange(`arms', 2, 1e9)
    if `same_count' == 0 {
        display as error "gracedr: n(), sum() and ss() must have the same number of " ///
            "values, at least 2"
        exit 198
    }
    _gracedr_votes_whole_list "`n'" 1e15
    if r(valid) == 0 {
        display as error "gracedr: n() must be non-negative whole numbers"
        exit 198
    }
    local text = strtrim(`"`macval(x)'"')
    local value = real(`"`macval(text)'"')
    local is_dot = `"`macval(text)'"' == "."
    if missing(`value') & `is_dot' == 0 {
        display as error "gracedr: x() must be a number or ."
        exit 198
    }
    return scalar vote = 0
    return scalar pvalue = .
    local enough = 1
    forvalues arm = 1/`arms' {
        local count`arm' = real(word("`n'", `arm'))
        local enough = `enough' & inrange(`count`arm'', 2, 1e15)
    }
    local testable = !missing(`value') & `enough'
    if `testable' == 0 {
        exit
    }
    local positive_variances = 1
    forvalues arm = 1/`arms' {
        local mean`arm' = real(word("`sum'", `arm')) / `count`arm''
        local sum_squares = real(word("`ss'", `arm'))
        local variance`arm' = (`sum_squares' - `count`arm'' * `mean`arm'' * `mean`arm'') / ///
            (`count`arm'' - 1)
        local positive_variances = `positive_variances' & !inrange(`variance`arm'', -1e300, 0)
    }
    if `positive_variances' == 0 {
        exit
    }
    if `arms' == 2 {
        local standard_error_squared = `variance1' / `count1' + `variance2' / `count2'
        local t_statistic = (`mean1' - `mean2') / sqrt(`standard_error_squared')
        local ratio1 = `variance1' / `count1'
        local ratio2 = `variance2' / `count2'
        local part1 = `ratio1' * `ratio1' / (`count1' - 1)
        local part2 = `ratio2' * `ratio2' / (`count2' - 1)
        local degrees = `standard_error_squared' * `standard_error_squared' / (`part1' + `part2')
        local p_value = 2 * ttail(`degrees', abs(`t_statistic'))
    }
    else {
        local weight_total = 0
        local weighted_sum = 0
        forvalues arm = 1/`arms' {
            local weight`arm' = `count`arm'' / `variance`arm''
            local weight_total = `weight_total' + `weight`arm''
            local weighted_sum = `weighted_sum' + `weight`arm'' * `mean`arm''
        }
        local weighted_mean = `weighted_sum' / `weight_total'
        local numerator = 0
        local h = 0
        forvalues arm = 1/`arms' {
            local gap = `mean`arm'' - `weighted_mean'
            local numerator = `numerator' + `weight`arm'' * `gap' * `gap'
            local share = 1 - `weight`arm'' / `weight_total'
            local h = `h' + `share' * `share' / (`count`arm'' - 1)
        }
        local numerator = `numerator' / (`arms' - 1)
        local correction = 1 + 2 * (`arms' - 2) / (`arms' * `arms' - 1) * `h'
        local f_statistic = `numerator' / `correction'
        local second_degrees = (`arms' * `arms' - 1) / (3 * `h')
        local p_value = Ftail(`arms' - 1, `second_degrees', `f_statistic')
    }
    return scalar pvalue = `p_value'
    local not_significant = inrange(`p_value', `pstar', 1)
    if `not_significant' == 1 {
        exit
    }
    local means ""
    forvalues arm = 1/`arms' {
        local means "`means' `mean`arm''"
    }
    local largest = `mean1'
    local smallest = `mean1'
    forvalues arm = 2/`arms' {
        local largest = max(`largest', `mean`arm'')
        local smallest = min(`smallest', `mean`arm'')
    }
    local above = !missing(`value') & `value' > `largest'
    local below = !missing(`value') & `value' < `smallest'
    if `above' == 1 {
        _gracedr_votes_extreme, values(`means') which(min)
        return scalar vote = r(index)
    }
    else if `below' == 1 {
        _gracedr_votes_extreme, values(`means') which(max)
        return scalar vote = r(index)
    }
end

program define _gracedr_votes_size, rclass
    syntax , N(numlist) RATIO(numlist)
    local arms : word count `n'
    local ratio_count : word count `ratio'
    local same_count = `arms' == `ratio_count' & inrange(`arms', 2, 1e9)
    if `same_count' == 0 {
        display as error "gracedr: n() and ratio() must have the same number of " ///
            "values (at least 2)"
        exit 198
    }
    _gracedr_votes_whole_list "`n'" 1e15
    if r(valid) == 0 {
        display as error "gracedr: n() must be non-negative whole numbers"
        exit 198
    }
    local ratio_total = 0
    local positive = 1
    foreach value of local ratio {
        local number = real("`value'")
        local positive = `positive' & !missing(`number') & `number' > 0
        local ratio_total = `ratio_total' + `number'
    }
    if `positive' == 0 {
        display as error "gracedr: ratio() values must be positive"
        exit 198
    }
    local total = 0
    foreach value of local n {
        local total = `total' + real("`value'")
    }
    local deficits ""
    local smallest = .
    forvalues arm = 1/`arms' {
        local proportion = real(word("`ratio'", `arm')) / `ratio_total'
        local deficit = real(word("`n'", `arm')) - `proportion' * `total'
        local deficits "`deficits' `deficit'"
        local smallest = min(`smallest', `deficit')
    }
    local threshold = 0 - 1 + 0.000000001
    local voting = inrange(`smallest', 0 - 1e300, `threshold')
    return scalar vote = 0
    if `voting' == 1 {
        _gracedr_votes_extreme, values(`deficits') which(min)
        return scalar vote = r(index)
    }
end

program define _gracedr_votes_tally, rclass
    syntax , VOTES(numlist) WEIGHTS(numlist) ARMS(integer)
    _gracedr_votes_check_arms `arms'
    _gracedr_votes_whole_list "`votes'" `arms'
    if r(valid) == 0 {
        display as error "gracedr: votes() must be whole numbers from 0 to arms()"
        exit 198
    }
    local vote_count : word count `votes'
    local weight_count : word count `weights'
    local positive = `vote_count' == `weight_count'
    foreach value of local weights {
        local number = real("`value'")
        local positive = `positive' & !missing(`number') & `number' > 0
    }
    if `positive' == 0 {
        display as error "gracedr: weights() must be positive, one for each vote"
        exit 198
    }
    forvalues arm = 1/`arms' {
        local score`arm' = 0
        local voted`arm' = 0
    }
    forvalues position = 1/`vote_count' {
        local arm = real(word("`votes'", `position'))
        if inrange(`arm', 1, 1e9) {
            local score`arm' = `score`arm'' + real(word("`weights'", `position'))
            local voted`arm' = 1
        }
    }
    local scores ""
    local mapping ""
    forvalues arm = 1/`arms' {
        if `voted`arm'' == 1 {
            local scores "`scores' `score`arm''"
            local mapping "`mapping' `arm'"
        }
    }
    return scalar winner = 0
    if !missing("`scores'") {
        _gracedr_votes_extreme, values(`scores') which(max)
        local index = r(index)
        if inrange(`index', 1, 1e9) {
            return scalar winner = real(word("`mapping'", `index'))
        }
    }
end

program define _gracedr_votes_tilt, rclass
    syntax , BASE(numlist) WINNER(string) XI(real)
    _gracedr_votes_check_xi `xi'
    local arms : word count `base'
    local base_ok = inrange(`arms', 2, 1e9)
    foreach value of local base {
        local number = real("`value'")
        local base_ok = `base_ok' & !missing(`number') & inrange(`number', 0, 1e300)
    }
    if `base_ok' == 0 {
        display as error "gracedr: base() must be at least 2 non-negative numbers"
        exit 198
    }
    local winner_number = real(`"`macval(winner)'"')
    local winner_ok = !missing(`winner_number') & inrange(`winner_number', 0, `arms')
    if `winner_ok' == 1 {
        local winner_ok = `winner_number' == floor(`winner_number')
    }
    if `winner_ok' == 0 {
        display as error "gracedr: winner() must be a whole number from 0 to the number of arms"
        exit 198
    }
    local base_winner = 0
    if inrange(`winner_number', 1, `arms') {
        local base_winner = real(word("`base'", `winner_number'))
    }
    local interior = !inrange(`base_winner', 0, 0) & !inrange(`base_winner', 1, 1e300)
    local tilt_it = inrange(`winner_number', 1, `arms') & `interior'
    local winner_probability = .
    if `tilt_it' == 1 {
        local odds = `base_winner' / (1 - `base_winner') * `xi' / (1 - `xi')
        local winner_probability = `odds' / (1 + `odds')
    }
    local probs ""
    forvalues arm = 1/`arms' {
        local value = real(word("`base'", `arm'))
        if `tilt_it' == 1 {
            if `arm' == `winner_number' {
                local value = `winner_probability'
            }
            else {
                local value = `value' * (1 - `winner_probability') / (1 - `base_winner')
            }
        }
        local text = strtrim(string(`value', "%21.15g"))
        local probs "`probs' `text'"
    }
    return local probs = strtrim("`probs'")
end
