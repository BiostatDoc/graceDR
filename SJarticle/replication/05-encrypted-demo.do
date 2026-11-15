version 19
clear
set linesize 80

python:
import os
import secrets

previous = {name: value for name, value in os.environ.items() if name == "GRACEDR_PASSPHRASE"}
os.environ["GRACEDR_PASSPHRASE"] = secrets.token_hex(16)
end

local study "studies/encrypted"
remove_folder "`study'"

gracedr setup, ///
    study("`study'") ///
    n(40) ///
    arms(A B) ///
    categorical(sex: male female | race: white black other) ///
    continuous(age) ///
    codes("data/example_codes.csv") ///
    seed(20260611) ///
    encrypt

use "data/example_participants.dta", clear
local total = _N
forvalues row = 1/`total' {
    local id = id[`row']
    local sex = sex[`row']
    local race = race[`row']
    local age = age[`row']
    quietly gracedr randomize, study("`study'") id(`id') sex(`sex') race(`race') age(`age')
}

local last_id "`r(id)'"
local last_arm "`r(arm)'"
local new_arm = cond("`last_arm'" == "A", "B", "A")
gracedr override, ///
    study("`study'") ///
    id(`last_id') ///
    arm(`new_arm') ///
    reason("Wrong race entered in the example.")

local files : dir "`study'" files "*"
display as text `"Files in the encrypted study: `files'"'
gracedr status, study("`study'")

use_study_participants "studies/example"
drop time
tempfile plain
quietly save `"`plain'"'
use_study_participants "`study'"
drop time
local rows = _N
cf _all using `"`plain'"'
display as text "The encrypted and the plain study agree on `rows' participants."

python:
import os

removed = os.environ.pop("GRACEDR_PASSPHRASE", None)
os.environ.update(previous)
end
