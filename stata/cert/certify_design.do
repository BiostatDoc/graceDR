version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

foreach case in "60 1 1 10" "200 1 1 20" "1000 1 1 100" "60 2 1 12" "60 1 1 1 12" ///
    "101 1 1 12" "5 1 1 5" "60 1.5 1 10" "110 1 1 1 1 1 1 1 1 1 1 1 11" "2 1 1 2" {
    gettoken total case : case
    local expected : word count `case'
    local expected : word `expected' of `case'
    local ratio = trim(substr("`case'", 1, strlen("`case'") - strlen("`expected'")))
    _gracedr_design runin_size, n(`total') ratio(`ratio')
    assert r(n) == `expected'
}

foreach case in "7 1 1 4 3" "10 2 1 7 3" "60 1 1 1 20 20 20" "10 1 1 1 4 3 3" ///
    "11 1 1 1 4 4 3" "1 1 1 1 0" "0 1 1 0 0" "10 1 2 7 1 2 7" "6 1 1 1 1 2 2 1 1" ///
    "10 0.5 0.5 5 5" {
    gettoken total case : case
    tokenize `case'
    local arms = 0
    local values ""
    local counts ""
    while !missing("`1'") {
        local arms = `arms' + 1
        local values "`values' `1'"
        macro shift
    }
    local half = `arms' / 2
    local ratio_text ""
    local expected_text ""
    forvalues position = 1/`arms' {
        local item : word `position' of `values'
        if `position' <= `half' {
            local ratio_text "`ratio_text' `item'"
        }
        else {
            local expected_text "`expected_text' `item'"
        }
    }
    _gracedr_design targets, n(`total') ratio(`ratio_text')
    assert trim("`r(targets)'") == trim("`expected_text'")
}

