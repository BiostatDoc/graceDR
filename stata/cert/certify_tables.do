version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

local tolerance = 1 / 1000000000

_gracedr_smd binary, p1(0.6) p2(0.4)
close_to `r(smd)' 0.408248290463863 `tolerance'
_gracedr_smd binary, p1(0.4) p2(0.6)
close_to `r(smd)' -0.408248290463863 `tolerance'
_gracedr_smd binary, p1(0.5) p2(0.5)
assert r(smd) == 0
_gracedr_smd binary, p1(1) p2(1)
assert r(smd) == 0
_gracedr_smd binary, p1(1) p2(0)
assert r(smd) == 0
_gracedr_smd continuous, m1(10) m2(12) s1(2) s2(2)
close_to `r(smd)' -1 `tolerance'
_gracedr_smd continuous, m1(5) m2(3) s1(3) s2(1)
close_to `r(smd)' 0.894427190999916 `tolerance'
_gracedr_smd continuous, m1(5) m2(7) s1(0) s2(0)
assert r(smd) == 0
_gracedr_smd continuous, m1(5) m2(7) s1(.) s2(.)
assert r(smd) == 0
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown smd subcommand nothing") ///
    command("_gracedr_smd nothing")

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert tables"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

local shared_design "categorical(sex: male female | group: x y z) continuous(age)"
gracedr setup, ///
    study("`scratch'/two_arms") ///
    n(20) ///
    arms(A B) ///
    `shared_design' ///
    runin(0) ///
    seed(1)
local two_arms "`scratch'/two_arms"
start_participants, study("`two_arms'") arms("A A A A B B B B")
set_column, name(sex) values("male male male female male female female female")
set_column, name(group) values("x x y z x y y y")
set_column, name(age) values("30 40 50 60 20 30 40 50")
finish_participants, study("`two_arms'")

_gracedr_tables balance, study("`two_arms'") saving("`scratch'/two_arms_balance.dta")
matrix smd_values = r(smd)
assert rowsof(smd_values) == 3
assert colsof(smd_values) == 1
local actual = smd_values[1, 1]
close_to `actual' 1.15470053837925 `tolerance'
local actual = smd_values[2, 1]
close_to `actual' 1.15470053837925 `tolerance'
local actual = smd_values[3, 1]
close_to `actual' 0.774596669241483 `tolerance'
assert "`r(varnames)'" == "sex group age"
preserve
quietly use "`scratch'/two_arms_balance.dta", clear
assert _N == 6
assert variable[1] == "sex" & level[1] == "male"
assert arm1[1] == "3 (75.0%)" & arm2[1] == "1 (25.0%)"
assert arm1[2] == "1 (25.0%)" & arm2[2] == "3 (75.0%)"
assert level[3] == "x" & arm1[3] == "2 (50.0%)" & arm2[3] == "1 (25.0%)"
assert arm1[4] == "1 (25.0%)" & arm2[4] == "3 (75.0%)"
assert arm1[5] == "1 (25.0%)" & arm2[5] == "0 (0.0%)"
assert variable[6] == "age" & level[6] == ""
assert arm1[6] == "45.0 (12.9)" & arm2[6] == "35.0 (12.9)"
assert nmissing[1] == 0 & nmissing[6] == 0
local actual = smd[4]
close_to `actual' 1.15470053837925 `tolerance'
local actual = smd[3]
close_to `actual' 1.15470053837925 `tolerance'
local actual = smd[6]
close_to `actual' 0.774596669241483 `tolerance'
restore

gracedr setup, ///
    study("`scratch'/three_arms") ///
    n(30) ///
    arms(A B C) ///
    continuous(age) ///
    runin(0) ///
    seed(2)
local three_arms "`scratch'/three_arms"
start_participants, study("`three_arms'") arms("A A B B C C")
set_column, name(age) values("10 20 20 30 40 60")
finish_participants, study("`three_arms'")
_gracedr_tables balance, study("`three_arms'")
local actual = r(smd)[1, 1]
close_to `actual' 3.13049516849971 `tolerance'

start_participants, study("`three_arms'") arms("A A B B C C")
set_column, name(age) values("5 5 7 7 1 1")
finish_participants, study("`three_arms'")
_gracedr_tables balance, study("`three_arms'")
local actual = r(smd)[1, 1]
close_to `actual' 0 `tolerance'

start_participants, study("`three_arms'") arms("A B C")
set_column, name(age) values("5 7 9")
finish_participants, study("`three_arms'")
_gracedr_tables balance, study("`three_arms'")
assert r(smd)[1, 1] == 0

start_participants, study("`three_arms'") arms("A A B B")
set_column, name(age) values("5 6 7 8")
finish_participants, study("`three_arms'")
_gracedr_tables balance, study("`three_arms'") saving("`scratch'/empty_arm.dta")
assert missing(r(smd)[1, 1])
preserve
quietly use "`scratch'/empty_arm.dta", clear
assert arm3[1] == "-"
restore

start_participants, study("`two_arms'") arms("A A A B B B")
set_column, name(sex) values("male . female male male female")
set_column, name(group) values("x y . . z x")
set_column, name(age) values("30 . 50 20 30 .")
finish_participants, study("`two_arms'")
_gracedr_tables balance, study("`two_arms'") saving("`scratch'/missing_rows.dta")
preserve
quietly use "`scratch'/missing_rows.dta", clear
assert arm1[1] == "1 (50.0%)" & arm2[1] == "2 (66.7%)"
assert nmissing[1] == 1 & nmissing[3] == 2 & nmissing[6] == 2
assert arm1[6] == "40.0 (14.1)" & arm2[6] == "25.0 (7.1)"
restore

