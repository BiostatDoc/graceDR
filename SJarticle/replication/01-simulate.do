version 19
clear

local design "arms(A B) categorical(sex: male female | race: white black other)"
local design "`design' continuous(age)"
local iid "generator(iid) probs(sex: 0.48 0.52 | race: 0.62 0.23 0.15)"
local iid "`iid' meansd(age: 60 10)"
local drift "generator(drift) probs(sex: 0.20 0.80 | race: 0.77 0.08 0.15)"
local drift "`drift' meansd(age: 48 8)"
local drift "`drift' driftto(sex: 0.80 0.20 | race: 0.37 0.48 0.15 | age: 72 8)"

foreach size of numlist 200 500 {
    foreach scenario in iid drift {
        local cell "N`size'_`scenario'"
        display as text "Running `cell'"
        quietly gracedr simulate, ///
            n(`size') ///
            `design' ///
            ``scenario'' ///
            methods(${methods}) ///
            nsims(${nsims}) ///
            seed(${seed}) ///
            saving("results/sim_`cell'.dta") ///
            summary("results/summary_`cell'.dta")
        display as text "Finished `cell': " r(nsims) " simulations of " r(methods)
    }
}
