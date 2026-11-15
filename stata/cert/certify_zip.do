version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"

program define assert_no_new_files
    args before
    local after : dir "`c(tmpdir)'" files "*"
    foreach file of local after {
        assert `: list file in before'
    }
end

program define assert_unchanged
    args original
    cf _all using "`original'"
end

_gracedr_study folder, study("`c(tmpdir)'")
local root "`r(folder)'/gracedr cert zip"
remove_folder "`root'"
mkdir "`root'"

python:
import os
from sfi import Macro
import sys

canary = "".join(["Canary", "Phrase", "4471"])
other = "".join(["Other", "Phrase", "9082"])
os.environ["GRACEDR_PASSPHRASE"] = canary
end
local before : dir "`c(tmpdir)'" files "*"

make_data 25
label variable x "Ten times row"
generate byte flag = 1 + mod(_n, 2)
label define flag_label 1 "one" 2 "two"
label values flag flag_label
notes: made up note
local original "`root'/original.dta"
quietly save "`original'", replace
local filename_before "`c(filename)'"

local archive "`root'/my data.zip"
encsave using "`archive'"
confirm file "`archive'"
assert_no_new_files `"`before'"'
assert_unchanged "`original'"
assert "`c(filename)'" == "`filename_before'"

clear
encuse using "`archive'"
assert_no_new_files `"`before'"'
assert_unchanged "`original'"
assert "`: variable label x'" == "Ten times row"
assert "`: value label flag'" == "flag_label"
local note : char _dta[note1]
assert `"`macval(note)'"' == "made up note"

python:
import pyzipper

with pyzipper.AESZipFile(os.path.join(Macro.getLocal("root"), "my data.zip")) as zf:
    members = zf.infolist()
    extra = members[0].extra
    header = int.from_bytes(extra[0:2], "little")
    strength = extra[8]
    Macro.setLocal("member_count", str(len(members)))
    Macro.setLocal("encrypted", str(members[0].flag_bits & 1))
    Macro.setLocal("header", str(header))
    Macro.setLocal("strength", str(strength))
end
assert `member_count' == 1
assert `encrypted' == 1
assert `header' == 39169
assert `strength' == 3

encsave using "`root'/no extension"
confirm file "`root'/no extension.zip"
clear
encuse using "`root'/no extension", clear
assert_unchanged "`original'"

make_data 4
expect_failure, ///
    rc(602) ///
    message("already exists") ///
    command(`"encsave using "`archive'""')
assert_no_new_files `"`before'"'
encsave using "`archive'", replace
clear
encuse using "`archive'"
assert _N == 4
assert_no_new_files `"`before'"'

make_data 25
expect_failure, ///
    rc(603) ///
    message("cannot write") ///
    command(`"encsave using "`root'/no such folder/data.zip""')
assert_no_new_files `"`before'"'

quietly save "`root'/in_memory.dta", replace
python:
os.environ["GRACEDR_PASSPHRASE"] = other
end
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"encuse using "`archive'", clear"')
assert_no_new_files `"`before'"'
assert_unchanged "`root'/in_memory.dta"
expect_failure, ///
    rc(499) ///
    message("wrong password") ///
    command(`"encuse using "`archive'""')
assert_no_new_files `"`before'"'
assert_unchanged "`root'/in_memory.dta"
python:
os.environ["GRACEDR_PASSPHRASE"] = canary
end

expect_failure, ///
    rc(601) ///
    message("not found") ///
    command(`"encuse using "`root'/missing.zip", clear"')
write_text_file "`root'/plain.zip" "not a zip file"
expect_failure, ///
    rc(610) ///
    message("not an encrypted dataset archive") ///
    command(`"encuse using "`root'/plain.zip", clear"')
write_text_file "`root'/garbage.txt" "not a stata dataset"
python:
import zipfile

with zipfile.ZipFile(os.path.join(Macro.getLocal("root"), "unencrypted.zip"), "w") as zf:
    zf.writestr("data.dta", b"made up")
import gracedr_zip

gracedr_zip.save_archive(
    os.path.join(Macro.getLocal("root"), "garbage.txt"),
    os.path.join(Macro.getLocal("root"), "garbage.zip"),
    canary.encode("utf8"),
)
end
expect_failure, ///
    rc(610) ///
    message("not an encrypted dataset archive") ///
    command(`"encuse using "`root'/unencrypted.zip", clear"')
capture encuse using "`root'/garbage.zip", clear
assert !missing(_rc) & _rc != 0
assert_no_new_files `"`before'"'
assert_unchanged "`root'/in_memory.dta"

quietly log using "`root'/trace.log", text replace name(trace)
set trace on
encsave using "`root'/traced.zip"
encuse using "`root'/traced.zip", clear
set trace off
macro list
quietly log close trace
python:
with open(os.path.join(Macro.getLocal("root"), "trace.log"), "r", -1, "utf8") as handle:
    text = handle.read()
Macro.setLocal("log_size", str(len(text)))
Macro.setLocal("leaked", str(int(canary in text)))
end
assert inrange(`log_size', 1001, 100000000)
assert `leaked' == 0
assert_no_new_files `"`before'"'

python:
sys.modules["pyzipper"] = None
end
make_data 3
expect_failure, ///
    rc(199) ///
    message("pyzipper is not installed") ///
    command(`"encsave using "`root'/blocked.zip""')
expect_failure, ///
    rc(199) ///
    message("pip install pyzipper") ///
    command(`"encuse using "`archive'", clear"')
expect_failure, ///
    rc(199) ///
    message("set python_exec") ///
    command(`"encuse using "`archive'", clear"')
assert_no_new_files `"`before'"'
capture confirm file "`root'/blocked.zip"
assert !missing(_rc) & _rc != 0
python:
sys.modules.pop("pyzipper")
end

remove_folder "`root'"
display "certify_zip: all checks passed"
