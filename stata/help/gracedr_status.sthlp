{smcl}
{title:Title}

{phang}
{bf:gracedr status} {hline 2} Group sizes, balance and graphs for a study


{title:Syntax}

{p 8 17 2}
{cmd:gracedr status}{cmd:,}
{opth study(string)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth study(string)}}folder that holds the study files{p_end}
{synopt:{opt from(#)}}use participants with sequence number at least {it:#}{p_end}
{synopt:{opt to(#)}}use participants with sequence number at most {it:#}{p_end}
{synopt:{opt checkpoint(string)}}use participants up to a checkpoint: {cmd:run-in},
{cmd:final}, or an enrollment total from the checkpoint list{p_end}
{synopt:{opt vars(namelist)}}keep only these balance variables{p_end}
{synopt:{opt graphs}}draw the imbalance and standardized mean difference graphs{p_end}
{synopt:{opt saving(filename)}}with {opt graphs}, save the graphs as
{it:filename}{cmd:_imbalance.gph} and {it:filename}{cmd:_smd.gph}; give {it:filename} without
{cmd:.gph}{p_end}
{synoptline}


{title:Description}

{pstd}
{cmd:gracedr status} reads the study files and prints the group-size table (arm, n, percent,
target at the next checkpoint, final target) and the balance table (per variable and level,
{cmd:n (pct)} or {cmd:mean (sd)} per arm, and the largest absolute standardized mean difference).
It does not randomize anyone and does not change your data or random number generator.

{pstd}
{opt from()} and {opt to()} are whole numbers of at least 1. {opt checkpoint()} cannot be
combined with {opt from()} or {opt to()}, {opt from()} cannot be greater than {opt to()}, and a
checkpoint must already be reached. {opt vars()} keeps variables
in the order of the design.

{pstd}
{opt saving()} writes plain graph files, also for an encrypted study, because you name them. They
are not encrypted. Save them in a folder that only the people who may see them can read.

{pstd}
Without {opt graphs} no graph is drawn. With it the graphs are named {cmd:gracedr_imbalance} and
{cmd:gracedr_smd}.


{title:Examples}

{phang2}{cmd:. gracedr status, study("`c(tmpdir)'/my study")}{p_end}

{phang2}{cmd:. gracedr status, study("`c(tmpdir)'/my study") checkpoint(run-in) vars(age)}{p_end}


{title:Stored results}

{pstd}
{cmd:gracedr status} stores {cmd:r(n_randomized)}, the matrix {cmd:r(groupsize)} (n, percent,
next target, final target by arm), the matrix {cmd:r(smd)} (one row per variable) and
{cmd:r(varnames)}.


{title:Also see}

{psee}
{help gracedr}, {help gracedr_randomize}


{title:Authors}

{pstd}Grace Huiyi Ma{p_end}
{pstd}Dutch Fork High School STEM Magnet Program{p_end}
{pstd}Irmo, South Carolina{p_end}

{pstd}James W. Hardin{p_end}
{pstd}Department of Epidemiology and Biostatistics{p_end}
{pstd}University of South Carolina{p_end}
{pstd}Columbia, South Carolina{p_end}
{pstd}jhardin@sc.edu{p_end}
