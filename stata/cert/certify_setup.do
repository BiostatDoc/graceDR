version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert setup"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
local balance "categorical(sex: male female | race: white black other) continuous(age)"

make_data 3
set seed 777
local user_state = c(rngstate)
local user_rng = c(rng)
gracedr setup, study("`scratch'/one") n(60) arms(A B) `balance' seed(12345)
assert _N == 3
assert x[3] == 30
assert c(rngstate) == "`user_state'"
assert c(rng) == "`user_rng'"
assert r(seed) == 12345
foreach name in design participants codes audit state {
    assert fileexists("`scratch'/one/`name'.dta")
}

local one "`scratch'/one"
foreach case in "n 60" "arms A B" "ratio 1 1" "runin 10" "runinmethod tilted" ///
    "sizebound 3" "nvars 3" "varnames sex race age" "vartypes categorical categorical continuous" {
    gettoken setting expected : case
    local expected = strtrim("`expected'")
    get_setting "`one'" "`setting'"
    assert "`r(value)'" == "`expected'"
}
get_setting "`one'" "pstar"
assert real("`r(value)'") == 0.3
get_setting "`one'" "xi"
assert real("`r(value)'") == 0.65
get_setting "`one'" "forcedat"
assert "`r(value)'" == ""
get_setting "`one'" "levels1"
assert `"`r(value)'"' == `""male" "female""'
get_setting "`one'" "levels2"
assert `"`r(value)'"' == `""white" "black" "other""'
get_setting "`one'" "levels3"
assert `"`r(value)'"' == ""
get_setting "`one'" "weights"
assert wordcount("`r(value)'") == 3
preserve
_gracedr_study read, study("`one'") name(design)
assert order == _n
assert "`: type value'" == "strL"
restore

preserve
_gracedr_study read, study("`one'") name(participants)
assert _N == 0
quietly ds
assert "`r(varlist)'" == "seq id sex race age arm code prob1 prob2 phase rngstate time"
assert "`: type seq'" == "long"
assert substr("`: type id'", 1, 3) == "str"
assert substr("`: type sex'", 1, 3) == "str"
assert "`: type age'" == "double"
assert "`: type prob1'" == "double"
assert "`: type rngstate'" == "strL"
assert "`: type time'" == "double"
assert "`: format time'" == "%tc"
_gracedr_study read, study("`one'") name(codes)
assert _N == 0
quietly ds
assert "`r(varlist)'" == "code arm status id"
_gracedr_study read, study("`one'") name(state)
assert _N == 1
assert seed[1] == 12345
assert generator[1] == "mt64"
assert format_version[1] == 1
_gracedr_study read, study("`one'") name(audit)
assert _N == 1
assert action[1] == "create"
assert id[1] == "(study)"
assert reason[1] == "study created"
assert !missing(time[1])
restore

