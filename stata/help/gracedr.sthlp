{smcl}
{title:Title}

{phang}
{bf:gracedr} {hline 2} Group-adaptive randomization with a study folder


{title:Syntax}

{p 8 17 2}
{cmd:gracedr} {it:subcommand}{cmd:,} {opth study(string)} [{it:options}]


{title:Description}

{pstd}
{cmd:gracedr} is the Stata version of graceDR. Every subcommand takes {opt study()}, the single
folder that holds the study files. The subcommands are:

{synoptset 14}{...}
{synopt:{helpb gracedr_setup:setup}}define a study and create its files{p_end}
{synopt:{helpb gracedr_codes:codes}}check and load a treatment codes file{p_end}
{synopt:{helpb gracedr_randomize:randomize}}assign one participant{p_end}
{synopt:{helpb gracedr_status:status}}group sizes, balance table and graphs{p_end}
{synopt:{helpb gracedr_override:override}}change one assignment, with a reason{p_end}
{synopt:{helpb gracedr_audit:audit}}list the audit log{p_end}
{synopt:{helpb gracedr_replay:replay}}redo a past draw{p_end}
{synopt:{cmd:simulate}}simulate trials (not written yet){p_end}
{p2colreset}{...}

{pstd}
Typing {cmd:gracedr} alone lists the subcommands.
