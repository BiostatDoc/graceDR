version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define metric_value, rclass
    args point metric
    quietly count if point == "`point'" & metric == "`metric'"
    assert r(N) == 1
    quietly summarize value if point == "`point'" & metric == "`metric'"
    return scalar value = r(mean)
    return scalar present = r(N)
end

program define expect_metric
    args point metric expected
    metric_value "`point'" "`metric'"
    if "`expected'" == "." {
        assert r(present) == 0
    }
    else {
        close_to `r(value)' `expected' 0.000000001
    }
end

local tolerance = 1 / 1000000000

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert metrics"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

gracedr setup, ///
    study("`scratch'/six") ///
    n(6) ///
    arms(A B) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(2) ///
    forcedat(4) ///
    seed(1)
local six "`scratch'/six"

clear
quietly set obs 6
generate str10 sex = ""
generate double age = .
generate str10 arm = ""
generate double prob1 = .
generate double prob2 = .
local sexes "male female male female male female"
local ages "30 50 40 60 20 80"
local arms "A B A A B B"
local first "0.5 0.5 1 1 0 0.5"
local second "0.5 0.5 0 0 1 0.5"
forvalues row = 1/6 {
    quietly replace sex = word("`sexes'", `row') in `row'
    quietly replace age = real(word("`ages'", `row')) in `row'
    quietly replace arm = word("`arms'", `row') in `row'
    quietly replace prob1 = real(word("`first'", `row')) in `row'
    quietly replace prob2 = real(word("`second'", `row')) in `row'
}
tempfile trial
quietly save `"`trial'"'

_gracedr_metrics trial, study("`six'")
assert _N == 18
assert point[1] == "run-in" & metric[1] == "smd_max"
assert point[16] == "all" & metric[16] == "pct_deterministic"
expect_metric "run-in" smd_max 0
expect_metric "run-in" smd_sex 0
expect_metric "run-in" smd_age 0
expect_metric "run-in" size_dev_A 0
expect_metric "run-in" size_dev_B 0
expect_metric "n=4" smd_max 2
expect_metric "n=4" smd_sex 2
expect_metric "n=4" smd_age 0
expect_metric "n=4" size_dev_A 1
expect_metric "n=4" size_dev_B 1
expect_metric "end" smd_max 0.707106781186547
expect_metric "end" smd_sex 0.707106781186547
expect_metric "end" smd_age 0.280056016805602
expect_metric "end" size_dev_A 0
expect_metric "end" size_dev_B 0
expect_metric "all" pct_deterministic 50
expect_metric "all" longest_forced_run 2
expect_metric "all" correct_guess 50

quietly use `"`trial'"', clear
quietly replace sex = "" in 2
quietly replace age = . in 2
_gracedr_metrics trial, study("`six'")
expect_metric "run-in" smd_max .
expect_metric "run-in" smd_sex .
expect_metric "run-in" smd_age .
expect_metric "run-in" size_dev_A 0
expect_metric "n=4" smd_sex .
expect_metric "n=4" size_dev_A 1
quietly use `"`trial'"', clear
quietly replace age = . in 2
_gracedr_metrics trial, study("`six'")
expect_metric "run-in" smd_age .
expect_metric "run-in" smd_sex 0
expect_metric "run-in" smd_max 0

gracedr setup, ///
    study("`scratch'/three") ///
    n(6) ///
    arms(A B C) ///
    continuous(age) ///
    runin(0) ///
    seed(2)
local three "`scratch'/three"
clear
quietly set obs 6
generate double age = .
local three_ages "10 20 30 40 50 70"
forvalues row = 1/6 {
    quietly replace age = real(word("`three_ages'", `row')) in `row'
}
generate str10 arm = word("A B C", ceil(_n / 2))
generate double prob1 = 1 / 3
generate double prob2 = 1 / 3
generate double prob3 = 1 / 3
_gracedr_metrics trial, study("`three'")
assert _N == 8
assert point[1] == "end"
expect_metric "end" smd_max 4.02492235949962
expect_metric "end" smd_age 4.02492235949962
expect_metric "end" size_dev_A 0
expect_metric "end" size_dev_B 0
expect_metric "end" size_dev_C 0
expect_metric "all" pct_deterministic 0
expect_metric "all" longest_forced_run 0
expect_metric "all" correct_guess 33.3333333333333

gracedr setup, ///
    study("`scratch'/runs") ///
    n(6) ///
    arms(A B) ///
    categorical(sex: male female) ///
    runin(0) ///
    seed(3)
clear
quietly set obs 6
generate str10 sex = "male"
generate str10 arm = word("A B A A B B", _n)
generate double prob1 = 1
generate double prob2 = 0
quietly replace prob1 = 0 in 2
quietly replace prob2 = 1 in 2
quietly replace prob1 = 0 in 5/6
quietly replace prob2 = 1 in 5/6
quietly replace prob1 = 0.5 in 4
quietly replace prob2 = 0.5 in 4
_gracedr_metrics trial, study("`scratch'/runs")
expect_metric "all" pct_deterministic 83.3333333333333
expect_metric "all" longest_forced_run 2

make_data 3
generate marker = _n
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"_gracedr_metrics trial, study("`scratch'/nothing")"')
assert _N == 3
assert marker[3] == 3
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown metrics subcommand nothing") ///
    command(`"_gracedr_metrics nothing"')

remove_folder "`scratch'"
display "certify_metrics: all checks passed"
