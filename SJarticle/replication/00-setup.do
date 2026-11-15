version 19
clear all
set more off
set linesize 80

global cells N200_iid N200_drift N500_iid N500_drift
global methods srs blocks minimization msb mmsb
global nsims 1000
global seed 20260611

local source : environment GRACEDR_SOURCE
if "`source'" == "" {
    local source "https://raw.githubusercontent.com/BiostatDoc/graceDR/main/stata"
}
quietly net install gracedr, from("`source'") replace

local home "`c(pwd)'"
foreach folder in data results figures studies {
    capture mkdir `folder'
}
quietly cd data
quietly net get gracedr, from("`source'") replace
quietly cd "`home'"

quietly findfile gracedr.ado
local plus = lower(subinstr("`c(sysdir_plus)'", char(92), "/", .))
local installed = strpos(lower("`r(fn)'"), "`plus'") == 1
if `installed' == 0 {
    display as error "gracedr.ado was found outside the PLUS folder: `r(fn)'"
    display as error "Remove that copy so that the installed package is the one that runs."
    exit 459
}

python:
import subprocess
import sys

try:
    import pyzipper
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyzipper"])
    import pyzipper
end

display "Stata " c(stata_version) ", " c(os) ", " c(machine_type)
display "The gracedr package is installed and its example files are in data/"
