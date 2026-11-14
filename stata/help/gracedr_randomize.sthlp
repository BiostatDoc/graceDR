{smcl}
{title:Title}

{phang}
{bf:gracedr randomize} {hline 2} Assign the next participant to an arm


{title:Syntax}

{p 8 17 2}
{cmd:gracedr randomize}{cmd:,}
{opth study(string)}
{opt id(string)}
{it:name}{cmd:(}{it:value}{cmd:)} ...
[{opt graphs}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth study(string)}}folder that holds the study files{p_end}
{synopt:{opt id(string)}}participant id, not empty, at most 244 bytes, not already used{p_end}
{synopt:{it:name}{cmd:(}{it:value}{cmd:)}}one option for each balance variable, named after the
variable{p_end}
{synopt:{opt graphs}}draw the imbalance and standardized mean difference graphs{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:gracedr randomize} assigns one participant with the modified minimal sufficient balance
method. It checks the id and the values, works out the allocation probabilities, draws the arm
from the study's own random number stream, and picks a treatment code for the arm when the study
has codes. The code comes from the same random number state as the arm, so one stored state
reproduces both.

{pstd}
It then adds the participant to {cmd:participants.dta}, marks the code used in
{cmd:codes.dta}, adds a row to {cmd:audit.dta}, and only then stores the new random number state
in {cmd:state.dta}. Everything is checked before the first file is written, so a duplicate id,
a full study, a missing study or an arm with no unused codes leaves every file as it was.
If a write fails part way, the command names the files already written and says that
{cmd:state.dta} was not advanced.

{pstd}
The command prints the participant, the arm, the treatment code and the group-size table. It
leaves your data in memory and your own random number generator unchanged.

{pstd}
A missing value is entered as {cmd:.}, for example {cmd:age(.)}. A missing value is written to
the study as empty text for a categorical variable and as {cmd:.} for a continuous variable. The
command shows a warning that names the variables and still randomizes the participant.

{pstd}
Variable names and the options that supply values are case-sensitive: {cmd:Sex(male)} does not
match a variable named {cmd:sex}.

{pstd}
A quoted value that contains a closing parenthesis is not supported, because the option scanner
counts parentheses and ignores quotes.

{pstd}
Without {opt graphs} no graph is drawn. With it the graphs are named {cmd:gracedr_imbalance}
and {cmd:gracedr_smd}, and each call replaces the previous ones.


{title:Examples}

{phang2}{cmd:. gracedr randomize, study("`c(tmpdir)'/my study") id(P001) sex(male) age(54)}{p_end}

{phang2}{cmd:. gracedr randomize, study("`c(tmpdir)'/my study") id(P002) sex(female)}
{cmd:age(.) graphs}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr randomize} stores {cmd:r(id)}, {cmd:r(arm)}, {cmd:r(code)} (empty without codes),
{cmd:r(phase)} (one of {cmd:quota}, {cmd:runin}, {cmd:bound}, {cmd:msb-biased} and
{cmd:msb-random}), {cmd:r(probs)} (the allocation probabilities in arm order),
{cmd:r(missingvars)} and {cmd:r(n_randomized)}.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_setup}, {help gracedr_codes}
