version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert simulate"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

local design "n(12) arms(A B) categorical(sex: male female) continuous(age)"
local design "`design' runin(4) forcedat(8)"
local all_methods "mmsb srs blocks minimization msb"

gracedr simulate, ///
    `design' ///
    methods(`all_methods') ///
    nsims(3) ///
    seed(5) ///
    saving("`scratch'/first.dta") ///
    summary("`scratch'/first_summary.dta")
assert r(nsims) == 3
assert "`r(methods)'" == "`all_methods'"
preserve
quietly use "`scratch'/first.dta", clear
quietly ds
assert "`r(varlist)'" == "sim method point metric value"
assert _N == 3 * 5 * 18
quietly levelsof method, local(found_methods) clean
assert "`found_methods'" == "blocks minimization mmsb msb srs"
quietly summarize sim
assert r(min) == 1 & r(max) == 3
quietly levelsof point, local(found_points) clean
assert "`found_points'" == "all end n=8 run-in"
quietly count if metric == "correct_guess" & !inrange(value, 0, 100)
assert r(N) == 0
quietly count if substr(metric, 1, 9) == "size_dev_" & !inrange(value, 0, 12)
assert r(N) == 0
quietly count if metric == "pct_deterministic" & !inrange(value, 0, 100)
assert r(N) == 0
quietly count if method == "srs" & metric == "pct_deterministic" & value == 0
assert r(N) == 3
quietly count if method == "srs" & metric == "longest_forced_run" & value == 0
assert r(N) == 3
quietly count if method == "srs" & metric == "correct_guess" & inrange(value, 49.999999, 50.000001)
assert r(N) == 3
quietly count if method == "blocks" & substr(metric, 1, 9) == "size_dev_" & point == "end"
assert r(N) == 6
quietly count if method == "blocks" & substr(metric, 1, 9) == "size_dev_" ///
    & point == "end" & value == 0
assert r(N) == 6
quietly count if method == "mmsb" & substr(metric, 1, 9) == "size_dev_" ///
    & inlist(point, "run-in", "n=8", "end")
assert r(N) == 18
quietly count if method == "mmsb" & substr(metric, 1, 9) == "size_dev_" ///
    & inlist(point, "run-in", "n=8", "end") & value == 0
assert r(N) == 18
restore

preserve
quietly use "`scratch'/first_summary.dta", clear
quietly ds
assert "`r(varlist)'" == "method point metric mean sd q95 q99 max"
assert _N == 5 * 18
quietly count if method == "srs" & metric == "correct_guess"
assert r(N) == 1
quietly summarize mean if method == "srs" & metric == "correct_guess"
assert inrange(r(mean), 49.999999, 50.000001)
quietly summarize sd if method == "srs" & metric == "correct_guess"
assert inrange(r(mean), -0.000001, 0.000001)
quietly summarize max if method == "srs" & metric == "pct_deterministic"
assert r(mean) == 0
restore

gracedr simulate, ///
    `design' ///
    methods(`all_methods') ///
    nsims(3) ///
    seed(5) ///
    saving("`scratch'/second.dta")
preserve
quietly use "`scratch'/second.dta", clear
quietly cf _all using "`scratch'/first.dta"
restore
gracedr simulate, ///
    `design' ///
    methods(`all_methods') ///
    nsims(3) ///
    seed(6) ///
    saving("`scratch'/other_seed.dta")
preserve
quietly use "`scratch'/other_seed.dta", clear
capture quietly cf _all using "`scratch'/first.dta"
assert _rc == 9
restore

gracedr simulate, `design' methods(srs mmsb) nsims(3) seed(5) saving("`scratch'/pair.dta")
gracedr simulate, `design' methods(srs) nsims(3) seed(5) saving("`scratch'/single.dta")
preserve
quietly use "`scratch'/pair.dta", clear
quietly keep if method == "srs"
tempfile pair_srs
quietly save `"`pair_srs'"'
quietly use "`scratch'/single.dta", clear
quietly cf _all using `"`pair_srs'"'
restore
gracedr simulate, `design' methods(mmsb) nsims(3) seed(5) saving("`scratch'/mmsb_only.dta")
preserve
quietly use "`scratch'/mmsb_only.dta", clear
tempfile mmsb_only
quietly save `"`mmsb_only'"'
quietly use "`scratch'/first.dta", clear
quietly keep if method == "mmsb"
quietly cf _all using `"`mmsb_only'"'
restore