foreach total of numlist 1/50 {
    _gracedr_design targets, n(`total') ratio(3 2 1)
    local counts `"`r(targets)'"'
    local sum = 0
    local position = 0
    foreach count of local counts {
        local position = `position' + 1
        local ratio_value : word `position' of 3 2 1
        local sum = `sum' + `count'
        assert abs(`count' - `total' * `ratio_value' / 6) < 1
    }
    assert `sum' == `total'
}

_gracedr_design checkpoints, n(60) ratio(1 1) runin(10) forcedat(45 30 30)
assert _N == 4
assert n[1] == 10 & type[1] == "run-in" & target1[1] == 5 & target2[1] == 5
assert n[2] == 30 & type[2] == "forced" & target1[2] == 15 & target2[2] == 15
assert n[3] == 45 & type[3] == "forced" & target1[3] == 23 & target2[3] == 22
assert n[4] == 60 & type[4] == "final" & target1[4] == 30 & target2[4] == 30
quietly ds
assert "`r(varlist)'" == "n type target1 target2"

_gracedr_design checkpoints, n(60) ratio(1 1) runin(10) forcedat(10 60)
assert _N == 2
assert n[1] == 10 & type[1] == "run-in"
assert n[2] == 60 & type[2] == "final"

_gracedr_design checkpoints, n(60) ratio(1 1) runin(0)
assert _N == 1
assert n[1] == 60 & type[1] == "final"

_gracedr_design checkpoints, n(30) ratio(2 1 1) runin(12) forcedat(20)
assert _N == 3
quietly ds
assert "`r(varlist)'" == "n type target1 target2 target3"
assert target1[1] + target2[1] + target3[1] == n[1]
assert target1[2] + target2[2] + target3[2] == n[2]
assert target1[3] == 15 & target2[3] == 8 & target3[3] == 7

expect_failure, ///
    rc(198) ///
    message("gracedr: runin() must be a whole number from 0 to 60") ///
    command(`"_gracedr_design checkpoints, n(60) ratio(1 1) runin(61)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: forcedat() values must be whole numbers from 1 to 60") ///
    command(`"_gracedr_design checkpoints, n(60) ratio(1 1) runin(10) forcedat(61)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: forcedat() values must be whole numbers from 1 to 60") ///
    command(`"_gracedr_design checkpoints, n(60) ratio(1 1) runin(10) forcedat(0)"')
foreach subcommand in targets runin_size {
    expect_failure, ///
        rc(198) ///
        message("gracedr: ratio() values must be positive") ///
        command(`"_gracedr_design `subcommand', n(10) ratio(1 0)"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: ratio() values must be positive") ///
    command(`"_gracedr_design checkpoints, n(10) ratio(1 -1) runin(0)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown design subcommand nonsense") ///
    command(`"_gracedr_design nonsense"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown design subcommand") ///
    command(`"_gracedr_design"')

local base_call "_gracedr_design validate, n(60) arms(A B) ratio(1 1)"
local base_balance "categorical(sex: male female) continuous(age)"

`base_call' `base_balance'
assert r(n) == 60
assert `"`r(arms)'"' == "A B"
assert trim("`r(ratio)'") == "1 1"
assert real(word("`r(weights)'", 1)) == 0.5
assert real(word("`r(weights)'", 2)) == 0.5
assert wordcount("`r(weights)'") == 2
assert r(runin) == 10
assert r(pstar) == 0.3
assert r(xi) == 0.65
assert r(sizebound) == 3
assert "`r(runinmethod)'" == "tilted"
assert "`r(forcedat)'" == ""
assert "`r(varnames)'" == "sex age"
assert "`r(vartypes)'" == "categorical continuous"
assert r(nvars) == 2
assert `"`r(levels1)'"' == `""male" "female""'
assert `"`r(levels2)'"' == ""

_gracedr_design validate, ///
    n(200) ///
    arms("Arm one"  "Arm two"  "Arm three") ///
    ratio(2 1 1) ///
    weights(1 3 2) ///
    pstar(0.2) ///
    xi(0.7) ///
    runin(30) ///
    runinmethod(rar) ///
    forcedat(150 100 100) ///
    sizebound(2) ///
    categorical(race: " White" BLACK | site: a b c) ///
    continuous(age)
assert r(n) == 200
assert `"`r(arms)'"' == `""Arm one" "Arm two" "Arm three""'
assert trim("`r(ratio)'") == "2 1 1"
assert r(runin) == 30
assert r(pstar) == 0.2
assert r(xi) == 0.7
assert r(sizebound) == 2
assert "`r(runinmethod)'" == "rar"
assert "`r(forcedat)'" == "100 150"
assert "`r(varnames)'" == "race site age"
assert "`r(vartypes)'" == "categorical categorical continuous"
assert `"`r(levels1)'"' == `""white" "black""'
assert `"`r(levels2)'"' == `""a" "b" "c""'
local weight_sum = 0
local weight_list `"`r(weights)'"'
foreach weight of local weight_list {
    local weight_sum = `weight_sum' + `weight'
}
local epsilon = 1 / 1000000000000
assert inrange(`weight_sum', 1 - `epsilon', 1 + `epsilon')

_gracedr_design validate, n(60) arms(A B) ratio(2 1) runin(0) `base_balance'
assert r(runin) == 0
_gracedr_design validate, n(60) arms(A B C) `base_balance'
assert trim("`r(ratio)'") == "1 1 1"
assert r(runin) == 12
_gracedr_design validate, n(60) arms(A B) ratio(1 1) runin(60) forcedat(1 60) `base_balance'
assert r(runin) == 60
assert "`r(forcedat)'" == "1 60"
_gracedr_design validate, n(60) arms(A B) ratio(1 1) categorical(sex: Male " Female ")
assert `"`r(levels1)'"' == `""male" "female""'
assert real("`r(weights)'") == 1

foreach bad_n in 1 2.5 abc 0 -5 2000000001 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: n() must be a whole number from 2 to 2000000000") ///
        command(`"_gracedr_design validate, n(`bad_n') arms(A B) `base_balance'"')
}
foreach bad_arms in "A" "A A" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: arms() must be at least 2 unique labels") ///
        command(`"_gracedr_design validate, n(60) arms(`bad_arms') `base_balance'"')
}
expect_failure, ///
    rc(198) ///
    message("option arms() required") ///
    command(`"_gracedr_design validate, n(60) arms() `base_balance'"')
foreach bad_ratio in "1 1 1" "1" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: ratio() must have one value per arm") ///
        command(`"_gracedr_design validate, n(60) arms(A B) ratio(`bad_ratio') `base_balance'"')
}
foreach bad_ratio in "1 0" "1 -1" "1 x" "1 ." {
    expect_failure, ///
        rc(198) ///
        message("gracedr: ratio() values must be positive") ///
        command(`"_gracedr_design validate, n(60) arms(A B) ratio(`bad_ratio') `base_balance'"')
}

expect_failure, ///
    rc(198) ///
    message("gracedr: at least one balance variable is required") ///
    command(`"_gracedr_design validate, n(60) arms(A B) ratio(1 1)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: balance variable names must be unique") ///
    command(`"`base_call' categorical(sex: a b) continuous(sex)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: balance variable names must be unique") ///
    command(`"`base_call' categorical(sex: a b | sex: c d)"')
foreach reserved in id arm code seq {
    expect_failure, ///
        rc(198) ///
        message("gracedr: balance variable name `reserved' is reserved") ///
        command(`"`base_call' continuous(age `reserved')"')
    expect_failure, ///
        rc(198) ///
        message("gracedr: balance variable name `reserved' is reserved") ///
        command(`"`base_call' categorical(`reserved': a b)"')
}
foreach reserved in phase rngstate time study graphs prob1 prob12 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: balance variable name `reserved' is reserved") ///
        command(`"`base_call' continuous(`reserved')"')
}
local label_message "gracedr: arm labels and levels must not contain"
local label_message "`label_message' double quotes, backticks or dollar signs"
local dollar = char(36)
expect_failure, ///
    rc(198) ///
    message("`label_message'") ///
    command(`"_gracedr_design validate, n(60) arms(A B`dollar') categorical(sex: a b)"')
expect_failure, ///
    rc(198) ///
    message("`label_message'") ///
    command(`"`base_call' categorical(sex: a b`dollar')"')
local long_label ""
forvalues position = 1/244 {
    local long_label "`long_label'x"
}
_gracedr_design validate, n(60) arms(A `long_label') categorical(sex: a b)
local too_long "`long_label'x"
expect_failure, ///
    rc(198) ///
    message("gracedr: arm labels and levels must be at most 244 bytes") ///
    command(`"_gracedr_design validate, n(60) arms(A `too_long') categorical(sex: a b)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: arm labels and levels must be at most 244 bytes") ///
    command(`"`base_call' categorical(sex: a `too_long')"')
local minus = char(45)
foreach bad_name in 2x a`minus'b {
    expect_failure, ///
        rc(198) ///
        message("gracedr: `bad_name' is not a valid Stata variable name") ///
        command(`"`base_call' continuous(`bad_name')"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: categorical variable sex needs at least 2 levels") ///
    command(`"`base_call' categorical(sex: male)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: levels of sex must be unique after trimming and lower-casing") ///
    command(`"`base_call' categorical(sex: Male male)"')
foreach bad_entry in "sex" "sex male female" ": male female" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: categorical() entries must look like name: level level") ///
        command(`"`base_call' categorical(`bad_entry')"')
}

foreach bad_value in 0 1 -0.1 1.5 abc {
    expect_failure, ///
        rc(198) ///
        message("gracedr: pstar() must be a number between 0 and 1") ///
        command(`"`base_call' `base_balance' pstar(`bad_value')"')
}
foreach bad_value in 0.5 1 0.3 2 abc {
    expect_failure, ///
        rc(198) ///
        message("gracedr: xi() must be a number between 0.5 and 1") ///
        command(`"`base_call' `base_balance' xi(`bad_value')"')
}
foreach bad_value in 0 2.5 abc -1 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: sizebound() must be a whole number of at least 1") ///
        command(`"`base_call' `base_balance' sizebound(`bad_value')"')
}
foreach bad_value in "1" "1 1 1" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: weights() must have one value per balance variable") ///
        command(`"`base_call' `base_balance' weights(`bad_value')"')
}
foreach bad_value in "1 0" "1 -2" "1 x" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: weights() values must be positive") ///
        command(`"`base_call' `base_balance' weights(`bad_value')"')
}
foreach bad_value in 61 -1 2.5 abc {
    expect_failure, ///
        rc(198) ///
        message("gracedr: runin() must be a whole number from 0 to 60") ///
        command(`"`base_call' `base_balance' runin(`bad_value')"')
}
foreach bad_value in "0" "61" "2.5" "10 abc" "-3" {
    expect_failure, ///
        rc(198) ///
        message("gracedr: forcedat() values must be whole numbers from 1 to 60") ///
        command(`"`base_call' `base_balance' forcedat(`bad_value')"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: runinmethod() must be tilted or rar") ///
    command(`"`base_call' `base_balance' runinmethod(foo)"')

expect_failure, ///
    rc(198) ///
    message("gracedr: sex age is not a valid Stata variable name") ///
    command(`"`base_call' categorical(sex age: a b)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: a b is not a valid Stata variable name") ///
    command(`"`base_call' continuous("a b")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: balance variable names must be unique") ///
    command(`"`base_call' continuous(age age)"')
local name32 "abcdefghabcdefghabcdefghabcdefgh"
`base_call' continuous(`name32')
assert "`r(varnames)'" == "`name32'"
expect_failure, ///
    rc(198) ///
    message("gracedr: `name32'i is not a valid Stata variable name") ///
    command(`"`base_call' continuous(`name32'i)"')
`base_call' continuous(ID Arm)
assert "`r(varnames)'" == "ID Arm"
expect_failure, ///
    rc(198) ///
    message("gracedr: categorical variable sex needs at least 2 levels") ///
    command(`"`base_call' categorical(sex:)"')
foreach bad_levels in "Male MALE" `""  male" male"' {
    expect_failure, ///
        rc(198) ///
        message("gracedr: levels of sex must be unique after trimming and lower-casing") ///
        command(`"`base_call' categorical(sex: `bad_levels')"')
}
foreach entries in "sex: a b |" "| sex: a b" "sex: a b ||" "sex: a b |  " {
    `base_call' categorical(`entries')
    assert "`r(varnames)'" == "sex"
    assert r(nvars) == 1
}
`base_call' categorical(| sex: a b || site: x y |)
assert "`r(varnames)'" == "sex site"
assert r(nvars) == 2
local tab = char(9)
`base_call' categorical(sex: "`tab'Male`tab'" female)
assert `"`r(levels1)'"' == `""male" "female""'

foreach case in "60 2 1 12" "200 1 1 20" "1000 1 1 100" "2 1 1 2" "5 1 1 5" "60 1.5 1 10" ///
    "30 1 1 10" "70 1 1 10" "110 1 1 12" "1010 1 1 102" {
    gettoken total case : case
    gettoken first_ratio case : case
    gettoken second_ratio expected : case
    _gracedr_design validate, ///
        n(`total') ///
        arms(A B) ///
        ratio(`first_ratio' `second_ratio') ///
        `base_balance'
    assert r(runin) == `expected'
}
_gracedr_design validate, n(60) arms(A B C D E F G H I J K L) `base_balance'
assert r(runin) == 12

_gracedr_design targets, n(10) ratio(0.1 0.2 0.7)
assert "`r(targets)'" == "1 2 7"
_gracedr_design targets, n(10) ratio(0.3 0.3 0.4)
assert "`r(targets)'" == "3 3 4"
_gracedr_design targets, n(100) ratio(1 1 1)
assert "`r(targets)'" == "34 33 33"
_gracedr_design targets, n(2000000000) ratio(1 1 1)
assert "`r(targets)'" == "666666667 666666667 666666666"
_gracedr_design checkpoints, n(2000000000) ratio(1 1) runin(0)
assert _N == 1
assert n[1] == 2000000000 & target1[1] == 1000000000 & target2[1] == 1000000000
_gracedr_design validate, n(2000000000) arms(A B) `base_balance'
assert r(n) == 2000000000
assert r(runin) == 200000000

_gracedr_design checkpoints, n(60) ratio(1 1) runin(60)
assert _N == 1
assert n[1] == 60 & type[1] == "final"

_gracedr_design validate, n(60) arms(A B) ratio(1 1) weights(1 3 2) ///
    categorical(sex: a b | site: x y) continuous(age)
local weight_list `"`r(weights)'"'
local epsilon = 1 / 1000000000000
assert inrange(real(word("`weight_list'", 1)), 1 / 6 - `epsilon', 1 / 6 + `epsilon')
assert inrange(real(word("`weight_list'", 2)), 0.5 - `epsilon', 0.5 + `epsilon')
assert inrange(real(word("`weight_list'", 3)), 1 / 3 - `epsilon', 1 / 3 + `epsilon')
_gracedr_design validate, n(60) arms(A B) ratio(1 1) ///
    categorical(sex: a b | site: x y) continuous(age)
local weight_list `"`r(weights)'"'
foreach position in 1 2 3 {
    assert inrange(real(word("`weight_list'", `position')), 1 / 3 - `epsilon', 1 / 3 + `epsilon')
}
_gracedr_design validate, n(60) arms(A B) ratio(1 1) continuous(age) categorical(sex: a b)
assert "`r(varnames)'" == "sex age"
assert "`r(vartypes)'" == "categorical continuous"

expect_failure, ///
    rc(198) ///
    message("gracedr: forcedat() values must be whole numbers from 1 to 60") ///
    command(`"`base_call' `base_balance' forcedat(100)"')
_gracedr_design validate, n(200) arms(A B) forcedat(9 10 100) `base_balance'
assert "`r(forcedat)'" == "9 10 100"
_gracedr_design validate, n(60) arms(A B) forcedat(30 30) `base_balance'
assert "`r(forcedat)'" == "30"
_gracedr_design validate, n(60) arms(A B) forcedat(10(10)50) `base_balance'
assert "`r(forcedat)'" == "10 20 30 40 50"
_gracedr_design validate, n(60) arms(A B) runin(10) forcedat(10) `base_balance'
assert "`r(forcedat)'" == "10"
expect_failure, ///
    rc(198) ///
    message("gracedr: runinmethod() must be tilted or rar") ///
    command(`"`base_call' `base_balance' runinmethod(RAR)"')

make_data 3
_gracedr_design validate, n(60) arms(A B) `base_balance'
assert _N == 3
assert x[3] == 30
assert label[2] == "row2"

display "certify_design: all checks passed"
