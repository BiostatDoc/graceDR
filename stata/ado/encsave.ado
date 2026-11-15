program define encsave
    version 19
    syntax using/ [, REPLACE]
    local has_extension = lower(substr(`"`macval(using)'"', -4, 4)) == ".zip"
    if `has_extension' == 0 {
        local using `"`macval(using)'.zip"'
    }
    if "`replace'" == "" {
        capture confirm new file `"`macval(using)'"'
        if _rc == 602 {
            display as error `"encsave: file `macval(using)' already exists"'
            exit 602
        }
    }
    _gracedr_zip_folder
    local module_folder `r(folder)'
    local archive `"`macval(using)'"'
    tempfile plain
    preserve
    quietly save `"`plain'"'
    restore
    python: import sys; sys.path[:0] = [r"`module_folder'"]
    capture noisily python: import gracedr_zip; gracedr_zip.run_from_stata("encsave", "save")
    local python_rc = _rc
    capture erase `"`plain'"'
    if "`zipcode'" == "" {
        exit `python_rc'
    }
    if `zipcode' == 0 {
        exit
    }
    forvalues position = 1/`ziplines' {
        display as error `"`macval(zipline`position')'"'
    }
    exit `zipcode'
end
