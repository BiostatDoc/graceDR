*! version 1.0.0  15nov2026
program define _gracedr_values
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known parse
    local is_known : list subcommand in known
    if `is_known' == 0 | missing("`subcommand'") {
        display as error `"gracedr: unknown values subcommand `subcommand'"'
        exit 198
    }
    _gracedr_values_`subcommand' `macval(0)'
end

program define _gracedr_values_malformed
    args text
    display as error `"gracedr: could not read the options: `macval(text)'"'
    exit 198
end

program define _gracedr_values_split, rclass
    syntax , [OPTIONS(string)]
    local remaining = ustrtrim(`"`macval(options)'"')
    local count = 0
    local names ""
    while !missing(`"`macval(remaining)'"') {
        local open = strpos(`"`macval(remaining)'"', "(")
        if `open' == 0 {
            _gracedr_values_malformed `"`macval(options)'"'
        }
        local name = ustrtrim(substr(`"`macval(remaining)'"', 1, `open' - 1))
        local words : word count `macval(name)'
        capture confirm name `macval(name)'
        local plain_name = `words' == 1 & _rc == 0
        if `plain_name' == 0 {
            _gracedr_values_malformed `"`macval(options)'"'
        }
        local depth = 0
        local close = 0
        local position = `open'
        local limit = strlen(`"`macval(remaining)'"')
        while `close' == 0 & inrange(`position', 1, `limit') {
            local is_open = substr(`"`macval(remaining)'"', `position', 1) == "("
            local is_close = substr(`"`macval(remaining)'"', `position', 1) == ")"
            local depth = `depth' + `is_open' - `is_close'
            if `is_close' == 1 & `depth' == 0 {
                local close = `position'
            }
            local position = `position' + 1
        }
        if `close' == 0 {
            _gracedr_values_malformed `"`macval(options)'"'
        }
        local count = `count' + 1
        local names "`macval(names)' `macval(name)'"
        local content = ustrtrim(substr(`"`macval(remaining)'"', `open' + 1, `close' - `open' - 1))
        local quoted = substr(`"`macval(content)'"', 1, 1) == char(34)
        local quoted = `quoted' & substr(`"`macval(content)'"', -1, 1) == char(34)
        if `quoted' == 1 & inrange(strlen(`"`macval(content)'"'), 2, 1e15) {
            local content = substr(`"`macval(content)'"', 2, strlen(`"`macval(content)'"') - 2)
        }
        local content`count' `"`macval(content)'"'
        local remaining = ustrtrim(substr(`"`macval(remaining)'"', `close' + 1, .))
    }
    return scalar count = `count'
    return local names = strtrim("`macval(names)'")
    forvalues position = 1/`count' {
        return local content`position' `"`macval(content`position')'"'
    }
end

program define _gracedr_values_parse, rclass
    syntax , STUDY(string) ID(string) [OPTIONS(string)]
    _gracedr_study check_id, id(`"`macval(id)'"')
    _gracedr_study setting, study(`"`macval(study)'"') name(nvars)
    local variable_count = real("`r(value)'")
    _gracedr_study setting, study(`"`macval(study)'"') name(varnames)
    mata: st_local("varnames", st_global("r(value)"))
    _gracedr_study setting, study(`"`macval(study)'"') name(vartypes)
    mata: st_local("vartypes", st_global("r(value)"))
    forvalues position = 1/`variable_count' {
        _gracedr_study setting, study(`"`macval(study)'"') name(levels`position')
        mata: st_local("levels`position'", st_global("r(value)"))
    }
    _gracedr_values_split, options(`"`macval(options)'"')
    local supplied_count = r(count)
    mata: st_local("supplied", st_global("r(names)"))
    forvalues position = 1/`supplied_count' {
        mata: st_local("content`position'", st_global("r(content`position')"))
    }
    forvalues position = 1/`supplied_count' {
        local name : word `position' of `macval(supplied)'
        local known : list name in varnames
        if `known' == 0 {
            foreach candidate of local varnames {
                local same_letters = strlower("`candidate'") == strlower("`macval(name)'")
                if `same_letters' == 1 {
                    display as error "gracedr: `macval(name)'() is not a balance variable. " ///
                        "Variable names are case-sensitive; use `candidate'()"
                    exit 198
                }
            }
        }
    }
    local absent : list varnames - supplied
    if !missing("`macval(absent)'") {
        display as error "gracedr: missing value(s) for: `macval(absent)'"
        exit 198
    }
    local unexpected ""
    local seen ""
    forvalues position = 1/`supplied_count' {
        local name : word `position' of `macval(supplied)'
        local known : list name in varnames
        local repeated : list name in seen
        if `known' == 0 | `macval(repeated)' == 1 {
            local unexpected : list unexpected | name
        }
        local seen "`seen' `macval(name)'"
    }
    if !missing("`unexpected'") {
        display as error "gracedr: unexpected or repeated value name(s): `unexpected'"
        exit 198
    }
    local missing_names ""
    forvalues position = 1/`variable_count' {
        local name : word `position' of `macval(varnames)'
        local type : word `position' of `macval(vartypes)'
        local where : list posof "`macval(name)'" in supplied
        local content `"`macval(content`where')'"'
        local absent_value = missing(`"`macval(content)'"') | `"`macval(content)'"' == "."
        if `absent_value' == 1 {
            local missing_names "`missing_names' `macval(name)'"
        }
        if "`type'" == "categorical" {
            local level = ustrlower(ustrtrim(`"`macval(content)'"'))
            if `absent_value' == 1 {
                local level ""
            }
            else {
                local found : list posof `"`macval(level)'"' in levels`position'
                if `macval(found)' == 0 {
                    local level_list `"`macval(levels`position')'"'
                    display as error `"gracedr: "`macval(level)'" is not a level "' ///
                        `"of `macval(name)'. Levels are `macval(level_list)'."'
                    exit 198
                }
            }
            return local value`position' `"`macval(level)'"'
        }
        else {
            if `absent_value' == 1 {
                return local value`position' "."
            }
            else {
                tempname exact
                scalar `exact' = real(`"`macval(content)'"')
                if missing(scalar(`exact')) {
                    display as error "gracedr: `macval(name)' must be a finite number"
                    exit 198
                }
                return local value`position' `"`macval(content)'"'
                return scalar number`position' = scalar(`exact')
            }
            if `absent_value' == 1 {
                return scalar number`position' = .
            }
        }
    }
    return local id `"`macval(id)'"'
    return scalar nvars = `variable_count'
    return local varnames `"`macval(varnames)'"'
    return local vartypes `"`macval(vartypes)'"'
    return local missingvars = strtrim("`missing_names'")
end
