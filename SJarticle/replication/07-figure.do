version 19
clear

use "results/stats_all.dta", clear
local position = 0
foreach cell of global cells {
    local position = `position' + 1
    quietly levelsof setting if cellno == `position', local(panel_text)
    label define panel_label `position' `panel_text', add
}
label values cellno panel_label
quietly summarize meanguess
local axis_low = floor(r(min) - 2)
local axis_high = ceil(r(max) + 12)
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
    by(cellno, cols(2) legend(off) note("")) ///
    xtitle("Correct-guess probability (%)") ///
    ytitle("Mean largest SMD at end") ///
    xscale(range(`axis_low' `axis_high')) ///
    ylabel(, angle(horizontal))
graph export "figures/tradeoff.pdf", replace
