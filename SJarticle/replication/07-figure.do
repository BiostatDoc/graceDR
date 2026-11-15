version 19
clear

use "results/stats_all.dta", clear
local symbols "Oh Th S X O"
local plots ""
local position = 0
foreach method in srs blocks minimization msb mmsb {
    local position = `position' + 1
    local symbol : word `position' of `symbols'
    local series `"(scatter meansmd_end meanguess if method == "`method'","'
    local series `"`series' msymbol(`symbol') mcolor(black) mlabel(method_label)"'
    local series `"`series' mlabsize(vsmall) mlabcolor(black))"'
    local plots `"`plots' `series'"'
}
twoway `plots', ///
    by(setting, cols(2) legend(off) note("")) ///
    xtitle("Correct-guess probability (%)") ///
    ytitle("Mean largest SMD at end") ///
    xscale(range(44 82)) ///
    ylabel(, angle(horizontal))
graph export "figures/tradeoff.pdf", replace
