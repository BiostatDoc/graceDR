{smcl}
{title:Title}

{phang}
{bf:gracedr codes} {hline 2} Check and load a treatment codes file


{title:Syntax}

{p 8 17 2}
{cmd:gracedr codes using} {it:filename}{cmd:,} {opt arms(string)}

{synoptset 12}{...}
{synopthdr}
{synoptline}
{synopt:{opt arms(string)}}the valid arm labels, quoted if they hold spaces{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:gracedr codes} reads a treatment codes file and checks it. It needs no study. The file is
a CSV or a Stata dataset (a name ending in {cmd:.dta}) with the columns {cmd:code} and
{cmd:arm}. Numeric codes in a Stata dataset must be whole numbers; they are turned into text.
Values are trimmed, and leading zeros in a CSV are kept.

{pstd}
The command stops with a message when a column is missing, the file has no rows, a code is
empty or repeated, or an arm is blank or not one of {opt arms()}. When it stops, the data in
memory is left as it was.

{pstd}
When the file is valid, the data in memory is replaced by the codes with the columns
{cmd:code}, {cmd:arm}, {cmd:status} (all {cmd:unused}) and {cmd:id} (empty). This is the layout
of {cmd:codes.dta} in a study folder.


{title:Examples}

{pstd}
The example files come with the package. Run {cmd:net get gracedr} once to copy them into the
current folder.

{phang2}{cmd:. gracedr codes using "example_codes.csv", arms(A B)}{p_end}
{phang2}{cmd:. gracedr codes using "example_codes.dta", arms(A B)}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr codes} stores {cmd:r(n)}, the number of codes.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_setup}