expect_failure, ///
    rc(602) ///
    message("gracedr: a study already exists in `one'") ///
    command(`"gracedr setup, study("`one'") n(30) arms(A B) `balance'"')
get_setting "`one'" "n"
assert "`r(value)'" == "60"
assert !fileexists("`one'/design.bak")

gracedr setup, study("`scratch'/two") n(60) arms(A B) `balance'
local drawn_seed = r(seed)
assert inrange(`drawn_seed', 0, 2147483647)
assert `drawn_seed' == floor(`drawn_seed')
preserve
_gracedr_study read, study("`scratch'/two") name(state)
assert seed[1] == `drawn_seed'
restore
assert c(rngstate) == "`user_state'"

gracedr setup, ///
    study("`scratch'/three") ///
    n(100) ///
    arms(A B) ///
    ratio(2 1) ///
    weights(1 2 1) ///
    pstar(0.2) ///
    xi(0.7) ///
    runin(20) ///
    runinmethod(rar) ///
    forcedat(60 40) ///
    sizebound(2) ///
    categorical(sex: male female) ///
    continuous(age weight) ///
    seed(1)
local three "`scratch'/three"
get_setting "`three'" "ratio"
assert "`r(value)'" == "2 1"
get_setting "`three'" "runin"
assert "`r(value)'" == "20"
get_setting "`three'" "runinmethod"
assert "`r(value)'" == "rar"
get_setting "`three'" "forcedat"
assert "`r(value)'" == "40 60"
get_setting "`three'" "sizebound"
assert "`r(value)'" == "2"
get_setting "`three'" "varnames"
assert "`r(value)'" == "sex age weight"
get_setting "`three'" "weights"
local epsilon = 1 / 1000000000000
assert inrange(real(word("`r(value)'", 2)), 0.5 - `epsilon', 0.5 + `epsilon')

expect_failure, ///
    rc(198) ///
    message("gracedr: n() must be a whole number from 2 to 2000000000") ///
    command(`"gracedr setup, study("`scratch'/four") n(1) arms(A B) `balance'"')
local long_label ""
forvalues position = 1/245 {
    local long_label "`long_label'x"
}
expect_failure, ///
    rc(198) ///
    message("gracedr: arm labels and levels must be at most 244 bytes") ///
    command(`"gracedr setup, study("`scratch'/four") n(60) arms(A `long_label') `balance'"')
_gracedr_study folder, study("`scratch'/four")
assert r(found) == 0
expect_failure, ///
    rc(198) ///
    message("gracedr: arms() must be at least 2 unique labels") ///
    command(`"gracedr setup, study("`scratch'/four") n(60) arms(A) `balance'"')
_gracedr_study folder, study("`scratch'/four")
assert r(found) == 0
expect_failure, ///
    rc(603) ///
    message("gracedr: could not create the study folder") ///
    command(`"gracedr setup, study("`scratch'/missing/deeper") n(60) arms(A B) `balance'"')
foreach reserved in phase rngstate time study graphs prob1 prob2 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: balance variable name `reserved' is reserved") ///
        command(`"gracedr setup, study("`scratch'/four") n(60) arms(A B) continuous(`reserved')"')
}
local dollar = char(36)
local message_start "gracedr: arm labels and levels must not contain"
local message "`message_start' double quotes, backticks or dollar signs"
expect_failure, ///
    rc(198) ///
    message("`message'") ///
    command(`"gracedr setup, study("`scratch'/four") n(60) arms(A B`dollar') `balance'"')
local levels_call "gracedr setup, study("`scratch'/four") n(60) arms(A B)"
expect_failure, ///
    rc(198) ///
    message("`message'") ///
    command(`"`levels_call' categorical(sex: male fe`dollar')"')
_gracedr_study folder, study("`scratch'/four")
assert r(found) == 0

gracedr setup, ///
    study("`scratch'/example") ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    codes("`stata_dir'/data/example_codes.csv") ///
    seed(20260611)
_gracedr_study read, study("`scratch'/example") name(codes)
assert _N == 200
gracedr setup, ///
    study("`scratch'/three arms") ///
    n(90) ///
    arms(A B C) ///
    ratio(2 1 1) ///
    categorical(sex: male female) ///
    runin(0)
get_setting "`scratch'/three arms" "runin"
assert "`r(value)'" == "0"
preserve
_gracedr_study read, study("`scratch'/three arms") name(participants)
quietly ds
assert "`r(varlist)'" == "seq id sex arm code prob1 prob2 prob3 phase rngstate time"
restore

gracedr
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown subcommand nonsense") ///
    command(`"gracedr nonsense, study("`one'")"')
quietly mkdir "`scratch'/phantom_ado"
quietly findfile gracedr.ado
filefilter "`r(fn)'" "`scratch'/phantom_ado/gracedr.ado", ///
    from("simulate codes") ///
    to("phantom codes")
adopath ++ "`scratch'/phantom_ado"
program drop gracedr
expect_failure, ///
    rc(199) ///
    message("gracedr: phantom is not available yet") ///
    command(`"gracedr phantom, study("`one'")"')
adopath - "`scratch'/phantom_ado"
program drop gracedr
quietly erase "`scratch'/phantom_ado/gracedr.ado"
quietly rmdir "`scratch'/phantom_ado"

local four_call `"gracedr setup, study("`scratch'/four") n(60) arms(A B) `balance'"'
foreach bad_seed in -1 2147483648 1.5 abc {
    expect_failure, ///
        rc(198) ///
        message("gracedr: seed() must be a whole number from 0 to 2147483647") ///
        command(`"`four_call' seed(`bad_seed')"')
    _gracedr_study folder, study("`scratch'/four")
    assert r(found) == 0
}
foreach good_seed in 0 2147483647 {
    gracedr setup, ///
        study("`scratch'/seed`good_seed'") ///
        n(60) ///
        arms(A B) ///
        `balance' ///
        seed(`good_seed')
    assert r(seed) == `good_seed'
    preserve
    _gracedr_study read, study("`scratch'/seed`good_seed'") name(state)
    assert seed[1] == `good_seed'
    restore
}
gracedr setup, study("`scratch'/clock1") n(60) arms(A B) `balance'
local first_seed = r(seed)
sleep 30
gracedr setup, study("`scratch'/clock2") n(60) arms(A B) `balance'
local second_seed = r(seed)
local same_seed = `first_seed' == `second_seed'
assert `same_seed' == 0

local backslash_study = subinstr("`scratch'/norm", "/", char(92), .)
gracedr setup, study("`backslash_study'`=char(92)'") n(60) arms(A B) `balance' seed(9)
assert `"`r(study)'"' == "`scratch'/norm"

foreach reserved in id arm code seq {
    expect_failure, ///
        rc(198) ///
        message("gracedr: balance variable name `reserved' is reserved") ///
        command(`"gracedr setup, study("`scratch'/four") n(60) arms(A B) continuous(`reserved')"')
}

gracedr setup, ///
    study("`scratch'/order") ///
    n(60) ///
    arms(A B) ///
    continuous(age) ///
    categorical(sex: male female) ///
    weights(1 3) ///
    seed(2)
get_setting "`scratch'/order" "varnames"
assert "`r(value)'" == "sex age"
get_setting "`scratch'/order" "weights"
assert inrange(real(word("`r(value)'", 1)), 0.25 - `epsilon', 0.25 + `epsilon')
assert inrange(real(word("`r(value)'", 2)), 0.75 - `epsilon', 0.75 + `epsilon')


quietly mkdir "`scratch'/partial"
quietly copy "`one'/state.dta" "`scratch'/partial/state.dta"
make_data 3
set seed 31
local partial_state = c(rngstate)
expect_failure, ///
    rc(602) ///
    message("gracedr: setup stopped before it finished.") ///
    command(`"gracedr setup, study("`scratch'/partial") n(60) arms(A B) `balance' seed(4)"')
assert _N == 3
assert x[3] == 30
assert c(rngstate) == "`partial_state'"
foreach name in design codes participants state {
    assert fileexists("`scratch'/partial/`name'.dta")
}
assert !fileexists("`scratch'/partial/audit.dta")
expect_failure, ///
    rc(198) ///
    message("gracedr: n() must be a whole number from 2 to 2000000000") ///
    command(`"gracedr setup, study("`scratch'/four") n(1) arms(A B) `balance'"')
assert _N == 3
assert c(rngstate) == "`partial_state'"
write_text_file "`scratch'/blankarm.csv" "code,arm" "1,A" "2,"
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown arm(s) in the codes file: (blank)") ///
    command(`"`four_call' codes("`scratch'/blankarm.csv")"')
assert _N == 3
assert c(rngstate) == "`partial_state'"


remove_folder "`scratch'"

display "certify_setup: all checks passed"
