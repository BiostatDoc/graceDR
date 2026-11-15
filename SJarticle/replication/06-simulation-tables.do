version 19
clear
set linesize 100

use "results/stats_all.dta", clear
replace setting = "" if !inrange(methodno, 1, 1)

generate str18 end_se = string(meansmd_end, "%5.3f") + " (" + string(sesmd_end, "%5.3f") + ")"
generate str8 end_q95 = string(q95smd_end, "%5.3f")
generate str8 runin = string(meansmd_runin, "%5.3f")
show_table setting method_label end_se end_q95 runin, ///
    title("Table: largest standardized mean difference, mean (SE), 95th percentile, run-in mean")

generate str8 exact_runin = string(exactrunin, "%5.1f")
generate str8 exact_end = string(exactend, "%5.1f")
generate str14 difference = string(meandev_end, "%5.2f") + " (" + string(maxdev_end, "%3.0f") + ")"
show_table setting method_label exact_runin exact_end difference, ///
    title("Table: percent exact at run-in and at end, final difference, mean (max)")

generate str8 forced = string(meanforced, "%5.1f")
generate str12 longest_run = string(meanrun, "%5.1f") + " (" + string(maxrun, "%3.0f") + ")"
generate str14 guess = string(meanguess, "%5.2f") + " (" + string(seguess, "%5.2f") + ")"
show_table setting method_label forced longest_run guess, ///
    title("Table: percent forced, longest forced run mean (max), correct guess mean (SE)")

use "results/paired_all.dta", clear
reshape wide mean lower upper, i(cell method) j(key) string
generate byte cellno = .
local position = 0
foreach cell of global cells {
    local position = `position' + 1
    replace cellno = `position' if cell == "`cell'"
}
generate byte methodno = (method == "srs") + 2 * (method == "blocks") ///
    + 3 * (method == "minimization") + 4 * (method == "msb")
sort cellno methodno
generate str16 setting = "N = " + substr(cell, 2, 3) + ", " + substr(cell, 6, .)
replace setting = "" if !inrange(methodno, 1, 1)
generate str28 smd_difference = string(meansmd, "%7.4f") + " (" + string(lowersmd, "%7.4f") ///
    + ", " + string(uppersmd, "%7.4f") + ")"
generate str28 guess_difference = string(meanguess, "%6.1f") ///
    + " (" + string(lowerguess, "%6.1f") + ", " + string(upperguess, "%6.1f") + ")"
show_table setting method smd_difference guess_difference, ///
    title("Table: differences from modified MSB, mean (95% interval)")
