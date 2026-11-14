version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert mmsb"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
local sex_design "categorical(sex: male female)"

gracedr setup, study("`scratch'/ten") n(10) arms(A B) `sex_design' runin(0) seed(1)
gracedr setup, study("`scratch'/twenty") n(20) arms(A B) `sex_design' seed(2)
gracedr setup, study("`scratch'/twenty_rar") n(20) arms(A B) `sex_design' runinmethod(rar) seed(3)
gracedr setup, study("`scratch'/forty") n(40) arms(A B) `sex_design' runin(0) seed(4)
gracedr setup, study("`scratch'/three_arms") n(60) arms(A B C) `sex_design' runin(0) seed(5)
gracedr setup, study("`scratch'/sixty") n(60) arms(A B) `sex_design' runin(0) seed(6)
gracedr setup, study("`scratch'/ratio") n(60) arms(A B) ratio(2 1) `sex_design' runin(0) seed(7)
gracedr setup, ///
    study("`scratch'/forced") ///
    n(60) ///
    arms(A B) ///
    `sex_design' ///
    runin(0) ///
    forcedat(20) ///
    seed(8)
gracedr setup, study("`scratch'/three_age") n(60) arms(A B C) `sex_design' ///
    continuous(age) runin(0) seed(10)
gracedr setup, ///
    study("`scratch'/spaced") ///
    n(60) ///
    arms("Arm one" "Arm two") ///
    `sex_design' ///
    runin(0) ///
    seed(11)
gracedr setup, ///
    study("`scratch'/five") ///
    n(100) ///
    arms(A B C D E) ///
    `sex_design' ///
    runin(0) ///
    seed(12)
gracedr setup, study("`scratch'/broken") n(60) arms(A B) `sex_design' runin(0) seed(13)
gracedr setup, ///
    study("`scratch'/continuous") ///
    n(60) ///
    arms(A B) ///
    `sex_design' ///
    continuous(age) ///
    weights(1 3) ///
    runin(0) ///
    seed(9)

local ten "`scratch'/ten"
local twenty "`scratch'/twenty"
local twenty_rar "`scratch'/twenty_rar"
local forty "`scratch'/forty"
local three_arms "`scratch'/three_arms"
local sixty "`scratch'/sixty"
local ratio "`scratch'/ratio"
local forced "`scratch'/forced"
local continuous "`scratch'/continuous"
local three_age "`scratch'/three_age"
local spaced "`scratch'/spaced"
local five "`scratch'/five"
local broken "`scratch'/broken"

local mixed "male female male female male female male female male"
local ten_arms "A A A A A B B"
local ten_sexes "male female male female male female male"
fill_participants, study("`ten'") arms("`ten_arms'") sexes("`ten_sexes'")
_gracedr_mmsb probs, study("`ten'") id(P8) options("sex(male)")
check_probs "0 1"
assert "`r(phase)'" == "quota"

fill_participants, study("`twenty'") arms("A A A A A B B B B") sexes("`mixed'")
_gracedr_mmsb probs, study("`twenty'") id(P10) options("sex(female)")
check_probs "0 1"
assert "`r(phase)'" == "runin"

