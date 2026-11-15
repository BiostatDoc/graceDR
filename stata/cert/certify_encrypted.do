version 19
clear all
set linesize 255
set graphics off
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define assert_no_new_files
    args before
    local after : dir "`c(tmpdir)'" files "*"
    local unexpected ""
    foreach file of local after {
        local is_known : list file in before
        local is_shell_probe = strpos("`file'", "__PSScriptPolicyTest") == 1
        if `is_known' == 0 & `is_shell_probe' == 0 {
            local unexpected "`unexpected' `file'"
        }
    }
    if !missing("`unexpected'") {
        display as error "new files in `c(tmpdir)':`unexpected'"
    }
    assert missing("`unexpected'")
end

program define assert_only_zips
    args folder
    local files : dir "`folder'" files "*"
    local file_count : word count `files'
    assert inrange(`file_count', 1, 1e9)
    foreach file of local files {
        assert substr(strlower("`file'"), -4, 4) == ".zip"
    }
end

program define randomize_forty
    args study
    local cycle_sex "male female male male female female male female"
    local cycle_age "30 41 52 63 34 45 56 67 38 49 50 61"
    forvalues position = 1/40 {
        local sex_slot = mod(`position' - 1, 8) + 1
        local age_slot = mod(`position' - 1, 12) + 1
        local sex : word `sex_slot' of `cycle_sex'
        local age : word `age_slot' of `cycle_age'
        quietly gracedr randomize, ///
            study("`study'") ///
            id(P`position') ///
            sex(`sex') ///
            age(`age')
    }
end

program define compare_studies
    args plain secret
    foreach name in participants codes audit state {
        read_dataset "`plain'" `name'
        capture drop time
        tempfile reference
        quietly save `"`reference'"'
        read_dataset "`secret'" `name'
        capture drop time
        quietly cf _all using `"`reference'"'
    }
    clear
end

program define take_checksums, rclass
    args folder
    local sums ""
    foreach name in design codes participants audit state {
        quietly checksum "`folder'/`name'.zip"
        local sums "`sums' `r(checksum)'"
    }
    return local sums = strtrim("`sums'")
end

python:
import os
import sys
from sfi import Macro

sys.path[:0] = [os.path.join(Macro.getLocal("stata_dir"), "python")]
import gracedr_zip

canary = "".join(["Canary", "Phrase", "5512"])
other = "".join(["Other", "Phrase", "3307"])
os.environ["GRACEDR_PASSPHRASE"] = canary
end
local before : dir "`c(tmpdir)'" files "*"

_gracedr_study folder, study("`c(tmpdir)'")
local scratch "`r(folder)'/gracedr cert encrypted"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
write_codes_for "`scratch'/codes.csv" 20
local design "categorical(sex: male female) continuous(age)"
local plain "`scratch'/plain"
local secret "`scratch'/secret"

gracedr setup, ///
    study("`plain'") ///
    n(40) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(20261114)
gracedr setup, ///
    study("`secret'") ///
    n(40) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(20261114) ///
    encrypt
foreach name in design codes participants audit state {
    confirm file "`secret'/`name'.zip"
    capture confirm file "`secret'/`name'.dta"
    assert !missing(_rc) & _rc != 0
}
assert_only_zips "`secret'"
assert_no_new_files `"`before'"'

expect_failure, ///
    rc(602) ///
    message("a study already exists") ///
    command(`"gracedr setup, study("`secret'") n(40) arms(A B) `design' seed(1)"')
_gracedr_study exists, study("`secret'")
assert r(exists) == 1

randomize_forty "`plain'"
randomize_forty "`secret'"
assert_only_zips "`secret'"
assert_no_new_files `"`before'"'

read_dataset "`secret'" participants
assert _N == 40
local observed_arms ""
forvalues position = 1/40 {
    local one_arm = arm[`position']
    local observed_arms "`observed_arms'`one_arm'"
}
local reference_arms "ABABABABBAABBBBBBABAAAAAAABABABABBBBAABA"
assert "`observed_arms'" == "`reference_arms'"
clear
compare_studies "`plain'" "`secret'"

gracedr status, study("`secret'")
assert r(n_randomized) == 40
gracedr audit, study("`secret'")
assert r(rows) == 41
gracedr replay, study("`secret'") id(P7)
assert r(match) == 1
gracedr simulate, ///
    study("`secret'") ///
    methods(mmsb srs) ///
    nsims(2) ///
    seed(3) ///
    saving("`scratch'/simulated.dta")
assert r(nsims) == 2
assert_only_zips "`secret'"
assert_no_new_files `"`before'"'

gracedr setup, ///
    study("`scratch'/small") ///
    n(4) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(7) ///
    encrypt
local small "`scratch'/small"
quietly gracedr randomize, study("`small'") id(P1) sex(male) age(30)
local first_arm "`r(arm)'"
local other_arm = cond("`first_arm'" == "A", "B", "A")
gracedr override, study("`small'") id(P1) arm(`other_arm') reason("encrypted check")
gracedr replay, study("`small'") id(P1)
assert r(match) == 1
assert_only_zips "`small'"
take_checksums "`small'"
local sums_after_one "`r(sums)'"
read_dataset "`small'" state
local state_after_one = state[1]
clear

quietly mkdir "`small'/participants.tmp.zip"
expect_failure, ///
    rc(603) ///
    message("gracedr: could not write participants.zip") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(female) age(35)"')
remove_folder "`small'/participants.tmp.zip"
assert_only_zips "`small'"
assert_no_new_files `"`before'"'
take_checksums "`small'"
assert "`r(sums)'" == "`sums_after_one'"

quietly mkdir "`small'/state.tmp.zip"
expect_failure, ///
    rc(603) ///
    message("files already written: participants.zip codes.zip audit.zip") ///
    command(`"gracedr randomize, study("`small'") id(P2) sex(female) age(35)"')
remove_folder "`small'/state.tmp.zip"
assert_only_zips "`small'"
assert_no_new_files `"`before'"'
read_dataset "`small'" state
assert state[1] == "`state_after_one'"
clear

take_checksums "`secret'"
local sums_secret "`r(sums)'"
python:
os.environ["GRACEDR_PASSPHRASE"] = other
end
foreach command in ///
    `"gracedr status, study("`secret'")"' ///
    `"gracedr audit, study("`secret'")"' ///
    `"gracedr replay, study("`secret'") id(P3)"' ///
    `"gracedr randomize, study("`secret'") id(P41) sex(male) age(30)"' ///
    `"gracedr override, study("`secret'") id(P3) arm(A) reason("wrong password")"' ///
    `"gracedr simulate, study("`secret'") methods(srs) nsims(2) seed(3)"' ///
    `"_gracedr_study read, study("`secret'") name(participants)"' {
    expect_failure, rc(499) message("wrong password") command(`"`command'"')
}
assert_only_zips "`secret'"
assert_no_new_files `"`before'"'
take_checksums "`secret'"
assert "`r(sums)'" == "`sums_secret'"
make_data 3
generate marker = _n
quietly describe, varlist
local held_vars "`r(varlist)'"
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"_gracedr_study write, study("`secret'") name(participants)"')
assert _N == 3
quietly describe, varlist
assert "`r(varlist)'" == "`held_vars'"
assert marker[3] == 3
clear
take_checksums "`secret'"
assert "`r(sums)'" == "`sums_secret'"
python:
os.environ["GRACEDR_PASSPHRASE"] = canary
end
gracedr status, study("`secret'")

quietly log using "`scratch'/trace.log", text replace name(trace)
set trace on
gracedr status, study("`secret'")
set trace off
macro list
quietly log close trace
python:
with open(os.path.join(Macro.getLocal("scratch"), "trace.log"), "r", -1, "utf8") as handle:
    text = handle.read()
Macro.setLocal("log_size", str(len(text)))
Macro.setLocal("leaked", str(int(canary in text) + int(other in text)))
end
assert inrange(`log_size', 1001, 100000000)
assert `leaked' == 0

gracedr setup, ///
    study("`scratch'/layers") ///
    n(4) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(11) ///
    encrypt
local layers "`scratch'/layers"
quietly gracedr randomize, study("`layers'") id(P1) sex(male) age(30)
foreach name in participants codes audit state {
    confirm file "`layers'/`name'.bak.zip"
}
assert_only_zips "`layers'"
encuse using "`layers'/participants.bak.zip", clear
assert _N == 0
encuse using "`layers'/participants.zip", clear
assert _N == 1
clear
python:
os.environ["GRACEDR_PASSPHRASE"] = other
end
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"encuse using "`layers'/participants.bak.zip", clear"')
python:
os.environ["GRACEDR_PASSPHRASE"] = canary
end

gracedr setup, ///
    study("`scratch'/downgrade") ///
    n(4) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(12) ///
    encrypt
local downgrade "`scratch'/downgrade"
quietly erase "`downgrade'/design.zip"
expect_failure, ///
    rc(601) ///
    message("no study found") ///
    command(`"gracedr randomize, study("`downgrade'") id(P1) sex(male) age(30)"')
make_data 3
_gracedr_study write, study("`downgrade'") name(participants)
clear
confirm file "`downgrade'/participants.zip"
assert_only_zips "`downgrade'"
local plain_files : dir "`downgrade'" files "*.dta"
assert `: word count `plain_files'' == 0
_gracedr_study extension, study("`downgrade'")
assert "`r(extension)'" == "zip"
assert r(encrypted) == 1

quietly erase "`layers'/participants.zip"
expect_failure, ///
    rc(601) ///
    message("participants.zip is missing") ///
    command(`"gracedr status, study("`layers'")"')
write_text_file "`layers'/participants.zip" "not a zip file"
expect_failure, ///
    rc(610) ///
    message("not an encrypted dataset archive") ///
    command(`"gracedr status, study("`layers'")"')

python:
del os.environ["GRACEDR_PASSPHRASE"]
gracedr_zip.session_passphrases.clear()
prompts = []


def fake_prompt(confirm):
    prompts.append(confirm)
    return canary.encode("utf8")


gracedr_zip.prompt_passphrase = fake_prompt
end
gracedr setup, ///
    study("`scratch'/prompted") ///
    n(4) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(9) ///
    encrypt
python:
Macro.setLocal("setup_prompts", str(len(prompts)))
end
assert `setup_prompts' == 1
gracedr status, study("`scratch'/prompted")
gracedr audit, study("`scratch'/prompted")
python:
Macro.setLocal("read_prompts", str(len(prompts)))
key = gracedr_zip.session_key(os.path.join(Macro.getLocal("scratch"), "prompted", "x.zip"))
gracedr_zip.session_passphrases[key] = b"wrong"
end
assert `read_prompts' == 1
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"gracedr status, study("`scratch'/prompted")"')
python:
Macro.setLocal("cache_cleared", str(int(key not in gracedr_zip.session_passphrases)))
end
assert `cache_cleared' == 1
gracedr status, study("`scratch'/prompted")
python:
Macro.setLocal("retry_prompts", str(len(prompts)))
end
assert `retry_prompts' == 2
gracedr setup, ///
    study("`scratch'/second") ///
    n(4) ///
    arms(A B) ///
    `design' ///
    codes("`scratch'/codes.csv") ///
    seed(13) ///
    encrypt
python:
Macro.setLocal("second_prompts", str(len(prompts)))
Macro.setLocal("second_confirm", str(int(prompts[-1])))
os.environ["GRACEDR_PASSPHRASE"] = other
end
assert `second_prompts' == 3
assert `second_confirm' == 1
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"gracedr status, study("`scratch'/second")"')
python:
del os.environ["GRACEDR_PASSPHRASE"]
Macro.setLocal("kept_after_env", str(len(gracedr_zip.session_passphrases)))
gracedr_zip.session_passphrases.clear()
end
assert `kept_after_env' == 2
make_data 3
encsave using "`scratch'/standalone one.zip"
encsave using "`scratch'/standalone two.zip"
python:
Macro.setLocal("standalone_prompts", str(len(prompts)))
Macro.setLocal("standalone_cached", str(len(gracedr_zip.session_passphrases)))
end
assert `standalone_prompts' == 5
assert `standalone_cached' == 0
assert_no_new_files `"`before'"'

remove_folder "`scratch'"
display "certify_encrypted: all checks passed"
