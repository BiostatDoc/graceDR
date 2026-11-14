version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

_gracedr_study folder, study("`c(tmpdir)'")
local base "`r(folder)'"
local scratch "`base'/gracedr cert rules"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
local sex_design "categorical(sex: male female)"

gracedr setup, study("`scratch'/sex") n(100) arms(A B) `sex_design' runin(0) seed(1)
gracedr setup, ///
    study("`scratch'/sex_age") ///
    n(100) ///
    arms(A B) ///
    `sex_design' ///
    continuous(age) ///
    runin(0) ///
    seed(2)
gracedr setup, ///
    study("`scratch'/three") ///
    n(100) ///
    arms(A B C) ///
    ratio(2 1 1) ///
    `sex_design' ///
    runin(0) ///
    seed(3)
gracedr setup, ///
    study("`scratch'/equal") ///
    n(100) ///
    arms(A B C) ///
    `sex_design' ///
    runin(0) ///
    seed(4)
gracedr setup, ///
    study("`scratch'/blocks_three") ///
    n(100) ///
    arms(A B C) ///
    ratio(1 1 2) ///
    `sex_design' ///
    runin(0) ///
    seed(5)
gracedr setup, ///
    study("`scratch'/fractional") ///
    n(100) ///
    arms(A B) ///
    ratio(1.5 1) ///
    `sex_design' ///
    runin(0) ///
    seed(6)
gracedr setup, ///
    study("`scratch'/ratio") ///
    n(100) ///
    arms(A B) ///
    ratio(2 1) ///
    `sex_design' ///
    runin(0) ///
    seed(7)
gracedr setup, ///
    study("`scratch'/weighted") ///
    n(100) ///
    arms(A B) ///
    `sex_design' ///
    continuous(age) ///
    weights(1 3) ///
    runin(0) ///
    seed(8)
local sex "`scratch'/sex"
local sex_age "`scratch'/sex_age"
local three "`scratch'/three"
local equal "`scratch'/equal"
local blocks_three "`scratch'/blocks_three"
local fractional "`scratch'/fractional"
local ratio "`scratch'/ratio"
local weighted "`scratch'/weighted"

set seed 424242
local user_state = c(rngstate)

_gracedr_rules srs, study("`sex'")
check_probs "0.5 0.5"
assert "`r(phase)'" == "srs"
_gracedr_rules srs, study("`three'")
check_probs "0.5 0.25 0.25"
assert "`r(phase)'" == "srs"
_gracedr_rules srs, study("`ratio'")
check_probs "0.666666666666667 0.333333333333333"
fill_participants, ///
    study("`ratio'") ///
    arms("A A A A A A A B") ///
    sexes("male male male male male male male male")
_gracedr_rules srs, study("`ratio'")
check_probs "0.666666666666667 0.333333333333333"

_gracedr_rules blocks, study("`sex'")
check_probs "0.5 0.5"
assert "`r(phase)'" == "blocks"
fill_participants, study("`sex'") arms("A A") sexes("male male")
_gracedr_rules blocks, study("`sex'")
check_probs "0 1"
fill_participants, study("`sex'") arms("A A B B") sexes("male male male male")
_gracedr_rules blocks, study("`sex'")
check_probs "0.5 0.5"
fill_participants, study("`sex'") arms("A A A B") sexes("male male male male")
_gracedr_rules blocks, study("`sex'")
check_probs "0.25 0.75"
fill_participants, ///
    study("`sex'") ///
    arms("A A B B A B A B") ///
    sexes("male male male male male male male male")
_gracedr_rules blocks, study("`sex'")
check_probs "0.5 0.5"
fill_participants, ///
    study("`sex'") ///
    arms("A A B B A") ///
    sexes("male male male male male")
_gracedr_rules blocks, study("`sex'")
check_probs "0.333333333333333 0.666666666666667"
fill_participants, study("`blocks_three'") arms("A C C C") sexes("male male male male")
_gracedr_rules blocks, study("`blocks_three'")
check_probs "0.25 0.5 0.25"
assert "`r(phase)'" == "blocks"
expect_failure, ///
    rc(198) ///
    message("gracedr: blocks needs whole-number ratio values") ///
    command(`"_gracedr_rules blocks, study("`fractional'")"')
_gracedr_rules srs, study("`fractional'")
check_probs "0.6 0.4"

fill_participants, study("`sex'") arms("A A A B") sexes("male male male male")
_gracedr_rules minimization, study("`sex'") id(P5) options("sex(male)")
check_probs "0.2 0.8"
assert "`r(phase)'" == "minimization"
_gracedr_rules minimization, study("`sex'") id(P5) options("sex(male)") phigh(0.9)
check_probs "0.1 0.9"
_gracedr_rules minimization, study("`sex'") id(P5) options("sex(female)")
check_probs "0.5 0.5"
fill_participants, study("`sex'") arms("A A B B") sexes("male male male male")
_gracedr_rules minimization, study("`sex'") id(P5) options("sex(male)")
check_probs "0.5 0.5"
fill_participants, study("`sex'") arms("A") sexes("female")
_gracedr_rules minimization, study("`sex'") id(P2) options("sex(female)")
check_probs "0.2 0.8"
_gracedr_rules minimization, study("`sex'") id(P2) options("sex(.)")
check_probs "0.5 0.5"
assert "`r(missingvars)'" == "sex"
_gracedr_study empty, name(participants) study("`sex'")
_gracedr_study write, study("`sex'") name(participants)
_gracedr_rules minimization, study("`sex'") id(P1) options("sex(male)")
check_probs "0.5 0.5"

