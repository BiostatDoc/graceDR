version 19
clear all
set linesize 255
set graphics off
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define run_participants
    args study first last
    local cycle_sex "male female male male female female male female"
    local cycle_age "30 41 52 63 34 45 56 67 38 49 50 61"
    forvalues position = `first'/`last' {
        local sex_slot = mod(`position' - 1, 8) + 1
        local age_slot = mod(`position' - 1, 12) + 1
        local sex : word `sex_slot' of `cycle_sex'
        local age : word `age_slot' of `cycle_age'
        quietly gracedr randomize, study("`study'") id(P`position') sex(`sex') age(`age')
    }
end

program define expect_replays
    args study first last
    forvalues position = `first'/`last' {
        quietly gracedr replay, study("`study'") id(P`position')
        assert r(match) == 1
        assert "`r(arm)'" == "`r(arm_replayed)'"
        assert "`r(code)'" == "`r(code_replayed)'"
    }
end

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert ops"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
write_codes_for "`scratch'/codes.csv" 30
local design "categorical(sex: male female) continuous(age)"

gracedr setup, ///
    study("`scratch'/forty") ///
    n(40) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(20261114)
local forty "`scratch'/forty"
run_participants "`forty'" 1 40
read_dataset "`forty'" participants
local reference_arms "ABABABABBAABBBBBBABAAAAAAABABABABBBBAABA"
local observed_arms ""
forvalues position = 1/40 {
    local one_arm = arm[`position']
    local observed_arms "`observed_arms'`one_arm'"
}
assert "`observed_arms'" == "`reference_arms'"
clear

set seed 424242
local user_state = c(rngstate)
make_data 3
generate marker = _n

expect_failure, ///
    rc(0) ///
    message("40 participants randomized") ///
    command(`"gracedr status, study("`forty'")"')
gracedr status, study("`forty'")
assert r(n_randomized) == 40
assert r(groupsize)[1, 1] == 20 & r(groupsize)[2, 1] == 20
assert r(groupsize)[1, 3] == 20 & r(groupsize)[1, 4] == 20
assert "`r(varnames)'" == "sex age"
assert rowsof(r(smd)) == 2
assert c(rngstate) == "`user_state'"
assert _N == 3
assert marker[3] == 3

gracedr status, study("`forty'") from(11) to(20)
assert r(n_randomized) == 10
assert r(groupsize)[1, 1] == 3 & r(groupsize)[2, 1] == 7
local percent = r(groupsize)[1, 2]
assert inrange(abs(`percent' - 30), 0, 0.000001)
gracedr status, study("`forty'") from(31)
assert r(n_randomized) == 10
assert r(groupsize)[1, 1] == 4 & r(groupsize)[2, 1] == 6
gracedr status, study("`forty'") to(10)
assert r(n_randomized) == 10
assert r(groupsize)[1, 1] == 5
gracedr status, study("`forty'") checkpoint("run-in")
assert r(n_randomized) == 10
assert r(groupsize)[1, 1] == 5 & r(groupsize)[2, 1] == 5
assert r(groupsize)[1, 3] == 20
gracedr status, study("`forty'") checkpoint(10)
assert r(n_randomized) == 10
gracedr status, study("`forty'") checkpoint(final)
assert r(n_randomized) == 40
gracedr status, study("`forty'") from(50)
assert r(n_randomized) == 0
gracedr status, study("`forty'") vars(age)
assert "`r(varnames)'" == "age"
assert rowsof(r(smd)) == 1
gracedr status, study("`forty'") vars(age sex)
assert "`r(varnames)'" == "sex age"
gracedr status, study("`forty'") from(11) to(20) vars(sex)
assert r(n_randomized) == 10
assert "`r(varnames)'" == "sex"

expect_failure, ///
    rc(198) ///
    message("gracedr: checkpoint() cannot be combined with from() or to()") ///
    command(`"gracedr status, study("`forty'") checkpoint(10) from(2)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: checkpoint() cannot be combined with from() or to()") ///
    command(`"gracedr status, study("`forty'") checkpoint(10) to(20)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: from() (30) must not be greater than to() (20)") ///
    command(`"gracedr status, study("`forty'") from(30) to(20)"')
foreach bad in 1.5 abc -1 0 {
    expect_failure, ///
        rc(198) ///
        message("gracedr: from() must be a whole number of at least 1") ///
        command(`"gracedr status, study("`forty'") from(`bad')"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: to() must be a whole number of at least 1") ///
    command(`"gracedr status, study("`forty'") to(2.5)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown checkpoint 25") ///
    command(`"gracedr status, study("`forty'") checkpoint(25)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown checkpoint forced") ///
    command(`"gracedr status, study("`forty'") checkpoint(forced)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown balance variable height") ///
    command(`"gracedr status, study("`forty'") vars(sex height)"')
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"gracedr status, study("`scratch'/nothing")"')

gracedr setup, ///
    study("`scratch'/twelve") ///
    n(40) ///
    arms(A B) ///
    `design' ///
    runin(10) ///
    seed(3)
local twelve "`scratch'/twelve"
run_participants "`twelve'" 1 12
expect_failure, ///
    rc(198) ///
    message("gracedr: checkpoint 40 has not been reached: 12 participants randomized") ///
    command(`"gracedr status, study("`twelve'") checkpoint(final)"')
gracedr status, study("`twelve'") checkpoint(10)
assert r(n_randomized) == 10
gracedr status, study("`twelve'") checkpoint("run-in")
assert r(n_randomized) == 10

graph drop _all
quietly gracedr status, study("`forty'")
quietly graph dir, memory
assert wordcount("`r(list)'") == 0
quietly gracedr status, study("`forty'") graphs saving("`scratch'/status")
quietly graph dir, memory
local graph_list "`r(list)'"
local has_imbalance : list posof "gracedr_imbalance" in graph_list
local has_smd : list posof "gracedr_smd" in graph_list
assert inrange(`has_imbalance', 1, 2)
assert inrange(`has_smd', 1, 2)
confirm file "`scratch'/status_imbalance.gph"
confirm file "`scratch'/status_smd.gph"
assert c(rngstate) == "`user_state'"

expect_failure, ///
    rc(0) ///
    message("create") ///
    command(`"gracedr audit, study("`forty'")"')
gracedr audit, study("`forty'")
assert r(rows) == 41
assert _N == 3
read_dataset "`forty'" audit
assert action[1] == "create" & id[1] == "(study)"
clear

expect_failure, ///
    rc(198) ///
    message("gracedr: participant P99 has not been randomized") ///
    command(`"gracedr override, study("`forty'") id(P99) arm(B) reason(typo)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: (study) is reserved") ///
    command(`"gracedr override, study("`forty'") id("(study)") arm(B) reason(typo)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: participant P1 is already in arm A") ///
    command(`"gracedr override, study("`forty'") id(P1) arm(A) reason(typo)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown arm C") ///
    command(`"gracedr override, study("`forty'") id(P1) arm(C) reason(typo)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: reason() must not be empty") ///
    command(`"gracedr override, study("`forty'") id(P1) arm(B) reason(" ")"')
expect_failure, ///
    message("option reason() required") ///
    command(`"gracedr override, study("`forty'") id(P1) arm(B)"')
assert c(rngstate) == "`user_state'"

read_dataset "`forty'" participants
tempfile before_participants
quietly save `"`before_participants'"'
read_dataset "`forty'" codes
tempfile before_codes
quietly save `"`before_codes'"'
read_dataset "`forty'" audit
tempfile before_audit
quietly save `"`before_audit'"'
read_dataset "`forty'" state
local state_before = state[1]
clear
quietly use `"`before_participants'"', clear
local old_code = code[1]
assert arm[1] == "A"

gracedr override, study("`forty'") id(P1) arm(B) reason("entered in error")
assert "`r(id)'" == "P1"
assert "`r(old_arm)'" == "A"
assert "`r(arm)'" == "B"
assert "`r(old_code)'" == "`old_code'"
assert substr("`r(code)'", 1, 1) == "B"
local new_code "`r(code)'"
assert c(rngstate) == "`user_state'"
read_dataset "`forty'" participants
assert arm[1] == "B" & code[1] == "`new_code'"
assert arm[2] == "B"
quietly count if arm == "A"
assert r(N) == 19
read_dataset "`forty'" codes
quietly count if code == "`old_code'" & status == "voided" & id == "P1"
assert r(N) == 1
quietly count if code == "`new_code'" & status == "used" & id == "P1"
assert r(N) == 1
quietly count if status == "voided"
assert r(N) == 1
quietly count if status == "used"
assert r(N) == 40
read_dataset "`forty'" audit
assert _N == 42
assert action[42] == "override" & id[42] == "P1"
assert old[42] == "A" & new[42] == "B"
assert old_code[42] == "`old_code'" & new_code[42] == "`new_code'"
assert reason[42] == "entered in error"
read_dataset "`forty'" state
local state_after = state[1]
local moved = "`state_after'" == "`state_before'"
assert `moved' == 0
clear

gracedr status, study("`forty'")
assert r(groupsize)[1, 1] == 19 & r(groupsize)[2, 1] == 21
expect_failure, ///
    rc(198) ///
    message("gracedr: participant P1 is already in arm B") ///
    command(`"gracedr override, study("`forty'") id(P1) arm(B) reason(again)"')

gracedr override, study("`forty'") id(P30) arm(B) reason("second change")
gracedr override, study("`forty'") id(P1) arm(A) reason("changed back")
read_dataset "`forty'" codes
quietly count if status == "voided"
assert r(N) == 3
read_dataset "`forty'" audit
assert _N == 44
clear
expect_replays "`forty'" 1 40
gracedr replay, study("`forty'") id(P1)
assert "`r(arm)'" == "A"
assert r(match) == 1

expect_failure, ///
    rc(198) ///
    message("gracedr: participant P99 has not been randomized") ///
    command(`"gracedr replay, study("`forty'") id(P99)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: (study) is reserved") ///
    command(`"gracedr replay, study("`forty'") id("(study)")"')

read_dataset "`forty'" participants
local tampered_arm = cond(arm[3] == "A", "B", "A")
quietly replace arm = "`tampered_arm'" in 3
_gracedr_study write, study("`forty'") name(participants)
clear
expect_failure, ///
    rc(0) ///
    message("does not match") ///
    command(`"gracedr replay, study("`forty'") id(P3)"')
gracedr replay, study("`forty'") id(P3)
assert r(match) == 0
assert "`r(arm)'" == "`tampered_arm'"
local agrees = "`r(arm)'" == "`r(arm_replayed)'"
assert `agrees' == 0

gracedr setup, ///
    study("`scratch'/plain") ///
    n(20) ///
    arms(A B) ///
    `design' ///
    runin(0) ///
    seed(21)
local plain "`scratch'/plain"
run_participants "`plain'" 1 8
expect_replays "`plain'" 1 8
read_dataset "`plain'" participants
local plain_arm = arm[2]
local other_arm = cond("`plain_arm'" == "A", "B", "A")
read_dataset "`plain'" state
local plain_state = state[1]
clear
gracedr override, study("`plain'") id(P2) arm(`other_arm') reason("no codes")
assert "`r(code)'" == ""
read_dataset "`plain'" participants
assert arm[2] == "`other_arm'" & code[2] == ""
read_dataset "`plain'" state
assert state[1] == "`plain_state'"
read_dataset "`plain'" audit
assert action[_N] == "override" & old_code[_N] == "" & new_code[_N] == ""
clear
expect_replays "`plain'" 1 8

write_codes_for "`scratch'/two_per_arm.csv" 2
gracedr setup, ///
    study("`scratch'/few_two") ///
    n(8) ///
    arms(A B) ///
    categorical(sex: male female) ///
    runin(0) ///
    codes("`scratch'/two_per_arm.csv") ///
    seed(7)
local few_two "`scratch'/few_two"
quietly gracedr randomize, study("`few_two'") id(P1) sex(male)
read_dataset "`few_two'" participants
local first_arm = arm[1]
local other_arm = cond("`first_arm'" == "A", "B", "A")
read_dataset "`few_two'" codes
quietly replace status = "used" if arm == "`other_arm'"
_gracedr_study write, study("`few_two'") name(codes)
read_dataset "`few_two'" state
local few_state = state[1]
clear
expect_failure, ///
    rc(198) ///
    message("gracedr: no unused codes are left for arm `other_arm'") ///
    command(`"gracedr override, study("`few_two'") id(P1) arm(`other_arm') reason(none)"')
read_dataset "`few_two'" participants
assert arm[1] == "`first_arm'"
read_dataset "`few_two'" state
assert state[1] == "`few_state'"
read_dataset "`few_two'" audit
assert _N == 2
clear

gracedr status, study("`forty'") from(5) to(5)
assert r(n_randomized) == 1
gracedr status, study("`forty'") to(500)
assert r(n_randomized) == 40
gracedr status, study("`forty'") from(40) to(40)
assert r(n_randomized) == 1
expect_failure, ///
    rc(198) ///
    message("gracedr: from() (31) must not be greater than to() (30)") ///
    command(`"gracedr status, study("`forty'") from(31) to(30)"')
local run_in = "run" + char(45) + "in"
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown checkpoint `run_in'") ///
    command(`"gracedr status, study("`plain'") checkpoint(`run_in')"')
gracedr setup, ///
    study("`scratch'/empty") ///
    n(20) ///
    arms(A B) ///
    `design' ///
    seed(2)
gracedr status, study("`scratch'/empty")
assert r(n_randomized) == 0

foreach command in status audit {
    expect_failure, ///
        rc(601) ///
        message("gracedr: no study found in `scratch'/nothing") ///
        command(`"gracedr `command', study("`scratch'/nothing")"')
}
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"gracedr override, study("`scratch'/nothing") id(P1) arm(B) reason(x)"')
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/nothing") ///
    command(`"gracedr replay, study("`scratch'/nothing") id(P1)"')
expect_failure, ///
    message("option id() required") ///
    command(`"gracedr replay, study("`plain'")"')
expect_failure, ///
    message("option arm() required") ///
    command(`"gracedr override, study("`plain'") id(P1) reason(x)"')

expect_failure, ///
    rc(0) ///
    message("override") ///
    command(`"gracedr audit, study("`forty'")"')
gracedr replay, study("`forty'") id(P1)
assert "`r(code)'" == "`old_code'"
read_dataset "`forty'" participants
isid code
clear

make_data 3
generate marker = _n
set seed 424242
local user_state = c(rngstate)
read_dataset "`plain'" participants
tempfile plain_before
quietly save `"`plain_before'"'
quietly describe
local plain_columns = r(k)
make_data 3
generate marker = _n
local odd_reason = "it's a " + char(36) + "x ok"
gracedr replay, study("`plain'") id(P4)
assert c(rngstate) == "`user_state'"
assert _N == 3 & marker[3] == 3
read_dataset "`plain'" participants
local drawn_arm = arm[4]
local flip_arm = cond("`drawn_arm'" == "A", "B", "A")
make_data 3
generate marker = _n
gracedr override, study("`plain'") id(P4) arm(`flip_arm') reason(`macval(odd_reason)')
assert c(rngstate) == "`user_state'"
assert _N == 3 & marker[3] == 3
read_dataset "`plain'" audit
assert reason[_N] == "it's a " + char(36) + "x ok"
read_dataset "`plain'" participants
quietly describe
assert r(k) == `plain_columns'
quietly cf seq id sex age prob1 prob2 phase rngstate time using `"`plain_before'"'
assert arm[4] == "`flip_arm'"
clear
run_participants "`plain'" 9 12
expect_replays "`plain'" 1 12

gracedr setup, ///
    study("`scratch'/partial") ///
    n(8) ///
    arms(A B) ///
    categorical(sex: male female) ///
    runin(0) ///
    codes("`scratch'/two_per_arm.csv") ///
    seed(9)
local partial "`scratch'/partial"
quietly gracedr randomize, study("`partial'") id(P1) sex(male)
read_dataset "`partial'" participants
local first_arm = arm[1]
local other_arm = cond("`first_arm'" == "A", "B", "A")
read_dataset "`partial'" state
local partial_state = state[1]
clear
quietly mkdir "`partial'/codes.tmp"
expect_failure, ///
    rc(603) ///
    message("files already written: participants.dta;") ///
    command(`"gracedr override, study("`partial'") id(P1) arm(`other_arm') reason(none)"')
remove_folder "`partial'/codes.tmp"
read_dataset "`partial'" state
assert state[1] == "`partial_state'"
read_dataset "`partial'" audit
assert _N == 2
clear

remove_folder "`scratch'"
display "certify_ops: all checks passed"
