{smcl}
{title:Title}

{phang}
{bf:gracedr setup} {hline 2} Define a study and create its files


{title:Syntax}

{p 8 17 2}
{cmd:gracedr setup}{cmd:,}
{opth study(string)}
{opt n(#)}
{opt arms(string)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth study(string)}}folder that will hold the study files{p_end}
{synopt:{opt n(#)}}planned enrollment, a whole number from 2 to 2,000,000,000{p_end}
{synopt:{opt arms(string)}}at least 2 unique arm labels, quoted if they hold spaces{p_end}

{syntab:Balance variables}
{synopt:{opt categorical(string)}}{it:name}{cmd::} {it:level level}
[{cmd:|} {it:name2}{cmd::} {it:level level}]{p_end}
{synopt:{opt continuous(string)}}one or more variable names{p_end}
{synopt:{opt weights(numlist)}}one positive weight per balance variable{p_end}

{syntab:Allocation}
{synopt:{opt ratio(numlist)}}one positive value per arm; default 1 for every arm{p_end}
{synopt:{opt pstar(#)}}probability between 0 and 1; default 0.30{p_end}
{synopt:{opt xi(#)}}probability between 0.5 and 1; default 0.65{p_end}
{synopt:{opt runin(#)}}run-in size, 0 for no run-in; default is the larger of 10
and 10% of {cmd:n()}, raised to a multiple of the ratio total for whole-number ratios,
and never above {cmd:n()}{p_end}
{synopt:{opt runinmethod(tilted|rar)}}run-in method; default {cmd:tilted}{p_end}
{synopt:{opt forcedat(numlist)}}enrollment totals where proportions are forced{p_end}
{synopt:{opt sizebound(#)}}whole number of at least 1; default 3{p_end}

{syntab:Other}
{synopt:{opt codes(file)}}treatment codes, a CSV or Stata dataset with columns
{cmd:code} and {cmd:arm}{p_end}
{synopt:{opt seed(#)}}whole number from 0 to 2147483647{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:gracedr setup} checks the options, then creates the study folder and five datasets in it:
{cmd:design.dta}, {cmd:participants.dta}, {cmd:codes.dta}, {cmd:audit.dta} and
{cmd:state.dta}. It stops before it writes anything if an option or the codes file is wrong,
and it refuses to run when the folder already holds a study. Your data in memory and your own
random number generator are not changed.

{pstd}
If a write fails part way, the command says so and names the files to remove before setup is run
again. A folder that existed before setup is never deleted.

{pstd}
Balance variables are kept in a fixed order: every {opt categorical()} variable in the order
written, then every {opt continuous()} variable. {opt weights()} follows that order, whatever
order the options were typed in. Levels are trimmed and lower-cased. Variable names are
case-sensitive, and so are the options that supply a participant's values: {cmd:Sex()} does not
match a variable named {cmd:sex}.

{pstd}
Without {opt seed()}, setup picks a seed from the clock, shows it, and stores it in
{cmd:state.dta}. A study keeps its own random number stream, so the seed and the stored state
reproduce every draw. A seed taken from the clock is not secret, so give {opt seed()} yourself
when the seed must not be guessable.

{pstd}
Arm labels and levels must not contain double quotes, backticks or dollar signs.


{title:Examples}

{pstd}
Run an example once. To run it again, delete the study folder first. The first example uses
the example codes file, which {cmd:net get gracedr} copies into the current folder.

{phang2}{cmd:. gracedr setup, study("`c(tmpdir)'/my study") n(40) arms(A B)}
{cmd:categorical(sex: male female | race: white black other) continuous(age)}
{cmd:codes("example_codes.csv") seed(20260611)}{p_end}

{phang2}{cmd:. gracedr setup, study("`c(tmpdir)'/three arms") n(90) arms(A B C)}
{cmd:ratio(2 1 1) categorical(sex: male female) runin(0)}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr setup} stores {cmd:r(seed)} (the seed used) and {cmd:r(study)} (the normalized
folder).


{title:Also see}

{psee}
{help gracedr}, {help gracedr_codes}
