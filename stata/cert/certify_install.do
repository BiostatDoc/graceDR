version 19
clear all
set linesize 255
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
local original_plus = c(sysdir_plus)
local start_dir = c(pwd)

adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"
_gracedr_study folder, study("`c(tmpdir)'")
local scratch "`r(folder)'/gracedr cert install"
remove_folder "`scratch'"
quietly mkdir "`scratch'"
quietly mkdir "`scratch'/plus"
quietly mkdir "`scratch'/work"
adopath - "`stata_dir'/ado"
clear all

program define check_package_files
    args stata_dir
    local package_lines ""
    local sources ""
    tempname handle
    file open `handle' using "`stata_dir'/gracedr.pkg", read text
    file read `handle' line
    while r(eof) == 0 {
        local package_lines "`package_lines' [`line']"
        local kind = substr("`line'", 1, 2)
        if "`kind'" == "f " {
            local source = substr("`line'", 3, .)
            local sources `"`sources' "`source'""'
        }
        file read `handle' line
    }
    file close `handle'
    assert inrange(strpos("`package_lines'", "[v 3]"), 1, 1e9)
    assert regexm("`package_lines'", "d Distribution-Date: 20[0-9][0-9][01][0-9][0-3][0-9]")
    local expected_count = 0
    foreach folder in ado help data {
        local files : dir "`stata_dir'/`folder'" files "*"
        foreach file of local files {
            local entry "[f `folder'/`file']"
            assert inrange(strpos("`package_lines'", "`entry'"), 1, 1e9)
            local expected_count = `expected_count' + 1
        }
    }
    local listed : word count `sources'
    assert `listed' == `expected_count'
    foreach source of local sources {
        confirm file "`stata_dir'/`source'"
    }
end

program define check_installed_under
    args stata_dir plus_folder
    foreach folder in ado help {
        local files : dir "`stata_dir'/`folder'" files "*"
        foreach file of local files {
            quietly findfile `file'
            local found = lower(subinstr("`r(fn)'", char(92), "/", .))
            assert strpos("`found'", "`plus_folder'") == 1
        }
    }
    foreach file in example_codes.csv example_codes.dta example_participants.dta {
        capture quietly findfile `file'
        local in_plus = _rc == 0
        assert `in_plus' == 0
    }
end

program define run_install_checks
    args stata_dir scratch
    check_package_files "`stata_dir'"
    sysdir set PLUS "`scratch'/plus"
    net install gracedr, from("`stata_dir'") replace
    local plus_folder = lower("`scratch'/plus")
    check_installed_under "`stata_dir'" "`plus_folder'"

    net install gracedr, from("`stata_dir'") replace
    check_installed_under "`stata_dir'" "`plus_folder'"

    mata: chdir("`scratch'/work")
    net get gracedr, from("`stata_dir'")
    foreach file in example_codes.csv example_codes.dta example_participants.dta {
        confirm file "`file'"
    }
    net get gracedr, from("`stata_dir'") replace
    quietly findfile gracedr.ado
    local installed = lower(subinstr("`r(fn)'", char(92), "/", .))
    assert strpos("`installed'", "`plus_folder'") == 1

    gracedr codes using "example_codes.csv", arms(A B)
    assert _N == 200
    clear
    gracedr setup, ///
        study("`scratch'/study") ///
        n(20) ///
        arms(A B) ///
        categorical(sex: male female) ///
        continuous(age) ///
        codes("example_codes.csv") ///
        seed(2026)
    gracedr randomize, study("`scratch'/study") id(P001) sex(male) age(54)
    assert inlist("`r(arm)'", "A", "B")
    local first_arm "`r(arm)'"
    gracedr randomize, study("`scratch'/study") id(P002) sex(female) age(61)
    gracedr status, study("`scratch'/study")
    assert r(n_randomized) == 2
    gracedr audit, study("`scratch'/study")
    assert r(rows) == 3
    gracedr replay, study("`scratch'/study") id(P001)
    assert r(match) == 1
    local other_arm = cond("`first_arm'" == "A", "B", "A")
    gracedr override, ///
        study("`scratch'/study") ///
        id(P001) ///
        arm(`other_arm') ///
        reason("install check")
    gracedr replay, study("`scratch'/study") id(P001)
    assert r(match) == 1
    gracedr simulate, ///
        study("`scratch'/study") ///
        methods(mmsb srs blocks minimization msb) ///
        nsims(2) ///
        seed(3) ///
        saving("`scratch'/simulated.dta")
    assert r(nsims) == 2
    confirm file "`scratch'/simulated.dta"
    gracedr
end

capture noisily run_install_checks "`stata_dir'" "`scratch'"
local failure = _rc

mata: chdir("`start_dir'")
sysdir set PLUS "`original_plus'"
adopath ++ "`stata_dir'/ado"
do "`stata_dir'/cert/helpers.do"
remove_folder "`scratch'"
adopath - "`stata_dir'/ado"
if `failure' == 0 {
    display "certify_install: all checks passed"
}
else {
    exit `failure'
}
