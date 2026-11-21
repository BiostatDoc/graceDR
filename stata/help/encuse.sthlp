{smcl}
{title:Title}

{phang}
{bf:encuse} {hline 2} Load a dataset from an AES-256 encrypted zip file made by encsave


{title:Syntax}

{p 8 17 2}
{cmd:encuse} {cmd:using} {it:filename} [{cmd:,} {opt clear} {opt session}]


{title:Description}

{pstd}
{cmd:encuse} unzips a file made by {help encsave} to a temporary file, loads the dataset, and
erases the temporary file. If {it:filename} does not end in {cmd:.zip}, {cmd:.zip} is added.

{pstd}
The password comes from the environment variable {cmd:GRACEDR_PASSPHRASE}. If that is not set, a
masked pop-up opens and asks for it. There is no {cmd:password()} option, because Stata echoes
command lines into the log and the command history. With a wrong password, or a file that is not
an encrypted dataset archive, {cmd:encuse} stops with an error and the dataset in memory stays as
it was.

{pstd}
{cmd:encuse} needs the Python package {cmd:pyzipper} in the Python that Stata uses. If it is
missing, the error message shows how to install it. Use {cmd:python query} to see which Python
Stata uses and {cmd:set python_exec} to change it.


{title:Options}

{phang}
{opt clear} replaces the dataset in memory, even if it has unsaved changes.

{phang}
{opt session} remembers a password typed in the pop-up until Stata closes, so that later calls
with {opt session} do not ask again. A wrong password is forgotten, so the next call asks
again. The password stays in Python's memory only. The {cmd:gracedr} commands use it for
encrypted studies. Without it, every call asks.


{title:Examples}

{phang2}{cmd:. encuse using "`c(tmpdir)'/auto", clear}{p_end}


{title:Also see}

{psee}
{help encsave}


{title:Authors}

{pstd}Grace Huiyi Ma{p_end}
{pstd}Dutch Fork High School STEM Magnet Program{p_end}
{pstd}Irmo, South Carolina{p_end}

{pstd}James W. Hardin{p_end}
{pstd}Department of Epidemiology and Biostatistics{p_end}
{pstd}University of South Carolina{p_end}
{pstd}Columbia, South Carolina{p_end}
{pstd}jhardin@sc.edu{p_end}
