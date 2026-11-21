*! version 1.0.0  15nov2026
program define _gracedr_codes, rclass
    version 19
    syntax using/, ARMS(string asis)
    local arms : list clean arms
    if fileexists(`"`macval(using)'"') == 0 {
        display as error `"gracedr: codes file `macval(using)' not found"'
        exit 601
    }
    local is_stata = substr(strlower(`"`macval(using)'"'), -4, 4) == ".dta"
    if `is_stata' == 1 {
        quietly use `"`macval(using)'"', clear
    }
    else {
        quietly import delimited using `"`macval(using)'"', varnames(1) stringcols(_all) clear
    }
    local absent ""
    foreach column in code arm {
        capture confirm variable `column'
        if _rc == 0 {
            continue
        }
        local absent "`macval(absent)' `column'"
    }
    if !missing("`macval(absent)'") {
        display as error "gracedr: the codes file is missing column(s):`macval(absent)'"
        exit 198
    }
    keep code arm
    foreach column in code arm {
        capture confirm string variable `column'
        if _rc == 0 {
            continue
        }
        quietly count if !missing(`column') & `column' == floor(`column')
        local whole = r(N) == _N
        if `whole' == 0 {
            display as error "gracedr: `column' must be text or whole numbers"
            exit 198
        }
        quietly tostring `column', replace format(%21.0f)
    }
    foreach column in code arm {
        quietly count if inrange(strlen(`column'), 245, 1e15)
        local fits = r(N) == 0
        if `fits' == 0 {
            display as error "gracedr: `column' values must be at most 244 bytes"
            exit 198
        }
        quietly generate str244 `column'_text = `column'
        quietly drop `column'
        quietly rename `column'_text `column'
        quietly replace `column' = ustrtrim(`column')
    }
    if _N == 0 {
        display as error "gracedr: the codes file has no rows"
        exit 198
    }
    quietly count if missing(code)
    local none_empty = r(N) == 0
    if `none_empty' == 0 {
        display as error "gracedr: every code must be non-empty"
        exit 198
    }
    tempvar copies
    quietly duplicates tag code, generate(`copies')
    quietly count if inrange(`copies', 1, 1e15)
    local repeated = r(N) == 0
    if `macval(repeated)' == 0 {
        display as error "gracedr: codes must be unique"
        exit 198
    }
    quietly count if missing(arm)
    local none_blank = r(N) == 0
    if `none_blank' == 0 {
        display as error "gracedr: unknown arm(s) in the codes file: (blank)"
        exit 198
    }
    tempvar known_arm
    quietly generate byte `known_arm' = 0
    foreach label of local arms {
        quietly replace `known_arm' = 1 if arm == `"`macval(label)'"'
    }
    quietly count if `known_arm' == 0
    local unknown_rows = r(N)
    if inrange(`unknown_rows', 1, 1e15) {
        mata: gracedr_rows = select(st_sdata(., "arm"), st_data(., "`known_arm'") :== 0)
        mata: gracedr_unknown = uniqrows(gracedr_rows)
        mata: gracedr_no_space = strpos(gracedr_unknown, " ") :== 0
        mata: gracedr_length = strlen(gracedr_unknown)
        mata: gracedr_plain = substr(gracedr_unknown, 1, gracedr_length :* gracedr_no_space)
        mata: gracedr_spaced = char(34) :+ gracedr_unknown :+ char(34)
        mata: gracedr_keep = (gracedr_length :+ 2) :* (1 :- gracedr_no_space)
        mata: gracedr_shown = gracedr_plain :+ substr(gracedr_spaced, 1, gracedr_keep)
        mata: st_local("unknown", invtokens(gracedr_shown'))
        display as error `"gracedr: unknown arm(s) in the codes file: `macval(unknown)'"'
        exit 198
    }
    quietly generate str8 status = "unused"
    quietly generate str244 id = ""
    display as text "gracedr: `=_N' treatment codes are valid."
    foreach arm of local arms {
        quietly count if arm == "`arm'"
        display as text "  arm `arm': `r(N)' codes"
    }
    return scalar n = _N
end
