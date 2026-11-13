version 19
clear all
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"
findfile gracedr.ado
assert strpos(subinstr("`r(fn)'", "\", "/", .), "`stata_dir'/ado/") == 1
gracedr
display "certify_all: all checks passed"