fill_participants, ///
    study("`three'") ///
    arms("A A A A B B") ///
    sexes("male male male male male male")
_gracedr_rules minimization, study("`three'") id(P7) options("sex(male)")
check_probs "0.133333333333333 0.0666666666666667 0.8"
fill_participants, study("`equal'") arms("A A A A") sexes("male male male male")
_gracedr_rules minimization, study("`equal'") id(P5) options("sex(male)")
check_probs "0.2 0.4 0.4"

local flat_ages "20 20 20 20"
fill_participants, ///
    study("`sex_age'") ///
    arms("A A B B") ///
    sexes("male male female female") ///
    ages("`flat_ages'")
local cuts "breaks(age: 40 60)"
local age_call "_gracedr_rules minimization, study(`sex_age') id(P3)"
_gracedr_rules minimization, study("`sex_age'") id(P5) options("sex(.) age(25)") `cuts'
check_probs "0.5 0.5"
_gracedr_rules minimization, study("`sex_age'") id(P5) options("sex(male) age(25)") `cuts'
check_probs "0.2 0.8"
_gracedr_rules minimization, study("`sex_age'") id(P5) options("sex(.) age(.)") `cuts'
check_probs "0.5 0.5"
assert "`r(missingvars)'" == "sex age"
fill_participants, ///
    study("`sex_age'") ///
    arms("A A") ///
    sexes("male male") ///
    ages("70 70")
_gracedr_rules minimization, study("`sex_age'") id(P3) options("sex(.) age(80)") `cuts'
check_probs "0.2 0.8"
_gracedr_rules minimization, study("`sex_age'") id(P3) options("sex(.) age(20)") `cuts'
check_probs "0.5 0.5"
_gracedr_rules minimization, study("`sex_age'") id(P3) options("sex(.) age(40)") `cuts'
check_probs "0.5 0.5"
_gracedr_rules minimization, study("`sex_age'") id(P3) options("sex(.) age(60)") `cuts'
check_probs "0.2 0.8"
expect_failure, ///
    rc(198) ///
    message("gracedr: breaks() names a categorical variable sex") ///
    command(`"`age_call' options("sex(.) age(80)") breaks(age: 40 60 | sex: 1)"')

