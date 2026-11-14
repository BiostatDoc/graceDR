version 19
clear all
set linesize 255
set graphics off
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define write_codes_for
    args file per_arm
    tempname handle
    file open `handle' using "`file'", write text replace
    file write `handle' "code,arm" _n
    forvalues position = 1/`per_arm' {
        local number = 100 + `position'
        file write `handle' "A`number',A" _n
        file write `handle' "B`number',B" _n
    }
    file close `handle'
end

program define read_dataset
    args study name
    _gracedr_study read, study(`"`study'"') name(`name')
end

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert randomize"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
write_codes_for "`scratch'/codes.csv" 20
local design "categorical(sex: male female) continuous(age)"

gracedr setup, ///
    study("`scratch'/forty") ///
    n(40) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(20261114)
local forty "`scratch'/forty"

set seed 424242
local user_state = c(rngstate)
make_data 3
generate marker = _n

expect_failure, ///
    rc(0) ///
    message("Participant P1 randomized to arm") ///
    command(`"gracedr randomize, study("`forty'") id(P1) sex(male) age(30)"')
assert c(rngstate) == "`user_state'"
assert _N == 3
assert marker[3] == 3
gracedr randomize, study("`forty'") id(P2) sex(female) age(41)
assert "`r(id)'" == "P2"
assert inlist("`r(arm)'", "A", "B")
assert inlist("`r(phase)'", "runin")
assert r(n_randomized) == 2
assert wordcount("`r(probs)'") == 2
assert regexm("`r(code)'", "^[AB]1[0-9][0-9]$")
assert substr("`r(code)'", 1, 1) == "`r(arm)'"
assert "`r(missingvars)'" == ""