local runin_arms "A A A B B B"
local runin_sexes "male male male female female female"
fill_participants, study("`twenty'") arms("`runin_arms'") sexes("`runin_sexes'")
_gracedr_mmsb probs, study("`twenty'") id(P7) options("sex(male)")
check_probs "0.35 0.65"
assert "`r(phase)'" == "runin"
assert "`r(votes)'" == "2"
assert r(winner) == 2
fill_participants, study("`twenty_rar'") arms("`runin_arms'") sexes("`runin_sexes'")
_gracedr_mmsb probs, study("`twenty_rar'") id(P7) options("sex(male)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "runin"

local forty_arms "A A A A A A A A A B B B"
local forty_sexes "male female male female male female male female male female male female"
fill_participants, study("`forty'") arms("`forty_arms'") sexes("`forty_sexes'")
_gracedr_mmsb probs, study("`forty'") id(P13) options("sex(male)")
check_probs "0 1"
assert "`r(phase)'" == "bound"

local three_arms_list "A A A A A A A A A B B B B B C C C C"
local three_sexes "male female male female male female male female male female"
local three_sexes "`three_sexes' male female male female male female male female"
fill_participants, study("`three_arms'") arms("`three_arms_list'") sexes("`three_sexes'")
_gracedr_mmsb probs, study("`three_arms'") id(P19) options("sex(male)")
check_probs "0 0.483870967741935 0.516129032258065"
assert "`r(phase)'" == "bound"

local table_arms "A A A A A A A A B B A A B B B B B B B B"
local table_sexes "male male male male male male male male male male"
local table_sexes "`table_sexes' female female female female female"
local table_sexes "`table_sexes' female female female female female"
fill_participants, study("`sixty'") arms("`table_arms'") sexes("`table_sexes'")
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(male)")
check_probs "0.35 0.65"
assert "`r(phase)'" == "msb-biased"
assert "`r(votes)'" == "2 0"
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(female)")
check_probs "0.65 0.35"
assert "`r(phase)'" == "msb-biased"
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(.)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "msb-random"
assert "`r(missingvars)'" == "sex"
assert r(winner) == 0

fill_participants, ///
    study("`sixty'") ///
    arms("`table_arms' A A B B") ///
    sexes("`table_sexes' . . . .")
_gracedr_mmsb probs, study("`sixty'") id(P25) options("sex(male)")
check_probs "0.35 0.65"
assert "`r(phase)'" == "msb-biased"

local even_arms "A A A A A A A A B B B B B B B B B B B B"
local even_sexes "male male male male female female female female"
local even_sexes "`even_sexes' male male male male male male"
local even_sexes "`even_sexes' female female female female female female"
fill_participants, study("`sixty'") arms("`even_arms'") sexes("`even_sexes'")
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(male)")
check_probs "0.694174757281553 0.305825242718447"
assert "`r(phase)'" == "msb-biased"
assert "`r(votes)'" == "0 1"

local conflict_arms "A A A A A A A A B B B B B B B B B B B B"
local conflict_sexes "male female female female female female female female"
local conflict_sexes "`conflict_sexes' male male male male male"
local conflict_sexes "`conflict_sexes' male male male male female female female"
fill_participants, study("`sixty'") arms("`conflict_arms'") sexes("`conflict_sexes'")
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(female)")
check_probs "0.55 0.45"
assert "`r(phase)'" == "msb-random"
assert "`r(votes)'" == "2 1"
assert r(winner) == 0
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(male)")
check_probs "0.694174757281553 0.305825242718447"
assert "`r(phase)'" == "msb-biased"
assert r(winner) == 1

local ratio_arms "A A A A A A A A B B B B"
local ratio_sexes "male female male female male female male female male female male female"
fill_participants, study("`ratio'") arms("`ratio_arms'") sexes("`ratio_sexes'")
_gracedr_mmsb probs, study("`ratio'") id(P13) options("sex(male)")
check_probs "0.666666666666667 0.333333333333333"
assert "`r(phase)'" == "msb-random"
local skewed_sexes "male male male male male male male male female female female female"
fill_participants, study("`ratio'") arms("`ratio_arms'") sexes("`skewed_sexes'")
_gracedr_mmsb probs, study("`ratio'") id(P13) options("sex(male)")
check_probs "0.518518518518519 0.481481481481481"
assert "`r(phase)'" == "msb-biased"

local forced_arms "A A A A A A A A A A B B B B B B B B B"
local forced_sexes "male female male female male female male female male female"
local forced_sexes "`forced_sexes' male female male female male female male female male"
fill_participants, study("`forced'") arms("`forced_arms'") sexes("`forced_sexes'")
_gracedr_mmsb probs, study("`forced'") id(P20) options("sex(male)")
check_probs "0 1"
assert "`r(phase)'" == "quota"

local age_arms "A A A A A A A A A A B B B B B B B B B B"
local age_sexes "male female male female male female male female male female"
local age_sexes "`age_sexes' male female male female male female male female male female"
local age_values "28 32 30 30 29 31 30 30 28 32 48 52 50 50 49 51 50 50 48 52"
fill_participants, ///
    study("`continuous'") ///
    arms("`age_arms'") ///
    sexes("`age_sexes'") ///
    ages("`age_values'")
_gracedr_mmsb probs, study("`continuous'") id(P21) options("sex(male) age(70)")
check_probs "0.65 0.35"
assert "`r(phase)'" == "msb-biased"
assert "`r(votes)'" == "0 1 0"
_gracedr_mmsb probs, study("`continuous'") id(P21) options("age(10) sex(female)")
check_probs "0.35 0.65"
assert "`r(votes)'" == "0 2 0"
_gracedr_mmsb probs, study("`continuous'") id(P21) options("sex(male) age(40)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "msb-random"
_gracedr_mmsb probs, study("`continuous'") id(P21) options("sex(male) age(.)")
check_probs "0.5 0.5"
assert "`r(missingvars)'" == "age"

local lonely_sexes "male female male female male female male female"
fill_participants, study("`ten'") arms("B B B B B B B B") sexes("`lonely_sexes'")
_gracedr_mmsb probs, study("`ten'") id(P9) options("sex(male)")
assert "`r(phase)'" == "quota"
local first_probability = real(word("`r(probs)'", 1))
local second_probability = real(word("`r(probs)'", 2))
close_to `first_probability' 2.5 0.000000001
close_to `second_probability' 0 0.000000001
local last_arms "A A A A A B B B B"
local last_sexes "male female male female male female male female male"
fill_participants, study("`ten'") arms("`last_arms'") sexes("`last_sexes'")
_gracedr_mmsb probs, study("`ten'") id(P10) options("sex(female)")
check_probs "0 1"
assert "`r(phase)'" == "quota"

local after_arms "A A A A A B B B B B"
local after_sexes "male female male female male female male female male female"
fill_participants, study("`twenty'") arms("`after_arms'") sexes("`after_sexes'")
_gracedr_mmsb probs, study("`twenty'") id(P11) options("sex(male)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "msb-random"
assert "`r(votes)'" == "0 0"
fill_participants, study("`twenty'") arms("`runin_arms'") sexes("`runin_sexes'")
_gracedr_mmsb probs, study("`twenty'") id(P7) options("sex(.)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "runin"
assert r(winner) == 0

local final_arms "A A A A A A A A A A B B B B B B B B B B"
local final_sexes "male female male female male female male female male female"
local final_sexes "`final_sexes' male female male female male female male female male female"
fill_participants, study("`forced'") arms("`final_arms'") sexes("`final_sexes'")
_gracedr_mmsb probs, study("`forced'") id(P21) options("sex(male)")
check_probs "0.5 0.5"
assert "`r(phase)'" == "msb-random"

local behind_arms "A A A B B B C C C C C C C C C C C C"
local behind_sexes "male female male female male female male female male female"
local behind_sexes "`behind_sexes' male female male female male female male female"
fill_participants, study("`three_arms'") arms("`behind_arms'") sexes("`behind_sexes'")
_gracedr_mmsb probs, study("`three_arms'") id(P19) options("sex(male)")
check_probs "0.5 0.5 0"
assert "`r(phase)'" == "bound"

local age_a "28 32 30 30 29 31 30 30 28 32"
local age_b "48 52 50 50 49 51 50 50 48 52"
local age_c "68 72 70 70 69 71 70 70 68 72"
local alternating "male female male female male female male female male female"
local three_ages "`age_a' `age_b' `age_c'"
local three_sexes "`alternating' `alternating' `alternating'"
local three_age_arms "A A A A A A A A A A B B B B B B B B B B C C C C C C C C C C"
fill_participants, ///
    study("`three_age'") ///
    arms("`three_age_arms'") ///
    sexes("`three_sexes'") ///
    ages("`three_ages'")
_gracedr_mmsb probs, study("`three_age'") id(P31) options("sex(male) age(100)")
check_probs "0.481481481481481 0.259259259259259 0.259259259259259"
assert "`r(phase)'" == "msb-biased"
assert "`r(votes)'" == "0 1 0"

local split_sexes "male male male male male male male male male female"
local split_sexes "`split_sexes' male female female female female"
local split_sexes "`split_sexes' female female female female female"
fill_participants, ///
    study("`continuous'") ///
    arms("`age_arms'") ///
    sexes("`split_sexes'") ///
    ages("`age_values'")
_gracedr_mmsb probs, study("`continuous'") id(P21) options("sex(male) age(70)")
check_probs "0.65 0.35"
assert "`r(votes)'" == "2 1 0"
assert r(winner) == 1

local size_arms "A A A A A A B B B B B B"
local size_sexes "male female male female male female male female male female male female"
fill_participants, study("`ratio'") arms("`size_arms'") sexes("`size_sexes'")
_gracedr_mmsb probs, study("`ratio'") id(P13) options("sex(male)")
check_probs "0.818518518518519 0.181481481481481"
assert "`r(votes)'" == "0 1"
assert "`r(phase)'" == "msb-biased"

fill_participants, ///
    study("`continuous'") ///
    arms("`age_arms' A B") ///
    sexes("`age_sexes' male female") ///
    ages("`age_values' . .")
_gracedr_mmsb probs, study("`continuous'") id(P23) options("sex(male) age(70)")
check_probs "0.65 0.35"
assert "`r(votes)'" == "0 1 0"
fill_participants, ///
    study("`continuous'") ///
    arms("`age_arms'") ///
    sexes("`age_sexes'") ///
    ages("`age_values'")
_gracedr_mmsb probs, study("`continuous'") id(P21) options("sex(.) age(.)")
check_probs "0.5 0.5"
assert "`r(votes)'" == "0 0 0"
assert "`r(missingvars)'" == "sex age"
assert "`r(phase)'" == "msb-random"
assert missing(r(number2))
assert "`r(value1)'" == ""

local spaced_arms ""
local spaced_sexes ""
forvalues position = 1/10 {
    local spaced_arms "`spaced_arms' Arm_one"
    local spaced_sexes "`spaced_sexes' male"
}
forvalues position = 1/10 {
    local spaced_arms "`spaced_arms' Arm_two"
    local spaced_sexes "`spaced_sexes' female"
}
fill_participants, study("`spaced'") arms("`spaced_arms'") sexes("`spaced_sexes'")
_gracedr_mmsb probs, study("`spaced'") id(P21) options("sex(male)")
check_probs "0.35 0.65"
assert "`r(votes)'" == "2 0"

fill_participants, ///
    study("`five'") ///
    arms("A A B B C C D D E E") ///
    sexes("male female male female male female male female male female")
_gracedr_mmsb probs, study("`five'") id(P11) options("sex(male)")
check_probs "0.2 0.2 0.2 0.2 0.2"
assert "`r(phase)'" == "msb-random"

fill_participants, study("`broken'") arms("A B A B") sexes("male female male female")
preserve
_gracedr_study read, study("`broken'") name(design)
quietly replace value = "abc" if name == "n"
_gracedr_study write, study("`broken'") name(design)
restore
expect_failure, ///
    rc(198) ///
    message("gracedr: design.dta setting n is not a number") ///
    command(`"_gracedr_mmsb probs, study("`broken'") id(P5) options("sex(male)")"')

fill_participants, ///
    study("`ten'") ///
    arms("A A A A A B B B B B") ///
    sexes("male female male female male female male female male female")
expect_failure, ///
    rc(198) ///
    message("gracedr: the study already has 10 participants") ///
    command(`"_gracedr_mmsb probs, study("`ten'") id(P11) options("sex(male)")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: missing value(s) for: sex") ///
    command(`"_gracedr_mmsb probs, study("`sixty'") id(P21) options("")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: (study) is reserved and cannot be a participant id") ///
    command(`"_gracedr_mmsb probs, study("`sixty'") id((study)) options("sex(male)")"')
expect_failure, ///
    rc(601) ///
    message("gracedr: no study found in `scratch'/none") ///
    command(`"_gracedr_mmsb probs, study("`scratch'/none") id(P1) options("sex(male)")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown mmsb subcommand nonsense") ///
    command(`"_gracedr_mmsb nonsense"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown mmsb subcommand") ///
    command(`"_gracedr_mmsb"')

make_data 3
set seed 21
local user_state = c(rngstate)
fill_participants, study("`sixty'") arms("`table_arms'") sexes("`table_sexes'")
make_data 3
_gracedr_mmsb probs, study("`sixty'") id(P21) options("sex(male)")
assert _N == 3
assert x[3] == 30
assert c(rngstate) == "`user_state'"

remove_folder "`scratch'"

display "certify_mmsb: all checks passed"
