version 19
clear

capture program drop cell_stats
program define cell_stats
    args cell position
    use "results/summary_`cell'.dta", clear
    generate str12 key = ""
    replace key = "smd_end" if point == "end" & metric == "smd_max"
    replace key = "smd_runin" if point == "run-in" & metric == "smd_max"
    replace key = "guess" if point == "all" & metric == "correct_guess"
    replace key = "forced" if point == "all" & metric == "pct_deterministic"
    replace key = "run" if point == "all" & metric == "longest_forced_run"
    replace key = "dev_end" if point == "end" & metric == "size_dev_A"
    keep if !missing(key)
    keep method key mean sd q95 max
    reshape wide mean sd q95 max, i(method) j(key) string
    foreach key in smd_end guess {
        generate se`key' = sd`key' / sqrt(${nsims})
    }

    tempfile exact
    preserve
    use "results/sim_`cell'.dta", clear
    keep if metric == "size_dev_A" & inlist(point, "run-in", "end")
    generate byte exact = value == 0
    collapse (mean) exact, by(method point)
    replace exact = 100 * exact
    replace point = subinstr(point, "-", "", .)
    reshape wide exact, i(method) j(point) string
    quietly save `"`exact'"'
    restore
    merge 1:1 method using `"`exact'"', assert(match) nogenerate

    generate str16 cell = "`cell'"
    generate byte cellno = `position'
    quietly save "results/stats_`cell'.dta", replace
end

capture program drop cell_paired
program define cell_paired
    args cell
    use "results/sim_`cell'.dta", clear
    keep if (point == "end" & metric == "smd_max") | ///
        (point == "all" & metric == "correct_guess")
    generate str5 key = cond(metric == "smd_max", "smd", "guess")
    keep sim method key value
    reshape wide value, i(sim key) j(method) string

    tempname handle
    tempfile paired
    postfile `handle' str16 cell str12 method str5 key double(mean lower upper) ///
        using `"`paired'"'
    foreach method in srs blocks minimization msb {
        foreach key in smd guess {
            quietly generate double difference = value`method' - valuemmsb if key == "`key'"
            quietly summarize difference
            local estimate = r(mean)
            local error = r(sd) / sqrt(r(N))
            post `handle' ("`cell'") ("`method'") ("`key'") (`estimate') ///
                (`estimate' - 1.96 * `error') (`estimate' + 1.96 * `error')
            drop difference
        }
    }
    postclose `handle'
    use `"`paired'"', clear
    quietly save "results/paired_`cell'.dta", replace
end

local position = 0
foreach cell of global cells {
    local position = `position' + 1
    cell_stats `cell' `position'
    cell_paired `cell'
}

clear
foreach cell of global cells {
    append using "results/stats_`cell'.dta"
}
generate byte methodno = (method == "srs") + 2 * (method == "blocks") ///
    + 3 * (method == "minimization") + 4 * (method == "msb") + 5 * (method == "mmsb")
generate str24 method_label = ""
replace method_label = "Simple randomization" if method == "srs"
replace method_label = "Permuted blocks" if method == "blocks"
replace method_label = "Minimization" if method == "minimization"
replace method_label = "MSB" if method == "msb"
replace method_label = "Modified MSB" if method == "mmsb"
generate str16 setting = "N = " + substr(cell, 2, 3) + ", " + substr(cell, 6, .)
sort cellno methodno
quietly save "results/stats_all.dta", replace

clear
foreach cell of global cells {
    append using "results/paired_`cell'.dta"
}
quietly save "results/paired_all.dta", replace
display "Summaries saved in results/stats_all.dta and results/paired_all.dta"