start_participants, study("`two_arms'") arms("A A")
set_column, name(sex) values("male female")
set_column, name(group) values("x y")
set_column, name(age) values("30 40")
finish_participants, study("`two_arms'")
_gracedr_tables balance, study("`two_arms'") saving("`scratch'/one_arm.dta")
assert missing(r(smd)[1, 1])
preserve
quietly use "`scratch'/one_arm.dta", clear
assert arm2[1] == "0 (0.0%)" & arm2[6] == "-"
restore

_gracedr_study empty, name(participants) study("`two_arms'")
_gracedr_study write, study("`two_arms'") name(participants)
_gracedr_tables balance, study("`two_arms'") saving("`scratch'/none.dta")
assert missing(r(smd)[1, 1])
preserve
quietly use "`scratch'/none.dta", clear
assert arm1[1] == "0 (0.0%)" & arm1[6] == "-"
restore

make_data 3
generate marker = _n
_gracedr_tables balance, study("`two_arms'")
assert _N == 3
assert marker[3] == 3

gracedr setup, ///
    study("`scratch'/targets") ///
    n(31) ///
    arms(A B) ///
    ratio(2 1) ///
    categorical(sex: male female) ///
    runin(0) ///
    forcedat(10) ///
    seed(3)
local targets "`scratch'/targets"
start_participants, study("`targets'") arms("A A A A A B B")
finish_participants, study("`targets'")
_gracedr_tables groupsize, study("`targets'")
matrix sizes = r(groupsize)
assert rowsof(sizes) == 2
assert colsof(sizes) == 4
assert sizes[1, 1] == 5 & sizes[2, 1] == 2
local actual = sizes[1, 2]
close_to `actual' 71.4 `tolerance'
local actual = sizes[2, 2]
close_to `actual' 28.6 `tolerance'
assert sizes[1, 3] == 7 & sizes[2, 3] == 3
assert sizes[1, 4] == 21 & sizes[2, 4] == 10
assert r(total) == 7

start_participants, study("`targets'") arms("A A A A A A A B B B")
finish_participants, study("`targets'")
_gracedr_tables groupsize, study("`targets'")
assert r(groupsize)[1, 3] == 21 & r(groupsize)[2, 3] == 10

_gracedr_study empty, name(participants) study("`targets'")
_gracedr_study write, study("`targets'") name(participants)
_gracedr_tables groupsize, study("`targets'")
assert r(groupsize)[1, 1] == 0 & r(groupsize)[1, 2] == 0
assert r(groupsize)[1, 3] == 7 & r(groupsize)[2, 3] == 3
assert r(total) == 0

local full_arms ""
forvalues position = 1/31 {
    local full_arms "`full_arms' A"
}
start_participants, study("`targets'") arms("`full_arms'")
finish_participants, study("`targets'")
_gracedr_tables groupsize, study("`targets'")
assert r(groupsize)[1, 3] == 21 & r(groupsize)[2, 3] == 10
assert r(groupsize)[2, 1] == 0

gracedr setup, ///
    study("`scratch'/spaced") ///
    n(20) ///
    arms("Arm one" "Arm two") ///
    continuous(age) ///
    runin(0) ///
    seed(4)
local spaced "`scratch'/spaced"
start_participants, study("`spaced'") arms("Arm_one Arm_two Arm_one Arm_two")
set_column, name(age) values("10 20 30 40")
finish_participants, study("`spaced'")
_gracedr_tables groupsize, study("`spaced'")
assert r(groupsize)[1, 1] == 2
_gracedr_tables balance, study("`spaced'") saving("`scratch'/spaced.dta")
local actual = r(smd)[1, 1]
close_to `actual' 0.707106781186548 `tolerance'

matrix sizes = (7, 7)
matrix smd_values = (8)
_gracedr_tables groupsize, study("`targets'")
_gracedr_tables balance, study("`targets'")
assert sizes[1, 2] == 7
assert smd_values[1, 1] == 8
matrix drop sizes smd_values

gracedr setup, ///
    study("`scratch'/middle") ///
    n(31) ///
    arms(A B) ///
    ratio(2 1) ///
    categorical(sex: male female) ///
    runin(10) ///
    forcedat(20) ///
    seed(5)
local middle "`scratch'/middle"
start_participants, study("`middle'") arms("A A A A A A A A B B B B")
finish_participants, study("`middle'")
_gracedr_tables groupsize, study("`middle'")
assert r(groupsize)[1, 3] == 13 & r(groupsize)[2, 3] == 7
assert r(groupsize)[1, 4] == 21 & r(groupsize)[2, 4] == 10

gracedr setup, ///
    study("`scratch'/no_forced") ///
    n(20) ///
    arms(A B) ///
    categorical(sex: male female) ///
    seed(6)
local no_forced "`scratch'/no_forced"
start_participants, study("`no_forced'") arms("A B A B A B")
finish_participants, study("`no_forced'")
_gracedr_tables groupsize, study("`no_forced'")
assert r(groupsize)[1, 3] == 5 & r(groupsize)[2, 3] == 5
assert r(groupsize)[1, 4] == 10 & r(groupsize)[2, 4] == 10

expect_failure, ///
    rc(603) ///
    message("gracedr: could not save the table") ///
    command(`"_gracedr_tables balance, study("`targets'") saving("`scratch'/no_dir/x.dta")"')

expect_failure, ///
    rc(198) ///
    message("gracedr: unknown tables subcommand nothing") ///
    command("_gracedr_tables nothing, study(`targets')")
expect_failure, ///
    message("gracedr") ///
    command("_gracedr_tables groupsize, study(`scratch'/missing_study)")

remove_folder "`scratch'"
display "certify_tables: all checks passed"
