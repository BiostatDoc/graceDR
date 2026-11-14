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

program define fill_participants
    syntax , STUDY(string) ARMS(string) [SEXES(string) AGES(string)]
    _gracedr_study empty, name(participants) study(`"`study'"')
    local count : word count `arms'
    quietly set obs `count'
    forvalues position = 1/`count' {
        quietly replace seq = `position' in `position'
        quietly replace id = "P`position'" in `position'
        local label : word `position' of `arms'
        local label = subinstr("`label'", "_", " ", .)
        quietly replace arm = `"`macval(label)'"' in `position'
        if !missing("`sexes'") {
            local level = word("`sexes'", `position')
            if "`level'" == "." {
                local level ""
            }
            quietly replace sex = "`level'" in `position'
        }
        if !missing("`ages'") {
            local age = word("`ages'", `position')
            quietly replace age = `age' in `position'
        }
    }
    _gracedr_study write, study(`"`study'"') name(participants)
end

program define check_probs
    args expected
    local count : word count `expected'
    assert wordcount("`r(probs)'") == `count'
    local total = 0
    forvalues position = 1/`count' {
        local actual = real(word("`r(probs)'", `position'))
        local wanted = real(word("`expected'", `position'))
        close_to `actual' `wanted' 0.000000001
        local total = `total' + `actual'
    }
    close_to `total' 1 0.000000001
end

program define start_participants
    syntax , STUDY(string) ARMS(string)
    _gracedr_study empty, name(participants) study(`"`study'"')
    local count : word count `arms'
    quietly set obs `count'
    forvalues position = 1/`count' {
        local label : word `position' of `arms'
        local label = subinstr("`label'", "_", " ", .)
        quietly replace seq = `position' in `position'
        quietly replace id = "P`position'" in `position'
        quietly replace arm = `"`macval(label)'"' in `position'
    }
end

program define set_column
    syntax , NAME(string) VALUES(string)
    local count : word count `values'
    capture confirm string variable `name'
    local is_text = _rc == 0
    forvalues position = 1/`count' {
        local value : word `position' of `values'
        if "`value'" == "." {
            local value ""
        }
        if `is_text' == 1 {
            quietly replace `name' = "`value'" in `position'
        }
        else if !missing("`value'") {
            quietly replace `name' = `value' in `position'
        }
    }
end

program define finish_participants
    syntax , STUDY(string)
    _gracedr_study write, study(`"`study'"') name(participants)
end

program define write_codes_for
    args file per_arm
    tempname handle
    file open `handle' using "`file'", write text replace
    file write `handle' "code,arm" _n
    forvalues position = 1/`per_arm' {
        local number = 100 + `position'
        file write `handle' "A`number',A" _n
        file write `handle' "B`number',B" _n
    }
    file close `handle'
end

program define read_dataset
    args study name
    _gracedr_study read, study(`"`study'"') name(`name')
end
