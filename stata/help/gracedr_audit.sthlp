{smcl}
{title:Title}

{phang}
{bf:gracedr audit} {hline 2} List the audit log of a study


{title:Syntax}

{p 8 17 2}
{cmd:gracedr audit}{cmd:,}
{opth study(string)}


{title:Description}

{pstd}
{cmd:gracedr audit} lists {cmd:audit.dta}: the time (UTC), the action ({cmd:create},
{cmd:randomize} or {cmd:override}), the participant id, the old and new arm, the old and new
code, and the reason. The log is append-only. The first row is the study creation row, whose id
is {cmd:(study)}.

{pstd}
The command does not change your data in memory.


{title:Examples}

{phang2}{cmd:. gracedr audit, study("`c(tmpdir)'/my study")}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr audit} stores {cmd:r(rows)}, the number of rows listed.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_override}