local cycle_sex "male female male male female female male female"
local cycle_age "30 41 52 63 34 45 56 67 38 49 50 61"
forvalues position = 3/40 {
    local sex_slot = mod(`position' - 1, 8) + 1
    local age_slot = mod(`position' - 1, 12) + 1
    local sex : word `sex_slot' of `cycle_sex'
    local age : word `age_slot' of `cycle_age'
    quietly gracedr randomize, study("`forty'") id(P`position') sex(`sex') age(`age')
}

read_dataset "`forty'" participants
assert _N == 40
assert seq == _n
assert id == "P" + string(_n)
assert inlist(arm, "A", "B")
local observed_arms ""
forvalues position = 1/40 {
    local one_arm = arm[`position']
    local observed_arms "`observed_arms'`one_arm'"
}
local reference_arms "ABABABABBAABBBBBBABAAAAAAABABABABBBBAABA"
assert "`observed_arms'" == "`reference_arms'"
quietly count if arm == "A"
assert r(N) == 20
quietly count if arm == "B"
assert r(N) == 20
assert !missing(time)
assert inrange(time[40], time[1], 1e18)
assert inrange(abs(prob1 + prob2 - 1), 0, 0.000000001)
assert inlist(phase, "runin", "quota", "bound", "msb-biased", "msb-random")
assert phase[1] == "runin"
assert inrange(strlen(rngstate), 1001, 1e9)
quietly levelsof code, local(used_codes)
assert wordcount(`"`used_codes'"') == 40
assert substr(code, 1, 1) == arm
local first_age = age[1]
assert `first_age' == 30
assert sex[2] == "female"
tempfile saved_participants
quietly save `"`saved_participants'"'

read_dataset "`forty'" codes
assert _N == 40
quietly count if status == "used"
assert r(N) == 40
assert !missing(id)
quietly count if status == "unused"
assert r(N) == 0

read_dataset "`forty'" audit
assert _N == 41
assert action[1] == "create"
assert action[2] == "randomize" & id[2] == "P1"
local first_arm = substr("`observed_arms'", 1, 1)
assert old[2] == "" & new[2] == "`first_arm'"
assert old == "" if action == "randomize"
assert !missing(new_code) if action == "randomize"
assert id[41] == "P40"
assert inrange(time[41], time[2], 1e18)

use `"`saved_participants'"', clear
local used_before ""
forvalues position = 1/40 {
    local before = rngstate[`position']
    local first_prob = string(prob1[`position'], "%21.17g")
    local second_prob = string(prob2[`position'], "%21.17g")
    local probs "`first_prob' `second_prob'"
    local count_a = 20
    local count_b = 20
    local prior = `position' - 1
    if inrange(`prior', 1, 40) {
        quietly count if arm == "A" in 1/`prior'
        local count_a = 20 - r(N)
        quietly count if arm == "B" in 1/`prior'
        local count_b = 20 - r(N)
    }
    _gracedr_rng replay, ///
        state(`before') ///
        probs(`probs') ///
        arms(A B) ///
        codecounts(`count_a' `count_b')
    assert "`r(arm)'" == arm[`position']
    local wanted_index = r(code_index)
    local seen = 0
    local expected_code ""
    forvalues number = 1/20 {
        local candidate = arm[`position'] + string(100 + `number')
        local taken : list candidate in used_before
        if `taken' == 0 {
            local seen = `seen' + 1
            if `seen' == `wanted_index' {
                local expected_code "`candidate'"
            }
        }
    }
    assert code[`position'] == "`expected_code'"
    local this_code = code[`position']
    local used_before "`used_before' `this_code'"
}

read_dataset "`forty'" state
local final_state = state[1]
use `"`saved_participants'"', clear
local last_before = rngstate[40]
local unchanged = "`final_state'" == "`last_before'"
assert `unchanged' == 0

expect_failure, ///
    rc(198) ///
    message("gracedr: the study already has 40 participants") ///
    command(`"gracedr randomize, study("`forty'") id(P41) sex(male) age(30)"')
read_dataset "`forty'" participants
assert _N == 40

gracedr setup, ///
    study("`scratch'/small") ///
    n(20) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(5)
local small "`scratch'/small"
quietly gracedr randomize, study("`small'") id(P1) sex(male) age(30)
read_dataset "`small'" participants
tempfile one_row
quietly save `"`one_row'"'
read_dataset "`small'" codes
tempfile codes_after_one
quietly save `"`codes_after_one'"'
read_dataset "`small'" audit
tempfile audit_after_one
quietly save `"`audit_after_one'"'
read_dataset "`small'" state
local state_after_one = state[1]
clear

expect_failure, ///
    rc(198) ///
    message("gracedr: participant P1 has already been randomized") ///
    command(`"gracedr randomize, study("`small'") id(P1) sex(male) age(30)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: (study) is reserved") ///
    command(`"gracedr randomize, study("`small'") id("(study)") sex(male) age(30)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: id() must not be empty") ///
    command(`"gracedr randomize, study("`small'") id(" ") sex(male) age(30)"')
expect_failure, ///
    rc(198) ///
    message("gracedr") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(male) height(30)"')
expect_failure, ///
    rc(198) ///
    message("gracedr") ///
    command(`"gracedr randomize, study("`small'") id(P2) Sex(male) age(30)"')
assert c(rngstate) == "`user_state'"
expect_failure, ///
    rc(198) ///
    message("gracedr") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(male)"')
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"gracedr randomize, study("`scratch'/nothing") id(P2) sex(male) age(30)"')

program define expect_unchanged
    args study rows state
    read_dataset "`study'" participants
    assert _N == `rows'
    read_dataset "`study'" state
    assert state[1] == "`state'"
    clear
end

expect_unchanged "`small'" 1 "`state_after_one'"
read_dataset "`small'" codes
quietly cf _all using `"`codes_after_one'"'
read_dataset "`small'" audit
quietly cf _all using `"`audit_after_one'"'
clear

quietly mkdir "`small'/participants.tmp"
expect_failure, ///
    rc(603) ///
    message("gracedr: could not write participants.dta") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(female) age(35)"')
remove_folder "`small'/participants.tmp"
expect_unchanged "`small'" 1 "`state_after_one'"
read_dataset "`small'" codes
quietly cf _all using `"`codes_after_one'"'
read_dataset "`small'" audit
quietly cf _all using `"`audit_after_one'"'
clear

program define reset_study
    args study one_row codes_one audit_one
    quietly use `"`one_row'"', clear
    _gracedr_study write, study("`study'") name(participants)
    quietly use `"`codes_one'"', clear
    _gracedr_study write, study("`study'") name(codes)
    quietly use `"`audit_one'"', clear
    _gracedr_study write, study("`study'") name(audit)
    clear
end

quietly mkdir "`small'/codes.tmp"
expect_failure, ///
    rc(603) ///
    message("files already written: participants.dta;") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(female) age(35)"')
remove_folder "`small'/codes.tmp"
expect_unchanged "`small'" 2 "`state_after_one'"
reset_study "`small'" "`one_row'" "`codes_after_one'" "`audit_after_one'"

quietly mkdir "`small'/audit.tmp"
expect_failure, ///
    message("files already written: participants.dta codes.dta") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(female) age(35)"')
remove_folder "`small'/audit.tmp"
expect_unchanged "`small'" 2 "`state_after_one'"
read_dataset "`small'" audit
quietly cf _all using `"`audit_after_one'"'
read_dataset "`small'" codes
quietly count if status == "used"
assert r(N) == 2
clear
reset_study "`small'" "`one_row'" "`codes_after_one'" "`audit_after_one'"

quietly mkdir "`small'/state.tmp"
expect_failure, ///
    message("files already written: participants.dta codes.dta audit.dta") ///
    command(`"gracedr randomize, study("`small'") id(P3) sex(female) age(35)"')
remove_folder "`small'/state.tmp"
expect_unchanged "`small'" 2 "`state_after_one'"
assert c(rngstate) == "`user_state'"
reset_study "`small'" "`one_row'" "`codes_after_one'" "`audit_after_one'"

gracedr setup, ///
    study("`scratch'/few_codes") ///
    n(4) ///
    arms(A B) ///
    categorical(sex: male female) ///
    runin(0) ///
    seed(7)
local few_codes "`scratch'/few_codes"
read_dataset "`few_codes'" codes
quietly set obs 4
quietly replace code = "A1" in 1
quietly replace code = "A2" in 2
quietly replace code = "A3" in 3
quietly replace code = "A4" in 4
quietly replace arm = "A"
quietly replace status = "unused"
_gracedr_study write, study("`few_codes'") name(codes)
local failed_at = 0
forvalues position = 1/4 {
    if `failed_at' == 0 {
        capture quietly gracedr randomize, study("`few_codes'") id(P`position') sex(male)
        if _rc == 198 {
            local failed_at = `position'
        }
    }
}
assert inrange(`failed_at', 1, 4)
local rows_before = `failed_at' - 1
read_dataset "`few_codes'" state
local state_before_failure = state[1]
expect_failure, ///
    rc(198) ///
    message("gracedr: no unused codes are left for arm B") ///
    command(`"gracedr randomize, study("`few_codes'") id(P`failed_at') sex(male)"')
expect_unchanged "`few_codes'" `rows_before' "`state_before_failure'"
read_dataset "`few_codes'" audit
assert _N == `failed_at'

gracedr setup, ///
    study("`scratch'/no_codes") ///
    n(10) ///
    arms(A B) ///
    `design' ///
    runin(0) ///
    seed(9)
local no_codes "`scratch'/no_codes"
expect_failure, ///
    rc(0) ///
    message("missing value for sex age") ///
    command(`"gracedr randomize, study("`no_codes'") id(P1) sex(.) age(.)"')
gracedr randomize, study("`no_codes'") id(P2) sex(.) age(.)
assert "`r(missingvars)'" == "sex age"
assert "`r(code)'" == ""
read_dataset "`no_codes'" participants
local drawn_arm = arm[1]
assert _N == 2
assert sex[1] == "" & missing(age[1]) & code[1] == ""
read_dataset "`no_codes'" codes
assert _N == 0
read_dataset "`no_codes'" audit
assert _N == 3
assert new[2] == "`drawn_arm'"
assert new_code[2] == ""

gracedr setup, ///
    study("`scratch'/quirky") ///
    n(10) ///
    arms("Arm one" "Arm two") ///
    categorical(sex: male female) ///
    runin(0) ///
    seed(11)
local quirky "`scratch'/quirky"
local odd_id = "A" + char(36) + "B C"
gracedr randomize, study("`quirky'") id(`macval(odd_id)') sex(male)
assert !missing("`r(arm)'")
assert inlist(`"`r(arm)'"', "Arm one", "Arm two")
read_dataset "`quirky'" participants
assert id[1] == "A" + char(36) + "B C"
assert inlist(arm[1], "Arm one", "Arm two")
clear

gracedr setup, ///
    study("`scratch'/graphs") ///
    n(10) ///
    arms(A B) ///
    `design' ///
    runin(0) ///
    seed(13)
local graphs "`scratch'/graphs"
graph drop _all
quietly gracedr randomize, study("`graphs'") id(P1) sex(male) age(30)
quietly graph dir, memory
assert wordcount("`r(list)'") == 0
quietly gracedr randomize, ///
    study("`graphs'") ///
    id(P2) ///
    sex(female) ///
    age(40) ///
    graphs
quietly graph dir, memory
assert wordcount("`r(list)'") == 2
local graph_list "`r(list)'"
local has_imbalance : list posof "gracedr_imbalance" in graph_list
local has_smd : list posof "gracedr_smd" in graph_list
assert inrange(`has_imbalance', 1, 2)
assert inrange(`has_smd', 1, 2)

remove_folder "`scratch'"
display "certify_randomize: all checks passed"
