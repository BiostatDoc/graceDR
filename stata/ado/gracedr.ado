*! version 1.0.0  15nov2026
program define gracedr
    version 19
    gettoken subcommand 0 : 0, parse(" ,")
    local known setup randomize status override audit replay simulate codes
    if missing("`subcommand'") {
        display as text "gracedr subcommands: `known'"
        display as text "Type help gracedr_setup or help gracedr_codes for details."
        exit
    }
    local is_known : list subcommand in known
    if `is_known' == 0 {
        display as error `"gracedr: unknown subcommand `subcommand'"'
        exit 198
    }
    capture findfile gracedr_`subcommand'.ado
    if _rc == 0 {
        gracedr_`subcommand' `macval(0)'
    }
    else {
        display as error "gracedr: `subcommand' is not available yet"
        exit 199
    }
end
