program define _gracedr_generate
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known load check stream
    local is_known : list subcommand in known
    if `is_known' == 0 | missing(`"`macval(subcommand)'"') {
        display as error `"gracedr: unknown generate subcommand `macval(subcommand)'"'
        exit 198
    }
    _gracedr_generate_`subcommand' `macval(0)'
end

program define _gracedr_generate_load
    version 19
    capture mata: gd_generate_version()
    local ready = _rc == 0
    if `ready' == 0 {
        quietly findfile _gracedr_generate.mata
        quietly do "`r(fn)'"
    }
end

program define _gracedr_generate_pairs, rclass
    syntax , VARNAMES(string) OPTION(string) [TEXT(string)]
    local remaining `"`macval(text)'"'
    local seen ""
    while !missing(ustrtrim(`"`macval(remaining)'"')) {
        gettoken piece remaining : remaining, parse("|")
        if `"`macval(piece)'"' == "|" {
            continue
        }
        local colon = strpos(`"`macval(piece)'"', ":")
        local name = ustrtrim(substr(`"`macval(piece)'"', 1, `colon' - 1))
        local numbers = ustrtrim(substr(`"`macval(piece)'"', `colon' + 1, .))
        if `colon' == 0 | missing(`"`macval(numbers)'"') {
            display as error "gracedr: `option'() must look like name: number number"
            exit 198
        }
        foreach value of local numbers {
            if missing(real(`"`macval(value)'"')) {
                display as error "gracedr: `option'() must look like name: number number"
                exit 198
            }
        }
        local position : list posof `"`macval(name)'"' in varnames
        if `position' == 0 {
            display as error `"gracedr: `option'() names an unknown balance variable "' ///
                `"`macval(name)'"'
            exit 198
        }
        local again : list posof `"`macval(name)'"' in seen
        if inrange(`again', 1, 1e9) {
            display as error `"gracedr: `option'() names `macval(name)' more than once"'
            exit 198
        }
        local seen `"`seen' `macval(name)'"'
        return local spec`position' "`numbers'"
    }
end

program define _gracedr_generate_values, rclass
    syntax , NAME(string) TYPE(string) COUNT(integer) OPTION(string) [NUMBERS(string)]
    if missing("`numbers'") {
        if "`type'" == "categorical" {
            local share = strtrim(string(1 / `count', "%21.17g"))
            local numbers ""
            forvalues level = 1/`count' {
                local numbers "`numbers' `share'"
            }
        }
        else {
            local numbers "0 1"
        }
    }
    local numbers = strtrim("`numbers'")
    if "`type'" == "categorical" {
        local given : word count `numbers'
        local total = 0
        local negative = 0
        foreach value of local numbers {
            local total = `total' + real("`value'")
            local below = 0 - real("`value'")
            local negative = `negative' | inrange(`below', 0.00000000000000000001, 1e300)
        }
        local close = inrange(abs(`total' - 1), 0, 0.00000001)
        local valid = `given' == `count' & `negative' == 0 & `close' == 1
        if `valid' == 0 {
            display as error "gracedr: `option'() for `name' needs `count' probabilities " ///
                "that are not negative and add up to 1"
            exit 198
        }
    }
    else {
        local given : word count `numbers'
        local spread = real(word("`numbers'", 2))
        local valid = `given' == 2 & inrange(`spread', 0.0000000000000001, 1e300)
        if `valid' == 0 {
            display as error "gracedr: `option'() for `name' needs a mean and an sd " ///
                "greater than 0"
            exit 198
        }
    }
    return local numbers "`numbers'"
end

program define _gracedr_generate_check, rclass
    syntax ,                    ///
        VARNAMES(string)        ///
        VARTYPES(string)        ///
        LEVELCOUNTS(string)     ///
        [                       ///
        GENERATOR(string)       ///
        PROBS(string)           ///
        MEANSD(string)          ///
        DRIFTTO(string)         ///
        ]
    if missing("`generator'") {
        local generator iid
    }
    if !inlist("`generator'", "iid", "drift") {
        display as error "gracedr: generator() must be iid or drift"
        exit 198
    }
    if "`generator'" == "iid" & !missing(`"`macval(driftto)'"') {
        display as error "gracedr: driftto() needs generator(drift)"
        exit 198
    }
    if "`generator'" == "drift" & missing(`"`macval(driftto)'"') {
        display as error "gracedr: generator(drift) needs driftto()"
        exit 198
    }
    local variable_count : word count `varnames'
    foreach option in probs meansd driftto {
        _gracedr_generate_pairs, varnames(`varnames') option(`option') text(`"`macval(`option')'"')
        forvalues position = 1/`variable_count' {
            local `option'`position' "`r(spec`position')'"
        }
    }
    forvalues position = 1/`variable_count' {
        local name : word `position' of `varnames'
        local type : word `position' of `vartypes'
        local count : word `position' of `levelcounts'
        local wrong = "`type'" == "categorical" & !missing("`meansd`position''")
        if `wrong' == 1 {
            display as error "gracedr: meansd() applies only to continuous variables (`name')"
            exit 198
        }
        local wrong = "`type'" == "continuous" & !missing("`probs`position''")
        if `wrong' == 1 {
            display as error "gracedr: probs() applies only to categorical variables (`name')"
            exit 198
        }
        local given "`probs`position''"
        local given_option probs
        if "`type'" == "continuous" {
            local given "`meansd`position''"
            local given_option meansd
        }
        _gracedr_generate_values, ///
            name(`name') ///
            type(`type') ///
            count(`count') ///
            option(`given_option') ///
            numbers(`given')
        return local start`position' "`r(numbers)'"
        local ending "`r(numbers)'"
        if !missing("`driftto`position''") {
            _gracedr_generate_values, ///
                name(`name') ///
                type(`type') ///
                count(`count') ///
                option(driftto) ///
                numbers(`driftto`position'')
            local ending "`r(numbers)'"
        }
        return local end`position' "`ending'"
    }
end

program define _gracedr_generate_stream
    syntax ,                    ///
        STUDY(string)           ///
        N(integer)              ///
        [                       ///
        GENERATOR(string)       ///
        PROBS(string)           ///
        MEANSD(string)          ///
        DRIFTTO(string)         ///
        ]
    _gracedr_generate load
    preserve
    _gracedr_settings load, study(`"`macval(study)'"') designonly
    local variable_count = r(nvars)
    local d_n "`r(n)'"
    mata: st_local("varnames", st_global("r(varnames)"))
    mata: st_local("vartypes", st_global("r(vartypes)"))
    local counts ""
    forvalues position = 1/`variable_count' {
        mata: st_local("levels`position'", st_global("r(levels`position')"))
        local counts "`counts' `: word count `levels`position'''"
    }
    _gracedr_generate check, ///
        varnames(`varnames') ///
        vartypes(`vartypes') ///
        levelcounts(`counts') ///
        generator(`generator') ///
        probs(`"`macval(probs)'"') ///
        meansd(`"`macval(meansd)'"') ///
        driftto(`"`macval(driftto)'"')
    forvalues position = 1/`variable_count' {
        local g_start`position' "`r(start`position')'"
        local g_end`position' "`r(end`position')'"
    }
    local g_count = `n'
    clear
    quietly set obs `n'
    foreach name of local varnames {
        local position : list posof "`name'" in varnames
        local type : word `position' of `vartypes'
        if "`type'" == "categorical" {
            quietly generate str244 `name' = ""
        }
        else {
            quietly generate double `name' = .
        }
    }
    mata: gd_stream_to_data()
    restore, not
end
