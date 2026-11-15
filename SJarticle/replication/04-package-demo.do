version 19
clear
set linesize 80

local study "studies/example"
remove_folder "`study'"

gracedr setup, ///
    study("`study'") ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    codes("data/example_codes.csv") ///
    seed(20260611)

use "data/example_participants.dta", clear
local total = _N
forvalues row = 1/`total' {
    local id = id[`row']
    local sex = sex[`row']
    local race = race[`row']
    local age = age[`row']
    if `row' < `total' {
        quietly gracedr randomize, study("`study'") id(`id') sex(`sex') race(`race') age(`age')
    }
    else {
        gracedr randomize, study("`study'") id(`id') sex(`sex') race(`race') age(`age')
    }
}
local last_id "`r(id)'"
local last_arm "`r(arm)'"

gracedr status, study("`study'") graphs saving("figures/status")
graph export "figures/status-imbalance.pdf", name(gracedr_imbalance) replace
graph export "figures/status-smd.pdf", name(gracedr_smd) replace

local new_arm = cond("`last_arm'" == "A", "B", "A")
gracedr override, ///
    study("`study'") ///
    id(`last_id') ///
    arm(`new_arm') ///
    reason("Wrong race entered in the example.")
quietly gracedr audit, study("`study'")
display as text "Rows in the audit log: " r(rows)
use "`study'/audit.dta", clear
list action id old new reason in -2/l, noobs separator(0) abbreviate(20)
use "data/example_participants.dta", clear

local matches = 0
forvalues row = 1/`total' {
    local id = id[`row']
    quietly gracedr replay, study("`study'") id(`id')
    local matches = `matches' + r(match)
}
display as text "Replays that match the record: `matches' of `total'"

gracedr simulate, ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    methods(srs mmsb) ///
    nsims(20) ///
    seed(1) ///
    generator(iid) ///
    probs(sex: 0.48 0.52 | race: 0.62 0.23 0.15) ///
    meansd(age: 60 10)
