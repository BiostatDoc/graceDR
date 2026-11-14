version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

local tolerance = 1 / 1000000000

_gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(0.3)
assert r(vote) == 2
local expected = chi2tail(1, 7.2)
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes categorical, table(8 2 2 8) arms(2) row(2) pstar(0.3)
assert r(vote) == 1
_gracedr_votes categorical, table(8 2 2 8) arms(2) row(0) pstar(0.3)
assert r(vote) == 0
_gracedr_votes categorical, table(5 5 5 5) arms(2) row(1) pstar(0.3)
assert r(vote) == 0
close_to `r(pvalue)' 1 `tolerance'
_gracedr_votes categorical, table(0 0 10 10 10 0) arms(3) row(1) pstar(0.3)
assert r(vote) == 0
local expected = chi2tail(2, 30)
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes categorical, table(0 0 10 10 10 0) arms(3) row(2) pstar(0.3)
assert r(vote) == 3
_gracedr_votes categorical, table(5 5 0 0) arms(2) row(1) pstar(0.3)
assert r(vote) == 0
assert missing(r(pvalue))
_gracedr_votes categorical, table(5 0 5 0) arms(2) row(1) pstar(0.3)
assert r(vote) == 0
_gracedr_votes categorical, table(5 5 0 0 3 7) arms(2) row(2) pstar(0.5)
assert r(vote) == 0
_gracedr_votes categorical, table(5 5 0 0 3 7) arms(2) row(3) pstar(0.5)
assert r(vote) == 1
local expected = chi2tail(1, 5 / 6)
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes categorical, table(5 5 0 0 3 7) arms(2) row(1) pstar(0.5)
assert r(vote) == 2
_gracedr_votes categorical, table(5 5 0 0 3 7) arms(2) row(3) pstar(0.3)
assert r(vote) == 0
foreach case in "1 2" "2 1" "3 2" {
    gettoken row expected : case
    _gracedr_votes categorical, ///
        table(12 3 5 4 11 6 6 5 9) ///
        arms(3) ///
        row(`row') ///
        pstar(0.3)
    assert r(vote) == `expected'
    local expected = chi2tail(4, 11.417312599681019)
    close_to `r(pvalue)' `expected' `tolerance'
}

local pstar_message "gracedr: pstar() must be a number between 0 and 1"
local arms_message "gracedr: arms() must be a whole number from 2 to 1000"
local table_message "gracedr: table() must hold one non-negative count for each level and arm"
local row_message "gracedr: row() must be a whole number from 0 to the number of levels"
foreach bad_pstar in 0 1 -0.1 1.5 {
    expect_failure, ///
        rc(198) ///
        message("`pstar_message'") ///
        command(`"_gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(`bad_pstar')"')
}
expect_failure, ///
    rc(198) ///
    message("`arms_message'") ///
    command(`"_gracedr_votes categorical, table(8 2) arms(1) row(1) pstar(0.3)"')
foreach bad_table in "1 2 3" "8 2 2 -8" "8 2 2 8.5" {
    expect_failure, ///
        rc(198) ///
        message("`table_message'") ///
        command(`"_gracedr_votes categorical, table(`bad_table') arms(2) row(1) pstar(0.3)"')
}
foreach bad_row in 3 -1 1.5 {
    expect_failure, ///
        rc(198) ///
        message("`row_message'") ///
        command(`"_gracedr_votes categorical, table(8 2 2 8) arms(2) row(`bad_row') pstar(0.3)"')
}

_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(0.3)
assert r(vote) == 2
local expected = 2 * ttail(18, 5 / sqrt(0.8))
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(3) pstar(0.3)
assert r(vote) == 1
foreach inside in 7 10 5 . {
    _gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(`inside') pstar(0.3)
    assert r(vote) == 0
}
_gracedr_votes continuous, n(10 10) sum(100 100) ss(1036 1036) x(30) pstar(0.3)
assert r(vote) == 0
close_to `r(pvalue)' 1 `tolerance'

_gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(12) pstar(0.3)
assert r(vote) == 3
local expected = Ftail(2, 18, 62.5 * 27 / 28)
close_to `r(pvalue)' `expected' `tolerance'
local minus = char(45)
_gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(`minus'2) pstar(0.3)
assert r(vote) == 1
_gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(5) pstar(0.3)
assert r(vote) == 0

local first_gap = 1 - 4 / 10.5
local third_gap = 1 - 2.5 / 10.5
local h = `first_gap' * `first_gap' / 7 + `first_gap' * `first_gap' / 11
local h = `h' + `third_gap' * `third_gap' / 9
local f_statistic = 4 / (1 + 0.25 * `h')
local second_df = 8 / (3 * `h')
_gracedr_votes continuous, n(8 12 10) sum(32 72 50) ss(142 465 286) x(9) pstar(0.3)
assert r(vote) == 1
local expected = Ftail(2, `second_df', `f_statistic')
close_to `r(pvalue)' `expected' `tolerance'

_gracedr_votes continuous, n(12 9) sum(90 54) ss(708 364) x(10) pstar(0.3)
assert r(vote) == 2
local expected = 2 * ttail(14.660855784469096, 1.6712580435934667)
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes continuous, n(12 9) sum(90 54) ss(708 364) x(10) pstar(0.1)
assert r(vote) == 0
_gracedr_votes continuous, n(1 10) sum(5 50) ss(25 300) x(12) pstar(0.3)
assert r(vote) == 0
_gracedr_votes continuous, n(5 5) sum(10 20) ss(20 80) x(30) pstar(0.3)
assert r(vote) == 0
_gracedr_votes continuous, n(10 10 10) sum(0 0 100) ss(36 36 1036) x(12) pstar(0.3)
assert r(vote) == 0

local counts_message "gracedr: n(), sum() and ss() must have the same number of values, at least 2"
local n_message "gracedr: n() must be non-negative whole numbers"
local x_message "gracedr: x() must be a number or ."
expect_failure, ///
    rc(198) ///
    message("`counts_message'") ///
    command(`"_gracedr_votes continuous, n(10 10) sum(100) ss(1036 286) x(12) pstar(0.3)"')
expect_failure, ///
    rc(198) ///
    message("`counts_message'") ///
    command(`"_gracedr_votes continuous, n(10) sum(100) ss(1036) x(12) pstar(0.3)"')
local continuous_call "_gracedr_votes continuous,"
foreach bad_n in "10 -1" "10 2.5" {
    expect_failure, ///
        rc(198) ///
        message("`n_message'") ///
        command(`"`continuous_call' n(`bad_n') sum(100 50) ss(1036 286) x(12) pstar(0.3)"')
}
expect_failure, ///
    rc(198) ///
    message("`x_message'") ///
    command(`"_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(abc) pstar(0.3)"')
expect_failure, ///
    rc(198) ///
    message("`pstar_message'") ///
    command(`"_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(2)"')

_gracedr_votes size, n(5 9) ratio(1 1)
assert r(vote) == 1
_gracedr_votes size, n(6 7) ratio(1 1)
assert r(vote) == 0
_gracedr_votes size, n(6 8) ratio(1 1)
assert r(vote) == 1
_gracedr_votes size, n(8 6) ratio(1 1)
assert r(vote) == 2
_gracedr_votes size, n(4 4 10) ratio(1 1 1)
assert r(vote) == 0
_gracedr_votes size, n(5 5 5) ratio(1 1 1)
assert r(vote) == 0
_gracedr_votes size, n(2 8) ratio(2 1)
assert r(vote) == 1
_gracedr_votes size, n(5 5) ratio(1 2)
assert r(vote) == 2
_gracedr_votes size, n(3 9 12) ratio(1 1 2)
assert r(vote) == 1
local size_message "gracedr: n() and ratio() must have the same number of values (at least 2)"
local ratio_message "gracedr: ratio() values must be positive"
expect_failure, ///
    rc(198) ///
    message("`size_message'") ///
    command(`"_gracedr_votes size, n(5 9 3) ratio(1 1)"')
expect_failure, ///
    rc(198) ///
    message("`size_message'") ///
    command(`"_gracedr_votes size, n(5) ratio(1)"')
expect_failure, ///
    rc(198) ///
    message("`ratio_message'") ///
    command(`"_gracedr_votes size, n(5 9) ratio(1 0)"')
expect_failure, ///
    rc(198) ///
    message("`n_message'") ///
    command(`"_gracedr_votes size, n(5 -9) ratio(1 1)"')

_gracedr_votes tally, votes(1 2 0) weights(1 1 1) arms(2)
assert r(winner) == 0
_gracedr_votes tally, votes(1 1 2) weights(1 1 1) arms(2)
assert r(winner) == 1
_gracedr_votes tally, votes(0 0 0) weights(1 1 1) arms(2)
assert r(winner) == 0
_gracedr_votes tally, votes(2 0 0) weights(1 1 1) arms(2)
assert r(winner) == 2
_gracedr_votes tally, votes(1 2) weights(0.5 2) arms(2)
assert r(winner) == 2
_gracedr_votes tally, votes(1 1 2) weights(0.1 0.2 0.3) arms(2)
assert r(winner) == 0
_gracedr_votes tally, votes(3 3 1 2) weights(0.5 0.6 1 0.9) arms(3)
assert r(winner) == 3
_gracedr_votes tally, votes(3 3 1 2) weights(0.5 0.5 1 0.9) arms(3)
assert r(winner) == 0
_gracedr_votes tally, votes(1 1 1) weights(1 1 1) arms(3)
assert r(winner) == 1
local votes_message "gracedr: votes() must be whole numbers from 0 to arms()"
local weights_message "gracedr: weights() must be positive, one for each vote"
expect_failure, ///
    rc(198) ///
    message("`votes_message'") ///
    command(`"_gracedr_votes tally, votes(1 3) weights(1 1) arms(2)"')
expect_failure, ///
    rc(198) ///
    message("`votes_message'") ///
    command(`"_gracedr_votes tally, votes(1 1.5) weights(1 1) arms(2)"')
expect_failure, ///
    rc(198) ///
    message("`weights_message'") ///
    command(`"_gracedr_votes tally, votes(1 2) weights(1) arms(2)"')
expect_failure, ///
    rc(198) ///
    message("`weights_message'") ///
    command(`"_gracedr_votes tally, votes(1 2) weights(1 0) arms(2)"')
expect_failure, ///
    rc(198) ///
    message("`arms_message'") ///
    command(`"_gracedr_votes tally, votes(1) weights(1) arms(1)"')

_gracedr_votes tilt, base(0.5 0.5) winner(1) xi(0.65)
local actual = real(word("`r(probs)'", 1))
local expected = 0.65
close_to `actual' `expected' `tolerance'
local actual = real(word("`r(probs)'", 2))
local expected = 0.35
close_to `actual' `expected' `tolerance'
local odds = 0.3 / 0.7 * 0.8 / 0.2
_gracedr_votes tilt, base(0.7 0.3) winner(2) xi(0.8)
local actual = real(word("`r(probs)'", 2))
local expected = `odds' / (1 + `odds')
close_to `actual' `expected' `tolerance'
local actual = real(word("`r(probs)'", 1))
local expected = 1 - `odds' / (1 + `odds')
close_to `actual' `expected' `tolerance'
local odds = 0.2 / 0.8 * 0.7 / 0.3
local winner_probability = `odds' / (1 + `odds')
_gracedr_votes tilt, base(0.5 0.3 0.2) winner(3) xi(0.7)
local actual = real(word("`r(probs)'", 3))
local expected = `winner_probability'
close_to `actual' `expected' `tolerance'
local actual = real(word("`r(probs)'", 1))
local expected = 0.5 * (1 - `winner_probability') / 0.8
close_to `actual' `expected' `tolerance'
local actual = real(word("`r(probs)'", 2))
local expected = 0.3 * (1 - `winner_probability') / 0.8
close_to `actual' `expected' `tolerance'
local total = 0
foreach position in 1 2 3 {
    local total = `total' + real(word("`r(probs)'", `position'))
}
close_to `total' 1 `tolerance'
foreach case in "1 0|1|0.65" "0 1|1|0.65" "0.5 0.5|0|0.65" "1 0|2|0.65" {
    gettoken base rest : case, parse("|")
    gettoken bar rest : rest, parse("|")
    gettoken winner xi_text : rest, parse("|")
    local xi_text = substr("`xi_text'", 2, .)
    _gracedr_votes tilt, base(`base') winner(`winner') xi(`xi_text')
    local first = real(word("`r(probs)'", 1))
    local second = real(word("`r(probs)'", 2))
    local expected_first = real(word("`base'", 1))
    local expected_second = real(word("`base'", 2))
    close_to `first' `expected_first' `tolerance'
    close_to `second' `expected_second' `tolerance'
}
local xi_message "gracedr: xi() must be a number between 0.5 and 1"
local base_message "gracedr: base() must be at least 2 non-negative numbers"
local winner_message "gracedr: winner() must be a whole number from 0 to the number of arms"
foreach bad_xi in 0.5 1 0.3 2 {
    expect_failure, ///
        rc(198) ///
        message("`xi_message'") ///
        command(`"_gracedr_votes tilt, base(0.5 0.5) winner(1) xi(`bad_xi')"')
}
foreach bad_base in "1" "0.5 -0.5" {
    expect_failure, ///
        rc(198) ///
        message("`base_message'") ///
        command(`"_gracedr_votes tilt, base(`bad_base') winner(1) xi(0.65)"')
}
foreach bad_winner in 3 -1 1.5 {
    expect_failure, ///
        rc(198) ///
        message("`winner_message'") ///
        command(`"_gracedr_votes tilt, base(0.5 0.5) winner(`bad_winner') xi(0.65)"')
}

expect_failure, ///
    rc(198) ///
    message("`arms_message'") ///
    command(`"_gracedr_votes tally, votes(1) weights(1) arms(1001)"')

_gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(0.3)
local p_chi = r(pvalue)
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(0.3)
local p_t = r(pvalue)
_gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(12) pstar(0.3)
local p_f = r(pvalue)
foreach kind in chi t f {
    local above = `p_`kind'' * 1.01
    local below = `p_`kind'' * 0.99
    if "`kind'" == "chi" {
        _gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(`above')
        assert r(vote) == 2
        _gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(`below')
        assert r(vote) == 0
    }
    if "`kind'" == "t" {
        _gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(`above')
        assert r(vote) == 2
        _gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(`below')
        assert r(vote) == 0
    }
    if "`kind'" == "f" {
        _gracedr_votes continuous, ///
            n(10 10 10) sum(100 50 0) ss(1036 286 36) x(12) pstar(`above')
        assert r(vote) == 3
        _gracedr_votes continuous, ///
            n(10 10 10) sum(100 50 0) ss(1036 286 36) x(12) pstar(`below')
        assert r(vote) == 0
    }
}

foreach edge in 10 0 {
    _gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(`edge') pstar(0.3)
    assert r(vote) == 0
}
_gracedr_votes continuous, n(10 10 10) sum(100 50 0) ss(1036 286 36) x(.) pstar(0.3)
assert r(vote) == 0
_gracedr_votes continuous, n(2 10) sum(4 200) ss(10 4018) x(30) pstar(0.3)
assert r(vote) == 1
assert !missing(r(pvalue))
_gracedr_votes continuous, n(2 2) sum(4 60) ss(10 1810) x(100) pstar(0.3)
assert !missing(r(pvalue))
_gracedr_votes continuous, n(10 10) sum(100 50) ss(900 286) x(12) pstar(0.3)
assert r(vote) == 0
assert missing(r(pvalue))
_gracedr_votes continuous, n(10 10) sum(1E2 5e1) ss(1036 286) x(1.2e1) pstar(0.3)
assert r(vote) == 2
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x( 12 ) pstar(0.3)
assert r(vote) == 2
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(.5) pstar(0.3)
assert r(vote) == 1
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(1e1) pstar(0.3)
assert r(vote) == 0
expect_failure, ///
    rc(198) ///
    message("`x_message'") ///
    command(`"_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(.a) pstar(0.3)"')

_gracedr_votes continuous, ///
    n(10 12 8 9 11) ///
    sum(30 60 32 63 66) ///
    ss(108 333 145.5 473 426) ///
    x(20) ///
    pstar(0.3)
assert r(vote) == 1
local expected = Ftail(4, 21.63417660253499, 7.887861549276081)
close_to `r(pvalue)' `expected' `tolerance'
_gracedr_votes continuous, ///
    n(10 12 8 9 11) ///
    sum(30 60 32 63 66) ///
    ss(108 333 145.5 473 426) ///
    x(0) ///
    pstar(0.3)
assert r(vote) == 4
foreach case in "1 2" "2 1" "3 2" {
    gettoken row expected_vote : case
    _gracedr_votes categorical, ///
        table(12 3 5 4 6 4 11 6 7 5 6 5 9 8 13) ///
        arms(5) ///
        row(`row') ///
        pstar(0.3)
    assert r(vote) == `expected_vote'
    local expected = chi2tail(8, 16.398614927428092)
    close_to `r(pvalue)' `expected' `tolerance'
}

_gracedr_votes size, n(5 5 5 5 20) ratio(1 1 1 1 1)
assert r(vote) == 0
_gracedr_votes size, n(2 6 8 8 16) ratio(1 1 1 1 1)
assert r(vote) == 1
_gracedr_votes size, n(1 5) ratio(1 2)
assert r(vote) == 1
_gracedr_votes size, n(1000000000000 1000000000002) ratio(1 1)
assert r(vote) == 1

_gracedr_votes tally, votes(0) weights(1) arms(2)
assert r(winner) == 0
_gracedr_votes tally, votes(5 5 2 1) weights(1 1 1 1.5) arms(5)
assert r(winner) == 5
_gracedr_votes tally, votes(3 3 1 2) weights(1 1 0.2 0.2) arms(3)
assert r(winner) == 3
_gracedr_votes tally, votes(1 2) weights(0.3 0.30000000000001) arms(2)
assert r(winner) == 0
_gracedr_votes tally, votes(1 2) weights(0.3 0.300000000002) arms(2)
assert r(winner) == 2

_gracedr_votes tilt, base(0.1 0.2 0.3 0.15 0.25) winner(3) xi(0.75)
local words = wordcount("`r(probs)'")
assert `words' == 5
local expected_list "0.0625 0.125 0.5625 0.09375 0.15625"
foreach position in 1 2 3 4 5 {
    local actual = real(word("`r(probs)'", `position'))
    local expected = real(word("`expected_list'", `position'))
    close_to `actual' `expected' `tolerance'
}
foreach near_xi in 0.5000001 0.9999999999 {
    _gracedr_votes tilt, base(0.4 0.6) winner(2) xi(`near_xi')
    local total = real(word("`r(probs)'", 1)) + real(word("`r(probs)'", 2))
    close_to `total' 1 `tolerance'
}
_gracedr_votes tilt, base(0.000000001 0.999999999) winner(1) xi(0.65)
local total = real(word("`r(probs)'", 1)) + real(word("`r(probs)'", 2))
close_to `total' 1 `tolerance'
local first_probability = real(word("`r(probs)'", 1))
assert inrange(`first_probability', 0.000000001, 0.000000002)

global foo 1
local odd = char(36) + "foo"
expect_failure, ///
    rc(198) ///
    message("`row_message'") ///
    command(`"_gracedr_votes categorical, table(8 2 2 8) arms(2) row(`macval(odd)') pstar(0.3)"')
expect_failure, ///
    rc(198) ///
    message("`winner_message'") ///
    command(`"_gracedr_votes tilt, base(0.5 0.5) winner(`macval(odd)') xi(0.65)"')
expect_failure, ///
    rc(198) ///
    message("`x_message'") ///
    command(`"`continuous_call' n(10 10) sum(100 50) ss(1036 286) x(`macval(odd)') pstar(0.3)"')
macro drop foo

make_data 3
set seed 4
local user_state = c(rngstate)
_gracedr_votes categorical, table(8 2 2 8) arms(2) row(1) pstar(0.3)
_gracedr_votes continuous, n(10 10) sum(100 50) ss(1036 286) x(12) pstar(0.3)
assert _N == 3
assert x[3] == 30
assert c(rngstate) == "`user_state'"

expect_failure, ///
    rc(198) ///
    message("gracedr: unknown votes subcommand nonsense") ///
    command(`"_gracedr_votes nonsense"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown votes subcommand") ///
    command(`"_gracedr_votes"')

display "certify_votes: all checks passed"
