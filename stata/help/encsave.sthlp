{smcl}
{title:Title}

{phang}
{bf:encsave} {hline 2} Save the dataset in memory to an AES-256 encrypted zip file


{title:Syntax}

{p 8 17 2}
{cmd:encsave} {cmd:using} {it:filename} [{cmd:,} {opt replace}]


{title:Description}

{pstd}
{cmd:encsave} saves the dataset in memory to a temporary file, writes it into a zip file
encrypted with AES-256, and erases the temporary file. Only the zip file remains. The dataset
in memory is not changed. If {it:filename} does not end in {cmd:.zip}, {cmd:.zip} is added.

{pstd}
The password comes from the environment variable {cmd:GRACEDR_PASSPHRASE}. If that is not set, a
masked pop-up opens and asks for the password twice. There is no {cmd:password()} option,
because Stata echoes command lines into the log and the command history. The password is never
stored and never put in a Stata macro. Use {help encuse} to load the dataset again.

{pstd}
{cmd:encsave} needs the Python package {cmd:pyzipper} in the Python that Stata uses. If it is
missing, the error message shows how to install it. Use {cmd:python query} to see which Python
Stata uses and {cmd:set python_exec} to change it.


{title:Options}

{phang}
{opt replace} permits {cmd:encsave} to overwrite an existing zip file. The old file stays
unchanged if writing the new one fails.


{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. encsave using "`c(tmpdir)'/auto", replace}{p_end}


{title:Also see}

{psee}
{help encuse}
