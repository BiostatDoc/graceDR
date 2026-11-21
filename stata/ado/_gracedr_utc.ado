*! version 1.0.0  15nov2026
program define _gracedr_utc, rclass
    version 19
    tempname milliseconds
    scalar `milliseconds' = .
    local fetch "from sfi import Scalar; import time"
    local store `"Scalar.setValue("`milliseconds'", time.time_ns() // 1000000)"'
    capture python: `fetch'; `store'
    if missing(scalar(`milliseconds')) {
        display as error "gracedr: could not read the UTC clock from Python"
        exit 601
    }
    return scalar time = scalar(`milliseconds') + tc(01jan1970 00:00:00)
end