gracedr simulate, `design' methods(srs mmsb) nsims(2) seed(5) saving("`scratch'/two_sims.dta")
gracedr simulate, `design' methods(srs mmsb) nsims(4) seed(5) saving("`scratch'/four_sims.dta")
preserve
quietly use "`scratch'/four_sims.dta", clear
quietly keep if sim == 1 | sim == 2
tempfile four_first
quietly save `"`four_first'"'
quietly use "`scratch'/two_sims.dta", clear
quietly cf _all using `"`four_first'"'
restore

gracedr setup, ///
    study("`scratch'/study") ///
    n(12) ///
    arms(A B) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(4) ///
    forcedat(8) ///
    seed(3)
local study "`scratch'/study"
local before_files : dir "`study'" files "*"
local before_files : list sort before_files
preserve
quietly use "`study'/design.dta", clear
tempfile design_before
quietly save `"`design_before'"'
restore
gracedr simulate, ///
    study("`study'") ///
    methods(`all_methods') ///
    nsims(3) ///
    seed(5) ///
    saving("`scratch'/from_study.dta")
local after_files : dir "`study'" files "*"
local after_files : list sort after_files
assert `"`before_files'"' == `"`after_files'"'
preserve
quietly use "`study'/design.dta", clear
quietly cf _all using `"`design_before'"'
quietly use "`scratch'/from_study.dta", clear
quietly cf _all using "`scratch'/first.dta"
restore

local extra_files : dir "`study'" files "*"
foreach name of local extra_files {
    if "`name'" == "design.dta" {
        continue
    }
    quietly erase "`study'/`name'"
}
local lonely_files : dir "`study'" files "*"
local lonely_count : word count `lonely_files'
local lonely_first : word 1 of `lonely_files'
assert `lonely_count' == 1 & "`lonely_first'" == "design.dta"
gracedr simulate, ///
    study("`study'") ///
    methods(mmsb srs) ///
    nsims(2) ///
    seed(9) ///
    saving("`scratch'/design_only.dta")
local after_lonely : dir "`study'" files "*"
local after_count : word count `after_lonely'
local after_first : word 1 of `after_lonely'
assert `after_count' == 1 & "`after_first'" == "design.dta"

gracedr simulate, ///
    `design' ///
    methods(mmsb srs) ///
    nsims(2) ///
    seed(5) ///
    generator(drift) ///
    probs(sex: 0.9 0.1) ///
    driftto(sex: 0.1 0.9 | age: 80 5) ///
    meansd(age: 40 5) ///
    saving("`scratch'/drift.dta")
preserve
quietly use "`scratch'/drift.dta", clear
assert _N == 2 * 2 * 18
restore
gracedr simulate, ///
    `design' ///
    methods(minimization) ///
    nsims(2) ///
    seed(5) ///
    phigh(0.95) ///
    meansd(age: 50 8) ///
    saving("`scratch'/high.dta")

gracedr simulate, ///
    n(10) ///
    arms(A B C) ///
    ratio(2 1 1) ///
    categorical(sex: male female) ///
    runin(0) ///
    methods(blocks mmsb) ///
    nsims(2) ///
    seed(2) ///
    saving("`scratch'/three_arms.dta")
preserve
quietly use "`scratch'/three_arms.dta", clear
quietly levelsof point, local(three_points) clean
assert "`three_points'" == "all end"
quietly count if method == "blocks" & metric == "size_dev_A" & point == "end"
assert r(N) == 2
restore

gracedr simulate, ///
    n(12) ///
    arms(A B C) ///
    ratio(2 1 1) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(4) ///
    methods(minimization msb mmsb srs) ///
    nsims(2) ///
    seed(4) ///
    saving("`scratch'/three_rules.dta")
preserve
quietly use "`scratch'/three_rules.dta", clear
assert _N == 2 * 4 * 15
quietly count if method == "minimization" & metric == "size_dev_C"
assert r(N) == 4
restore
foreach variables in "categorical(sex: male female | race: a b c)" "continuous(age weight)" {
    gracedr simulate, ///
        n(10) ///
        arms(A B) ///
        `variables' ///
        runin(4) ///
        runinmethod(rar) ///
        methods(`all_methods') ///
        nsims(2) ///
        seed(8) ///
        saving("`scratch'/shapes.dta")
    preserve
    quietly use "`scratch'/shapes.dta", clear
    quietly count if missing(value) & (substr(metric, 1, 4) == "size" | ///
        substr(metric, 1, 3) == "pct" | substr(metric, 1, 4) == "long" | ///
        metric == "correct_guess")
    assert r(N) == 0
    restore
}
gracedr simulate, n(2) arms(A B) categorical(sex: male female) methods(`all_methods') ///
    nsims(2) seed(3) runin(2) saving("`scratch'/tiny.dta")
preserve
quietly use "`scratch'/tiny.dta", clear
assert _N == 2 * 5 * 11
restore

set rng kiss32
set seed 17
local kiss_state = c(rngstate)
gracedr simulate, `design' methods(srs mmsb) nsims(3) seed(5) saving("`scratch'/kiss.dta")
assert c(rng) == "kiss32"
assert c(rngstate) == "`kiss_state'"
preserve
quietly use "`scratch'/kiss.dta", clear
tempfile kiss_results
quietly save `"`kiss_results'"'
quietly use "`scratch'/pair.dta", clear
quietly cf _all using `"`kiss_results'"'
restore
set rng default
set seed 424242
local user_state = c(rngstate)

mata: seeds = gd_distinct_seeds(30000)
mata: st_local("seed_count", strofreal(rows(uniqrows(seeds))))
assert `seed_count' == 30000
mata: seeds = gd_distinct_seeds(1)
mata: st_local("single_seed", strofreal(rows(seeds)))
assert `single_seed' == 1
mata: seeds = gd_distinct_seeds(2)
mata: st_local("two_seeds", strofreal(rows(uniqrows(seeds))))
assert `two_seeds' == 2

local study_call "gracedr simulate, study("`study'")"
foreach option in "ratio(1 1)" "weights(1 1)" "pstar(0.3)" "xi(0.65)" "runin(4)" ///
    "runinmethod(tilted)" "forcedat(8)" "sizebound(3)" "categorical(sex: a b)" ///
    "continuous(age)" "n(12)" "arms(A B)" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: use either study() or the design options, not both") ///
        command(`"`study_call' `option' methods(srs) nsims(2) seed(1)"')
}
local study_files : dir "`scratch'/study" files "*"
local run_options "methods(srs) nsims(2) seed(1)"
local design_call "gracedr simulate, `design'"
local same "`scratch'/same.dta"
expect_failure, ///
    rc(198) ///
    message("gracedr: saving() must not point into the study folder") ///
    command(`"`study_call' `run_options' saving("`scratch'/study/design.dta")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: summary() must not point into the study folder") ///
    command(`"`study_call' `run_options' summary("`scratch'/study/out.dta")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: saving() and summary() must be different files") ///
    command(`"`design_call' `run_options' saving("`same'") summary("`same'")"')
expect_failure, ///
    rc(603) ///
    message("gracedr: could not save the summary to") ///
    command(`"`design_call' `run_options' summary("`scratch'/missing/x.dta")"')
local after_study_files : dir "`scratch'/study" files "*"
assert `"`study_files'"' == `"`after_study_files'"'

set seed 424242
local user_state = c(rngstate)
local user_rng = c(rng)
make_data 3
generate marker = _n
gracedr simulate, `design' methods(srs) nsims(2) seed(1)
assert _N == 3
assert marker[3] == 3
assert c(rngstate) == "`user_state'"
assert c(rng) == "`user_rng'"
gracedr simulate, `design' methods(srs) nsims(2) seed(1) clear
assert _N == 2 * 18
assert "`: type value'" == "double"
quietly describe
assert r(k) == 5

mata: values = (1 \ 2 \ 3 \ 4)
mata: st_local("q95", strofreal(gd_quantile7(values, 0.95), "%21.17g"))
mata: st_local("q99", strofreal(gd_quantile7(values, 0.99), "%21.17g"))
mata: st_local("q0", strofreal(gd_quantile7(values, 0), "%21.17g"))
mata: st_local("single", strofreal(gd_quantile7((7), 0.95), "%21.17g"))
close_to `q95' 3.85 0.000000000001
close_to `q99' 3.97 0.000000000001
close_to `q0' 1 0.000000000001
close_to `single' 7 0.000000000001
mata: summary = gd_summary_column((2 \ 4 \ . \ 6))
mata: st_local("summary_mean", strofreal(summary[1], "%21.17g"))
mata: st_local("summary_sd", strofreal(summary[2], "%21.17g"))
mata: st_local("summary_max", strofreal(summary[5], "%21.17g"))
close_to `summary_mean' 4 0.000000000001
close_to `summary_sd' 2 0.000000000001
close_to `summary_max' 6 0.000000000001
mata: summary = gd_summary_column((. \ .))
mata: st_local("summary_none", strofreal(cols(summary) - missing(summary)))
assert `summary_none' == 0
mata: summary = gd_summary_column((5))
mata: st_local("summary_one", strofreal(summary[2]))
assert "`summary_one'" == "."

local bad "`design' nsims(2) seed(1)"
local fractional_call "gracedr simulate, n(10) arms(A B) ratio(1.5 1) categorical(sex: a b)"
local tiny_call "gracedr simulate, n(1) arms(A B) categorical(sex: a b)"
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown method bogus; choose from mmsb srs blocks minimization msb") ///
    command(`"gracedr simulate, `bad' methods(srs bogus)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: methods() must be a non-empty set of unique method names") ///
    command(`"gracedr simulate, `bad' methods(srs srs)"')
foreach bad_sims in 0 1.5 abc -2 100000001 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: nsims() must be a whole number from 1 to 100000000") ///
        command(`"gracedr simulate, `design' methods(srs) seed(1) nsims(`bad_sims')"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: seed() must be a whole number from 0 to 2147483647") ///
    command(`"gracedr simulate, `design' methods(srs) nsims(2) seed(-1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: seed() must be a whole number from 0 to 2147483647") ///
    command(`"gracedr simulate, `design' methods(srs) nsims(2) seed(abc)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: use either study() or the design options, not both") ///
    command(`"gracedr simulate, study("`study'") n(5) methods(srs) nsims(2) seed(1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: simulate needs study() or n() and arms()") ///
    command(`"gracedr simulate, methods(srs) nsims(2) seed(1)"')
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"gracedr simulate, study("`scratch'/nothing") methods(srs) nsims(2) seed(1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: blocks needs whole-number ratio values") ///
    command(`"`fractional_call' methods(blocks) nsims(2) seed(1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: phigh() must be a number greater than 0 and less than 1") ///
    command(`"gracedr simulate, `bad' methods(srs) phigh(1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: generator(drift) needs driftto()") ///
    command(`"gracedr simulate, `bad' methods(srs) generator(drift)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: probs() for sex needs 2 probabilities") ///
    command(`"gracedr simulate, `bad' methods(srs) probs(sex: 0.5 0.6)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: n() must be a whole number from 2 to 2000000000") ///
    command(`"`tiny_call' methods(srs) nsims(2) seed(1)"')
expect_failure, ///
    rc(603) ///
    message("gracedr: could not save the results to") ///
    command(`"gracedr simulate, `bad' methods(srs) saving("`scratch'/missing/folder/x.dta")"')
assert _N == 2 * 18
assert c(rngstate) == "`user_state'"

remove_folder "`scratch'"
display "certify_simulate: all checks passed"
