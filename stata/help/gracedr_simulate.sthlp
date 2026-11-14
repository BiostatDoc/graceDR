{smcl}
{title:Title}

{phang}
{bf:gracedr simulate} {hline 2} Simulate trials under several allocation methods


{title:Syntax}

{p 8 17 2}
{cmd:gracedr simulate}{cmd:,}
{opt methods(string)}
{opt nsims(#)}
{opt seed(#)}
[{opth study(string)} | {it:design options}]
[{it:generator options}]
[{it:output options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt methods(string)}}one or more of {cmd:mmsb}, {cmd:srs}, {cmd:blocks},
{cmd:minimization} and {cmd:msb}{p_end}
{synopt:{opt nsims(#)}}number of trials, a whole number from 1 to 100,000,000{p_end}
{synopt:{opt seed(#)}}whole number from 0 to 2147483647{p_end}

{syntab:Design}
{synopt:{opth study(string)}}read the design from an existing study; only {cmd:design.dta} is
read and nothing is written to the folder{p_end}
{synopt:{it:design options}}without {opt study()}, the options of
{helpb gracedr_setup:gracedr setup}
({opt n()}, {opt arms()}, {opt ratio()}, {opt weights()}, {opt pstar()}, {opt xi()},
{opt runin()}, {opt runinmethod()}, {opt forcedat()}, {opt sizebound()}, {opt categorical()} and
{opt continuous()}); {opt n()} and {opt arms()} are required{p_end}

{syntab:Generator}
{synopt:{opt generator(iid|drift)}}default {cmd:iid}; {cmd:drift} moves the distributions
linearly to {opt driftto()}{p_end}
{synopt:{opt probs(string)}}{it:name}{cmd::} {it:p p} [{cmd:|} {it:name2}{cmd::} {it:p p}]:
category probabilities in level order, adding up to 1; default equal{p_end}
{synopt:{opt meansd(string)}}{it:name}{cmd::} {it:mean sd} [{cmd:|} ...]: normal
distribution for a continuous variable; default 0 and 1{p_end}
{synopt:{opt driftto(string)}}end-of-enrollment values in the same forms; with {cmd:drift}
only{p_end}
{synopt:{opt phigh(#)}}probability for the arm that minimization picks, greater than 0 and less
than 1; default 0.8{p_end}

{syntab:Output}
{synopt:{opt saving(filename)}}save the results dataset; not a file in the study folder{p_end}
{synopt:{opt summary(filename)}}save the summary dataset{p_end}
{synopt:{opt clear}}leave the results dataset in memory, replacing your data; without
{opt saving()} and {opt clear} only the summary is shown{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:gracedr simulate} simulates {opt nsims()} trials. In each simulation one stream of
participants is generated and every method allocates that same stream, with the same random
numbers, so the results for one method do not depend on which other methods are run. Simulation
{it:j} uses its own seed drawn from {opt seed()}, so the first {it:j} simulations are the same
whatever {opt nsims()} is. Your data and your random number generator are not changed.

{pstd}
The methods are {cmd:mmsb} (the modified minimal sufficient balance algorithm), {cmd:srs} (simple
random), {cmd:blocks} (permuted blocks of size {cmd:2 * sum(ratio)}, whole-number ratios only),
{cmd:minimization} (Pocock–Simon, with continuous variables split into three bins at the
tertiles of 1,000 generated participants) and {cmd:msb} (unmodified MSB: no size vote, no quota and
no bound).

{pstd}
Virtual participants come from independent distributions for each balance variable: category
probabilities for a categorical variable and a normal distribution for a continuous one. With
{cmd:generator(drift)} each value moves in a straight line from its start value to its
{opt driftto()} value over the enrollment: for participant {it:j} of {it:n} the value is
{it:start} + (({it:j} - 1) / max({it:n} - 1, 1)) * ({it:end} - {it:start}).

{pstd}
Metrics are computed for each trial at the run-in (when there is one), at each forced total
({cmd:n=}{it:k}) and at the end: the largest absolute standardized mean difference
({cmd:smd_max}), one per variable ({cmd:smd_}{it:name}) and the absolute difference between each
arm's count and its target ({cmd:size_dev_}{it:arm}). Over the whole trial ({cmd:all}) it also
computes {cmd:pct_deterministic} (the percent of assignments with a probability of 1),
{cmd:longest_forced_run} (the longest run of forced assignments to one arm) and
{cmd:correct_guess} (the percent chance that a guesser who always picks the arm furthest behind
its target is right).

{pstd}
The results dataset has one row per simulation, method and metric: {cmd:sim}, {cmd:method},
{cmd:point}, {cmd:metric} and {cmd:value}. The summary shown on screen has one row per method,
point and metric with the mean, standard deviation, 95th and 99th percentiles (type 7) and
maximum. Missing values are left out, and a group with no values gives a missing summary.

{pstd}
Simulations run one at a time in one loop. There is no parallel option.


{title:Examples}

{phang2}{cmd:. gracedr simulate, n(60) arms(A B) categorical(sex: male female)}
{cmd:continuous(age) methods(mmsb srs) nsims(100) seed(1)}{p_end}

{phang2}{cmd:. gracedr simulate, study("`c(tmpdir)'/my study") methods(mmsb minimization)}
{cmd:nsims(100) seed(1) generator(drift) probs(sex: 0.2 0.8) driftto(sex: 0.8 0.2)}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr simulate} stores {cmd:r(nsims)} and {cmd:r(methods)}.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_setup}
