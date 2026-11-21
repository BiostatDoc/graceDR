{smcl}
{title:Title}

{phang}
{bf:gracedr override} {hline 2} Change one participant's arm, with a reason


{title:Syntax}

{p 8 17 2}
{cmd:gracedr override}{cmd:,}
{opth study(string)}
{opt id(string)}
{opt arm(string)}
{opt reason(string)}


{title:Description}

{pstd}
{cmd:gracedr override} moves a randomized participant to another arm and records why. The arm
must be a different arm of the study, and the reason must not be blank. The participant's id is
checked like any participant id, so {cmd:(study)} is refused.

{pstd}
When the study has treatment codes, the participant's old code is marked {cmd:voided} and never
reused, and a new unused code is drawn for the new arm from the study's random number stream. If
the new arm has no unused codes the command stops and changes nothing. The audit row keeps the old
and new arm, the old and new code and the reason, and {helpb gracedr_replay:gracedr replay} still
checks the original draw.

{pstd}
The study files are written in this order: {cmd:participants.dta}, {cmd:codes.dta},
{cmd:audit.dta}, then {cmd:state.dta}. If a write fails part way, the command names the files
already written and says that the random number state was not changed. Without codes, the random
number state is never changed.


{title:Examples}

{phang2}{cmd:. gracedr override, study("`c(tmpdir)'/my study") id(P001) arm(B)}
{cmd:reason("entered in error")}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr override} stores {cmd:r(id)}, {cmd:r(old_arm)}, {cmd:r(arm)}, {cmd:r(old_code)} and
{cmd:r(code)}.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_replay}, {help gracedr_audit}


{title:Authors}

{pstd}Grace Huiyi Ma{p_end}
{pstd}Dutch Fork High School STEM Magnet Program{p_end}
{pstd}Irmo, South Carolina{p_end}

{pstd}James W. Hardin{p_end}
{pstd}Department of Epidemiology and Biostatistics{p_end}
{pstd}University of South Carolina{p_end}
{pstd}Columbia, South Carolina{p_end}
{pstd}jhardin@sc.edu{p_end}
