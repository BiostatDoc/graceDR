program define encuse
    version 19
    syntax using/ [, CLEAR]
    local has_extension = lower(substr(`"`macval(using)'"', -4, 4)) == ".zip"
    if `has_extension' == 0 {
        local using `"`macval(using)'.zip"'
    }
    if "`clear'" == "" & c(changed) == 1 {
        error 4
    }
    quietly findfile encuse.ado
    local backslash = char(92)
    local ado_file = subinstr(`"`r(fn)'"', "`backslash'", "/", .)
    local folder = substr("`ado_file'", 1, strlen("`ado_file'") - strlen("encuse.ado") - 1)
    local sibling "`folder'/../python"
    local archive `"`macval(using)'"'
    tempfile plain
    python: import sys; sys.path[:0] = [r"`folder'", r"`sibling'"]
    capture noisily python: import gracedr_zip; gracedr_zip.run_from_stata("encuse", "load")
    local python_rc = _rc
    if "`zipcode'" == "" {
        capture erase `"`plain'"'
        exit `python_rc'
    }
    local succeeded = `zipcode' == 0
    if `succeeded' == 0 {
        capture erase `"`plain'"'
        forvalues position = 1/`ziplines' {
            display as error `"`macval(zipline`position')'"'
        }
        exit `zipcode'
    }
    capture quietly describe using `"`plain'"'
    local is_dataset = _rc == 0
    if `is_dataset' == 0 {
        capture erase `"`plain'"'
        display as error `"encuse: `macval(archive)' does not hold a Stata dataset"'
        exit 610
    }
    capture noisily use `"`plain'"', `clear'
    local use_rc = _rc
    capture erase `"`plain'"'
    exit `use_rc'
end
