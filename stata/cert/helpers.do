program define expect_failure
    syntax , MESSAGE(string) COMMAND(string) [RC(integer -1)]
    tempfile capture_log
    quietly log using "`capture_log'", text replace name(expect)
    capture noisily `macval(command)'
    local actual = _rc
    quietly log close expect
    if `rc' == -1 {
        assert !missing(`actual') & `actual' != 0
    }
    else {
        assert `actual' == `rc'
    }
    tempname handle
    local found = 0
    file open `handle' using "`capture_log'", read text
    file read `handle' row
    while r(eof) == 0 {
        local position = strpos(`"`macval(row)'"', `"`macval(message)'"')
        if !missing(`position') & `position' > 0 {
            local found = 1
        }
        file read `handle' row
    }
    file close `handle'
    assert `found' == 1
end

program define make_data
    args nobs
    clear
    quietly set obs `nobs'
    generate double x = _n * 10
    generate str10 label = "row" + string(_n)
end

program define remove_folder
    args folder
    _gracedr_study folder, study(`"`macval(folder)'"')
    if r(found) == 1 {
        local subfolders : dir "`macval(folder)'" dirs "*"
        foreach subfolder of local subfolders {
            remove_folder "`macval(folder)'/`macval(subfolder)'"
        }
        local files : dir "`macval(folder)'" files "*"
        foreach file of local files {
            quietly erase "`macval(folder)'/`macval(file)'"
        }
        quietly rmdir "`macval(folder)'"
    }
end

program define get_setting, rclass
    args folder name
    _gracedr_study setting, study(`"`folder'"') name(`name')
    return local value `"`r(value)'"'
end

program define write_codes_csv
    args file
    tempname handle
    file open `handle' using "`file'", write text replace
    file write `handle' "code,arm" _n
    file write `handle' "007,A" _n
    file write `handle' "008,B" _n
    file write `handle' " 009 , A " _n
    file write `handle' "0010,B" _n
    file close `handle'
end

program define write_text_file
    args file first_line second_line third_line
    tempname handle
    file open `handle' using "`file'", write text replace
    foreach line in "`first_line'" "`second_line'" "`third_line'" {
        if !missing("`line'") {
            file write `handle' "`line'" _n
        }
    }
    file close `handle'
end

program define close_to
    args actual expected tolerance
    assert !missing(`actual')
    assert inrange(`actual', `expected' - `tolerance', `expected' + `tolerance')
end
