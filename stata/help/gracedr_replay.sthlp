{smcl}
{title:Title}

{phang}
{bf:gracedr replay} {hline 2} Redo a past draw and check it against the record


{title:Syntax}

{p 8 17 2}
{cmd:gracedr replay}{cmd:,}
{opth study(string)}
{opt id(string)}


{title:Description}

{pstd}
{cmd:gracedr replay} redraws the arm of one participant from the random number state and the
allocation probabilities stored with that participant, and compares the result with the record.
When the study has treatment codes it also rebuilds the codes that were still unused at that draw
(from the audit log and {cmd:codes.dta}) and picks the code the same way, so the code is checked
too.

{pstd}
If the participant was later overridden, the comparison uses the original arm and code kept in the
audit log. The command stores nothing and does not change your data or your random number
generator. A participant whose record was edited by hand shows as not matching.


{title:Examples}

{phang2}{cmd:. gracedr replay, study("`c(tmpdir)'/my study") id(P001)}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr replay} stores {cmd:r(id)}, {cmd:r(arm)}, {cmd:r(arm_replayed)}, {cmd:r(code)},
{cmd:r(code_replayed)} and {cmd:r(match)} (1 when the arm and the code both match).


{title:Also see}

{psee}
{help gracedr}, {help gracedr_override}, {help gracedr_randomize}
