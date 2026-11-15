version 19
clear all
set more off

capture log close
log using "logs/run-all.log", replace text

do "00-setup.do"
do "helpers.do"
do "01-simulate.do"
do "02-summarize.do"
do "03-package-tables.do"
do "04-package-demo.do"
do "05-encrypted-demo.do"
do "06-simulation-tables.do"
do "07-figure.do"

log close
