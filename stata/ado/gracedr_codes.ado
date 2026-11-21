*! version 1.0.0  15nov2026
program define gracedr_codes, rclass
    version 19
    syntax using/, ARMS(string asis)
    preserve
    _gracedr_codes using `"`macval(using)'"', arms(`macval(arms)')
    return scalar n = r(n)
    restore, not
end
