version 19
clear all
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"

local home "/Users/pat"

_gracedr_home, path("~/Library/Application Support/Stata/plus/py") home("`home'")
assert `"`r(path)'"' == "/Users/pat/Library/Application Support/Stata/plus/py"

_gracedr_home, path("~") home("`home'")
assert `"`r(path)'"' == "/Users/pat"

_gracedr_home, path("~lee/py") home("`home'")
assert `"`r(path)'"' == "~lee/py"

_gracedr_home, path("C:/Users/pat/plus/py") home("`home'")
assert `"`r(path)'"' == "C:/Users/pat/plus/py"

_gracedr_home, path("/data/a~b") home("`home'")
assert `"`r(path)'"' == "/data/a~b"

_gracedr_home, path("~/py") home("C:\Users\pat")
assert `"`r(path)'"' == "C:/Users/pat/py"

_gracedr_home, path("~/py") home("")
local fallback `"`r(path)'"'
local environment_home : environment HOME
if `"`environment_home'"' == "" {
    assert `"`fallback'"' == "~/py"
}
else {
    assert strpos(`"`fallback'"', "~") == 0
}

display "certify_home: all checks passed"
