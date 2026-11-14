version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert dollar"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

local dollar = char(36)
local dollar_text = "a" + char(36) + "HOME"
local lower_text = "a" + char(36) + "home"
local odd_study = "`scratch'/s" + char(36) + "HOME"
remove_folder "`macval(odd_study)'"

gracedr setup, ///
    study(`"`macval(odd_study)'"') ///
    n(60) ///
    arms(A B) ///
    categorical(sex: male female) ///
    seed(1)
assert r(study) == "`scratch'/s" + char(36) + "HOME"
foreach name in design codes participants state audit {
    assert fileexists("`macval(odd_study)'/`name'.dta")
}
assert !fileexists("`scratch'/s/design.dta")

_gracedr_study append_audit, ///
    study(`"`macval(odd_study)'"') ///
    action(randomize) ///
    id(P1) ///
    reason(`"`macval(dollar_text)'"')
_gracedr_study read, study(`"`macval(odd_study)'"') name(audit)
assert _N == 2
assert reason[2] == "a" + char(36) + "HOME"

_gracedr_study setting, study(`"`macval(odd_study)'"') name(n)
assert "`r(value)'" == "60"

_gracedr_rng draw, study(`"`macval(odd_study)'"') probs(1 1) arms(A B)
assert inlist("`r(arm)'", "A", "B")

_gracedr_values parse, ///
    study(`"`macval(odd_study)'"') ///
    id(`"`macval(dollar_text)'"') ///
    options("sex(male)")
assert r(id) == "a" + char(36) + "HOME"

local label_message "gracedr: arm labels and levels must not contain"
local label_message "`label_message' double quotes, backticks or dollar signs"
local validate_call "_gracedr_design validate, n(60) arms(A B)"
expect_failure, ///
    rc(198) ///
    message("`label_message'") ///
    command(`"`validate_call' categorical(kind: `macval(dollar_text)' plain)"')

tempname handle
file open `handle' using "`scratch'/dollar.csv", write text replace
file write `handle' "code,arm" _n
file write `handle' `"1,`macval(dollar_text)'"' _n
file close `handle'
local expected = "gracedr: unknown arm(s) in the codes file: a" + char(36) + "HOME"
expect_failure, ///
    rc(198) ///
    message(`"`macval(expected)'"') ///
    command(`"gracedr codes using "`scratch'/dollar.csv", arms(A B)"')

remove_folder "`scratch'"

display "certify_dollar: all checks passed"
