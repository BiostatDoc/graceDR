version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

local call "_gracedr_generate check, varnames(sex age) vartypes(categorical continuous)"
local call "`call' levelcounts(2 0)"

`call'
assert "`r(start1)'" == ".5 .5"
assert "`r(end1)'" == ".5 .5"
assert "`r(start2)'" == "0 1"
assert "`r(end2)'" == "0 1"
`call' probs(sex: 0.3 0.7) meansd(age: 60 10)
assert "`r(start1)'" == "0.3 0.7"
assert "`r(end1)'" == "0.3 0.7"
assert "`r(start2)'" == "60 10"
`call' generator(drift) driftto(sex: 0.8 0.2 | age: 72 8) probs(sex: 0.2 0.8)
assert "`r(start1)'" == "0.2 0.8"
assert "`r(end1)'" == "0.8 0.2"
assert "`r(start2)'" == "0 1"
assert "`r(end2)'" == "72 8"
`call' generator(drift) driftto(age: 72 8)
assert "`r(end1)'" == ".5 .5"
assert "`r(end2)'" == "72 8"
`call' generator(iid)
assert "`r(start2)'" == "0 1"

local third "_gracedr_generate check, varnames(race) vartypes(categorical) levelcounts(3)"
`third' probs(race: 0.62 0.23 0.15)
assert "`r(start1)'" == "0.62 0.23 0.15"
`third' probs(race: 0.5 0.5 0)
assert "`r(start1)'" == "0.5 0.5 0"

foreach case in ///
    "probs(sex: 0.3 0.6)#gracedr: probs() for sex needs 2 probabilities" ///
    "probs(sex: 0.3 0.7 0)#gracedr: probs() for sex needs 2 probabilities" ///
    "probs(sex: 1.2 -0.2)#gracedr: probs() for sex needs 2 probabilities" ///
    "meansd(age: 60 0)#gracedr: meansd() for age needs a mean and an sd greater than 0" ///
    "meansd(age: 60 -3)#gracedr: meansd() for age needs a mean and an sd greater than 0" ///
    "meansd(age: 60)#gracedr: meansd() for age needs a mean and an sd greater than 0" ///
    "probs(height: 1 0)#gracedr: probs() names an unknown balance variable height" ///
    "meansd(height: 1 1)#gracedr: meansd() names an unknown balance variable height" ///
    "probs(age: 0.5 0.5)#gracedr: probs() applies only to categorical variables (age)" ///
    "meansd(sex: 0 1)#gracedr: meansd() applies only to continuous variables (sex)" ///
    "probs(sex: 0.5 0.5 | sex: 0.4 0.6)#gracedr: probs() names sex more than once" ///
    "probs(sex 0.5 0.5)#gracedr: probs() must look like name: number number" ///
    "probs(sex:)#gracedr: probs() must look like name: number number" ///
    "probs(sex: a b)#gracedr: probs() must look like name: number number" ///
    "driftto(sex: 1 0)#gracedr: driftto() needs generator(drift)" ///
    "generator(drift)#gracedr: generator(drift) needs driftto()" ///
    "generator(wander)#gracedr: generator() must be iid or drift" ///
    "generator(drift) driftto(sex: 0.9 0.2)#gracedr: driftto() for sex needs 2 probabilities" ///
    "generator(drift) driftto(age: 70 0)#gracedr: driftto() for age needs a mean and an sd" {
    gettoken bad_option expected : case, parse("#")
    local expected = substr(`"`expected'"', 2, .)
    expect_failure, ///
        rc(198) ///
        message(`"`expected'"') ///
        command(`"`call' `bad_option'"')
}

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert generate"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
gracedr setup, ///
    study("`scratch'/study") ///
    n(60) ///
    arms(A B) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    seed(1)
local study "`scratch'/study"

set seed 7
local user_state = c(rngstate)
_gracedr_generate stream, ///
    study("`study'") ///
    n(4000) ///
    probs(sex: 0.3 0.7 | race: 0.5 0.3 0.2) ///
    meansd(age: 60 10)
assert _N == 4000
local moved = "`c(rngstate)'" == "`user_state'"
assert `moved' == 0
assert inlist(sex, "male", "female")
assert inlist(race, "white", "black", "other")
quietly count if sex == "male"
assert inrange(r(N) / 4000, 0.28, 0.32)
quietly count if race == "white"
assert inrange(r(N) / 4000, 0.47, 0.53)
quietly count if race == "other"
assert inrange(r(N) / 4000, 0.17, 0.23)
quietly summarize age
assert inrange(r(mean), 59.5, 60.5)
assert inrange(r(sd), 9.5, 10.5)
tempfile first_run
quietly save `"`first_run'"'
set seed 7
_gracedr_generate stream, ///
    study("`study'") ///
    n(4000) ///
    probs(sex: 0.3 0.7 | race: 0.5 0.3 0.2) ///
    meansd(age: 60 10)
quietly cf _all using `"`first_run'"'
set seed 8
_gracedr_generate stream, ///
    study("`study'") ///
    n(4000) ///
    probs(sex: 0.3 0.7 | race: 0.5 0.3 0.2) ///
    meansd(age: 60 10)
capture quietly cf _all using `"`first_run'"'
assert _rc == 9

set seed 11
_gracedr_generate stream, study("`study'") n(51) generator(drift) ///
    probs(sex: 1 0) ///
    driftto(sex: 0 1 | age: 20 0.000000001) ///
    meansd(age: 10 0.000000001)
assert sex[1] == "male"
assert sex[51] == "female"
quietly count if sex == "male" in 1/25
local early_male = r(N)
quietly count if sex == "male" in 27/51
local late_male = r(N)
assert inrange(`early_male', `late_male' + 1, 1e9)
assert inrange(age[1], 9.999999, 10.000001)
assert inrange(age[51], 19.999999, 20.000001)
assert inrange(age[26], 14.999999, 15.000001)
assert inrange(age[11], 11.999999, 12.000001)

_gracedr_generate stream, study("`study'") n(1)
assert _N == 1
_gracedr_generate stream, study("`study'") n(0)
assert _N == 0

expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"_gracedr_generate stream, study("`scratch'/nothing") n(5)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown generate subcommand nothing") ///
    command(`"_gracedr_generate nothing"')

make_data 3
generate marker = _n
set seed 5
local user_state = c(rngstate)
expect_failure, ///
    rc(198) ///
    message("gracedr: probs() must look like name: number number") ///
    command(`"_gracedr_generate stream, study("`study'") n(5) probs(sex)"')
assert _N == 3
assert marker[3] == 3
assert c(rngstate) == "`user_state'"

remove_folder "`scratch'"
display "certify_generate: all checks passed"