expect_failure, ///
    rc(198) ///
    message("gracedr: minimization needs breaks() for the continuous variable age") ///
    command(`"`age_call' options("sex(male) age(50)")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: breaks() names an unknown balance variable height") ///
    command(`"`age_call' options("sex(.) age(50)") breaks(height: 1 2)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: breaks() must look like name: number number") ///
    command(`"`age_call' options("sex(.) age(50)") breaks(age 40 60)"')
expect_failure, ///
    rc(198) ///
    message("gracedr: breaks() must look like name: number number") ///
    command(`"`age_call' options("sex(.) age(50)") breaks(age: 40 abc)"')
local high_call "_gracedr_rules minimization, study(`sex') id(P5) options(sex(male))"
foreach bad_high in 0 1 -0.2 1.5 abc {
    expect_failure, ///
        rc(198) ///
        message("gracedr: phigh() must be a number greater than 0 and less than 1") ///
        command(`"`high_call' phigh(`bad_high')"')
}

fill_participants, ///
    study("`ratio'") ///
    arms("A A B") ///
    sexes("male male male")
_gracedr_rules blocks, study("`ratio'")
check_probs "0.666666666666667 0.333333333333333"
fill_participants, ///
    study("`ratio'") ///
    arms("A A A A A B B") ///
    sexes("male male male male male male male")
_gracedr_rules blocks, study("`ratio'")
check_probs "0.6 0.4"

fill_participants, study("`sex'") arms("A A A B") sexes(". . . male")
_gracedr_rules minimization, study("`sex'") id(P5) options("sex(male)")
check_probs "0.8 0.2"
fill_participants, ///
    study("`weighted'") ///
    arms("A A B B") ///
    sexes("male male female female") ///
    ages("20 20 70 70")
_gracedr_rules minimization, study("`weighted'") id(P5) options("sex(male) age(70)") `cuts'
check_probs "0.8 0.2"
fill_participants, ///
    study("`sex_age'") ///
    arms("A A B B") ///
    sexes("male male female female") ///
    ages("20 20 70 70")
_gracedr_rules minimization, study("`sex_age'") id(P5) options("sex(male) age(70)") `cuts'
check_probs "0.5 0.5"
_gracedr_rules minimization, ///
    study("`sex_age'") ///
    id(P5) ///
    options("sex(.) age(-5)") ///
    breaks(age: -10 -2.5 40)
check_probs "0.5 0.5"
_gracedr_rules minimization, ///
    study("`sex_age'") ///
    id(P5) ///
    options("sex(.) age(70)") ///
    breaks(age: -10 -2.5 40)
check_probs "0.8 0.2"

foreach bad_breaks in "age: 60 40" "age: 40 40" "age:" {
    local expected "gracedr: breaks() numbers must strictly increase"
    if "`bad_breaks'" == "age:" {
        local expected "gracedr: breaks() must look like name: number number"
    }
    expect_failure, ///
        rc(198) ///
        message("`expected'") ///
        command(`"`age_call' options("sex(.) age(50)") breaks(`bad_breaks')"')
}
local odd_high = char(36) + "x"
expect_failure, ///
    rc(198) ///
    message("gracedr: phigh() must be a number greater than 0 and less than 1") ///
    command(`"`high_call' phigh(`macval(odd_high)')"')
expect_failure, ///
    rc(198) ///
    message("gracedr: the participant values need id()") ///
    command(`"_gracedr_rules minimization, study("`sex'") options("sex(male)")"')

local fixture_arms "A A A A A A A A A A B B B B B B B B B B"
local fixture_sexes "male male male male male male male male male female"
local fixture_sexes "`fixture_sexes' male female female female female female"
local fixture_sexes "`fixture_sexes' female female female female female"
local fixture_ages "28 32 30 30 29 31 30 30 28 32 48 52 50 50 49 51 50 50 48 52"
fill_participants, ///
    study("`weighted'") ///
    arms("`fixture_arms'") ///
    sexes("`fixture_sexes'") ///
    ages("`fixture_ages'")
_gracedr_rules msb, study("`weighted'") id(P21) options("sex(male) age(70)")
check_probs "0.65 0.35"
assert "`r(phase)'" == "msb"
assert "`r(votes)'" == "2 1"
assert r(winner) == 1
_gracedr_rules msb, study("`weighted'") id(P21) options("sex(.) age(.)")
check_probs "0.5 0.5"
assert "`r(votes)'" == "0 0"
assert "`r(missingvars)'" == "sex age"

local table_arms "A A A A A A A A B B A A B B B B B B B B"
local table_sexes "male male male male male male male male male male"
local table_sexes "`table_sexes' female female female female female"
local table_sexes "`table_sexes' female female female female female"
fill_participants, study("`sex'") arms("`table_arms'") sexes("`table_sexes'")
_gracedr_votes tilt, base(0.5 0.5) winner(2) xi(0.65)
local expected_male "`r(probs)'"
_gracedr_votes tilt, base(0.5 0.5) winner(1) xi(0.65)
local expected_female "`r(probs)'"
_gracedr_rules msb, study("`sex'") id(P21) options("sex(male)")
check_probs "`expected_male'"
assert "`r(votes)'" == "2"
_gracedr_rules msb, study("`sex'") id(P21) options("sex(female)")
check_probs "`expected_female'"
assert "`r(votes)'" == "1"

local lopsided "A A A A A A A A A A A A"
local lopsided_sexes "male male male male male male male male male male male male"
fill_participants, study("`sex'") arms("`lopsided'") sexes("`lopsided_sexes'")
_gracedr_rules msb, study("`sex'") id(P13) options("sex(male)")
check_probs "0.5 0.5"
assert r(winner) == 0
fill_participants, study("`ratio'") arms("`lopsided'") sexes("`lopsided_sexes'")
_gracedr_rules msb, study("`ratio'") id(P13) options("sex(male)")
check_probs "0.666666666666667 0.333333333333333"

foreach rule in srs blocks minimization msb {
    expect_failure, ///
        rc(601) ///
        message("gracedr: no study found in `scratch'/nothing") ///
        command(`"_gracedr_rules `rule', study("`scratch'/nothing") id(P1) options("sex(male)")"')
}
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown rules subcommand nothing") ///
    command(`"_gracedr_rules nothing, study("`sex'")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: unknown rules subcommand") ///
    command(`"_gracedr_rules"')
expect_failure, ///
    rc(198) ///
    message("gracedr: the participant values need id()") ///
    command(`"_gracedr_rules msb, study("`sex'") options("sex(male)")"')
expect_failure, ///
    rc(198) ///
    message("gracedr: id() must not be empty") ///
    command(`"_gracedr_rules minimization, study("`sex'") id(" ") options("sex(male)")"')
expect_failure, ///
    message("gracedr") ///
    command(`"_gracedr_rules msb, study("`sex'") id(P1) options("height(1)")"')
assert c(rngstate) == "`user_state'"

make_data 3
generate marker = _n
_gracedr_rules msb, study("`sex'") id(P13) options("sex(male)")
_gracedr_rules minimization, study("`sex'") id(P13) options("sex(male)")
_gracedr_rules blocks, study("`sex'")
_gracedr_rules srs, study("`sex'")
assert _N == 3
assert marker[3] == 3
assert c(rngstate) == "`user_state'"

remove_folder "`scratch'"
display "certify_rules: all checks passed"
