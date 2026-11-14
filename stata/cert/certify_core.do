version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define random_rows
    args study count three_arms
    if `count' == 0 {
        _gracedr_study empty, name(participants) study("`study'")
        _gracedr_study write, study("`study'") name(participants)
        exit
    }
    local arm_list ""
    local sex_list ""
    local race_list ""
    local age_list ""
    local arm_total = cond(`three_arms' == 1, 3, 2)
    forvalues position = 1/`count' {
        local arm_draw = ceil(runiform() * `arm_total')
        local letter = char(64 + `arm_draw')
        local arm_list "`arm_list' `letter'"
        local sex = cond(inrange(runiform(), 0.5, 1), "male", "female")
        if inrange(runiform(), 0.9, 1) {
            local sex "."
        }
        local sex_list "`sex_list' `sex'"
        local race_draw = ceil(runiform() * 3)
        local race : word `race_draw' of white black other
        local race_list "`race_list' `race'"
        local age = round(30 + 40 * runiform(), 0.1)
        if inrange(runiform(), 0.92, 1) {
            local age "."
        }
        local age_list "`age_list' `age'"
    }
    start_participants, study("`study'") arms("`arm_list'")
    set_column, name(sex) values("`sex_list'")
    if `three_arms' == 1 {
        set_column, name(race) values("`race_list'")
    }
    set_column, name(age) values("`age_list'")
    finish_participants, study("`study'")
end

program define compare_probs
    args live core
    local count : word count `live'
    assert wordcount("`core'") == `count'
    forvalues position = 1/`count' {
        local expected = real(word("`live'", `position'))
        local actual = real(word("`core'", `position'))
        close_to `actual' `expected' 0.000000001
    }
end

program define compare_methods
    syntax , STUDY(string) OPTIONS(string) BREAKS(string) [ID(string)]
    if missing("`id'") {
        local id "Pnew"
    }
    _gracedr_mmsb probs, study("`study'") id(`id') options("`options'")
    local live "`r(probs)'"
    local live_phase "`r(phase)'"
    _gracedr_core probs, study("`study'") method(mmsb) id(`id') options("`options'")
    compare_probs "`live'" "`r(probs)'"
    assert "`r(phase)'" == "`live_phase'"
    local phases "quota runin bound msb-biased msb-random"
    local phase_position : list posof "`live_phase'" in phases
    assert inrange(`phase_position', 1, 5)
    scalar seen`phase_position' = 1
    foreach method in srs blocks msb minimization {
        _gracedr_rules `method', ///
            study("`study'") ///
            id(`id') ///
            options("`options'") ///
            breaks(`breaks')
        local live "`r(probs)'"
        _gracedr_core probs, ///
            study("`study'") ///
            method(`method') ///
            id(`id') ///
            options("`options'") ///
            breaks(`breaks')
        compare_probs "`live'" "`r(probs)'"
    }
end

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert core"
remove_folder "`scratch'"
quietly mkdir "`scratch'"

gracedr setup, ///
    study("`scratch'/two") ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(10) ///
    seed(1)
gracedr setup, ///
    study("`scratch'/three") ///
    n(60) ///
    arms(A B C) ///
    ratio(2 1 1) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    weights(1 2 3) ///
    runin(12) ///
    forcedat(30) ///
    sizebound(2) ///
    pstar(0.4) ///
    xi(0.7) ///
    seed(2)
gracedr setup, ///
    study("`scratch'/rar") ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female) ///
    continuous(age) ///
    runin(10) ///
    runinmethod(rar) ///
    seed(3)

set seed 20261201
local two_values `""sex(male) age(25)" "sex(female) age(70)" "sex(.) age(40)" "sex(male) age(.)""'
local three_values `""sex(male) race(white) age(25)" "sex(female) race(other) age(70)""'
local three_values `"`three_values' "sex(.) race(black) age(40)" "sex(male) race(.) age(.)""'
foreach count in 0 5 11 14 31 39 {
    random_rows "`scratch'/two" `count' 0
    foreach options of local two_values {
        compare_methods, study("`scratch'/two") options(`options') breaks(age: 40 55)
    }
}
foreach count in 0 9 13 29 33 59 {
    random_rows "`scratch'/three" `count' 1
    foreach options of local three_values {
        compare_methods, study("`scratch'/three") options(`options') breaks(age: 40 55)
    }
}
foreach count in 4 12 {
    random_rows "`scratch'/rar" `count' 0
    compare_methods, study("`scratch'/rar") options(sex(male) age(25)) breaks(age: 40 55)
}

forvalues position = 1/5 {
    assert scalar(seen`position') == 1
}
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown core subcommand nothing") ///
    command(`"_gracedr_core nothing"')

remove_folder "`scratch'"
display "certify_core: all checks passed"
