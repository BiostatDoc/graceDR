version 19
clear all
local stata_dir : environment GRACEDR_STATA_DIR
assert !missing("`stata_dir'")
adopath ++ "`stata_dir'/ado"

tempname offset_scalar
local fetch "from sfi import Scalar; from datetime import datetime"
local offset_seconds "datetime.now().astimezone().utcoffset().total_seconds()"
python: `fetch'; Scalar.setValue("`offset_scalar'", `offset_seconds')
local offset_minutes = scalar(`offset_scalar') / 60
assert !missing(`offset_minutes')

_gracedr_utc
local utc = r(time)
local local_now = clock("`c(current_date)' `c(current_time)'", "DMYhms")
local difference = `utc' - `local_now'
local expected = (0 - `offset_minutes') * 60 * 1000
assert abs(`difference' - `expected') < 120000

_gracedr_utc
local later = r(time)
assert inrange(`later', `utc', `utc' + 60000)

display "certify_utc: all checks passed"
