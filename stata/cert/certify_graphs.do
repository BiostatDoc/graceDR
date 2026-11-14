version 19
clear all
set linesize 255
set graphics off
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

local tolerance = 1 / 1000000000

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert graphs"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

gracedr setup, ///
    study("`scratch'/study") ///
    n(20) ///
    arms(A B) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(0) ///
    forcedat(10) ///
    seed(1)
local study "`scratch'/study"

_gracedr_graphs imbalance, study("`study'") saving("`scratch'/empty_imbalance")
confirm file "`scratch'/empty_imbalance.gph"
assert r(total) == 0
_gracedr_graphs smd, study("`study'") saving("`scratch'/empty_smd")
confirm file "`scratch'/empty_smd.gph"
assert r(plotted) == 0

local twelve_arms "A A B A B B A A A B B A"
local alternating "male female male female male female male female male female male female"
start_participants, study("`study'") arms("`twelve_arms'")
set_column, name(sex) values("`alternating'")
set_column, name(age) values("30 40 50 60 20 30 40 50 25 35 45 55")
finish_participants, study("`study'")

make_data 3
generate marker = _n
_gracedr_graphs imbalance, study("`study'") saving("`scratch'/imbalance")
confirm file "`scratch'/imbalance.gph"
assert r(total) == 12
assert "`r(reached)'" == "10"
local actual = r(deviation)[1, 1]
close_to `actual' 1 `tolerance'
local actual = r(deviation)[1, 2]
close_to `actual' -1 `tolerance'
local actual = r(maxdeviation)
close_to `actual' 1.5 `tolerance'
assert _N == 3
assert marker[3] == 3

_gracedr_graphs smd, study("`study'") saving("`scratch'/smd")
confirm file "`scratch'/smd.gph"
assert r(plotted) == 2
assert _N == 3

start_participants, study("`study'") arms("A A A")
set_column, name(sex) values("male female male")
set_column, name(age) values("30 40 50")
finish_participants, study("`study'")
_gracedr_graphs smd, study("`study'") saving("`scratch'/one_arm_smd")
assert r(plotted) == 0

_gracedr_graphs imbalance, study("`study'")
assert r(total) == 3
assert "`r(reached)'" == ""
local actual = r(deviation)[1, 1]
close_to `actual' 1.5 `tolerance'

start_participants, study("`study'") arms("A B A B A B A B A B")
set_column, name(sex) values("male female male female male female male female male female")
set_column, name(age) values(". . . . . . . . . .")
finish_participants, study("`study'")
_gracedr_graphs imbalance, study("`study'")
assert "`r(reached)'" == "10"
quietly graph describe gracedr_imbalance
_gracedr_graphs smd, study("`study'") saving("`scratch'/mixed_smd")
assert r(plotted) == 1
quietly graph describe gracedr_smd
expect_failure, ///
    rc(603) ///
    message("gracedr: could not save the graph") ///
    command(`"_gracedr_graphs smd, study("`study'") saving("`scratch'/no_dir/x")"')

gracedr setup, ///
    study("`scratch'/spaced") ///
    n(30) ///
    arms("Arm one" "Arm two") ///
    ratio(2 1) ///
    continuous(age) ///
    runin(0) ///
    seed(2)
local spaced "`scratch'/spaced"
start_participants, study("`spaced'") arms("Arm_one Arm_one Arm_one Arm_two")
set_column, name(age) values("10 20 30 40")
finish_participants, study("`spaced'")
_gracedr_graphs imbalance, study("`spaced'") saving("`scratch'/spaced_imbalance")
confirm file "`scratch'/spaced_imbalance.gph"
local actual = r(deviation)[1, 1]
close_to `actual' 0.333333333333333 `tolerance'
local actual = r(deviation)[1, 2]
close_to `actual' -0.333333333333333 `tolerance'
_gracedr_graphs smd, study("`spaced'") saving("`scratch'/spaced_smd")
confirm file "`scratch'/spaced_smd.gph"
assert r(plotted) == 1

expect_failure, ///
    rc(198) ///
    message("gracedr: unknown graphs subcommand nothing") ///
    command("_gracedr_graphs nothing, study(`study')")

remove_folder "`scratch'"
display "certify_graphs: all checks passed"
