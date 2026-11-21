*! version 1.0.0  21nov2026
program define _gracedr_home, rclass
    version 19
    syntax, path(string) [home(string)]
    if `"`home'"' == "" {
        local home : environment HOME
    }
    local backslash = char(92)
    local home = subinstr(`"`home'"', "`backslash'", "/", .)
    local starts_home = substr(`"`path'"', 1, 1) == "~"
    local only_home = `"`path'"' == "~"
    local home_slash = substr(`"`path'"', 1, 2) == "~/"
    local expandable = `starts_home' & (`only_home' | `home_slash')
    local has_home = !missing(`"`home'"')
    if `expandable' == 1 & `has_home' == 1 {
        local path = `"`home'"' + substr(`"`path'"', 2, .)
    }
    return local path `"`path'"'
end
