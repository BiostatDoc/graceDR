# gracedr for Stata

This folder holds the Stata 19 version of graceDR. The design is in
`docs/superpowers/specs/2026-11-13-stata-addition-design.md`. Right now it holds the
checks that run the certification scripts, the study folder helpers, and the commands
`gracedr setup`, `gracedr codes`, `gracedr randomize`, `gracedr status`, `gracedr override`,
`gracedr audit`, `gracedr replay` and `gracedr simulate`. Later cards add the rest.

## Requirements

- Windows, with Stata 19 installed at `C:/Program Files/StataNow19/StataMP-64.exe`. To use another
  location, set the environment variable `STATA_EXE`.
- `make` and `bash` (Git for Windows provides both).
- The `stata_linter` package (`ssc install stata_linter`), Python, and the Python package
  `pandas`.
- Later cards add the Python package `pyzipper` for the encryption utility.

## Checks

Run these from the repository root, or from this folder with `make <target>`:

| Target | What it does |
|---|---|
| `format` | Replaces tabs with spaces and removes trailing spaces |
| `lint` | Runs `stata_linter` on every `.ado` and `.do` file, lines up to 99 characters |
| `test` | Runs every `cert/certify_*.do` in batch mode and fails on any Stata error |
| `pre-pr` | Runs the three above in order |

Mata code lives in `ado/_gracedr_*.mata`. Mata functions inside an `.ado` file are private to
that file, so each subject keeps its functions in a `.mata` file that its `load` subcommand runs
with `findfile` and `do` the first time it is needed.

Write each certification file as `cert/certify_<subject>.do`. It must start by finding the
`stata/` folder through the environment variable that `run_stata.sh` sets:

```
local stata_dir : environment GRACEDR_STATA_DIR
adopath ++ "`stata_dir'/ado"
```

The root `make pre-pr` runs the R checks and then these. It fails on a machine without Stata.

The batch runner writes `<do-file name>.log` in this folder. The top of a Stata log shows the
license holder and serial number, so `run_stata.sh` prints only the part after the do-file starts,
and logs are never committed.

`make` from Rtools passes Stata almost no environment variables. `run_stata.ps1` restores
`ComSpec`, `TEMP` and `TMP` before it starts Stata. Shell scripts here use bash globs and never
call `find` or `sort`, which Rtools bash resolves to Windows programs.

## Commands, data and help

`gracedr <subcommand>` is a dispatcher in `ado/gracedr.ado`. It runs `gracedr_<subcommand>`, so
each command is its own file. Subcommands that are not written yet say so.

| Command | File | What it does |
|---|---|---|
| `gracedr setup` | `ado/gracedr_setup.ado` | Checks the options and creates a study folder |
| `gracedr codes` | `ado/gracedr_codes.ado` | Checks and loads a treatment codes file |
| `gracedr randomize` | `ado/gracedr_randomize.ado` | Assigns the next participant |
| `gracedr status` | `ado/gracedr_status.ado` | Group sizes, balance and graphs, with filters |
| `gracedr override` | `ado/gracedr_override.ado` | Changes one arm, with a reason |
| `gracedr audit` | `ado/gracedr_audit.ado` | Lists the audit log |
| `gracedr replay` | `ado/gracedr_replay.ado` | Redoes a past draw and compares it |
| `gracedr simulate` | `ado/gracedr_simulate.ado` | Simulates trials under several methods |

`data/` holds `example_codes.csv` and `.dta` (the same 200 codes as the R package) and
`example_participants.dta` (40 made-up participants). `help/` holds the `.sthlp` files. To read
them in Stata, add the folders to the adopath with `adopath ++ "<this folder>/ado"` and
`adopath ++ "<this folder>/help"`. The help examples read the data with paths that start at the
repository root.

## Study files

`_gracedr_study` reads and writes the datasets in a study folder. A write goes to `<name>.tmp`
first, the current file is copied to `<name>.bak`, and the new file replaces it. Stata has no
file rename, so the replacement is a copy. `_gracedr_utc` returns the UTC clock through
the Windows PowerShell under `SYSTEMROOT`, because Stata has only local time. Both are certified in
`cert/certify_study.do` and `cert/certify_utc.do`. Shared certification programs
(`expect_failure`, `make_data`, `remove_folder`) are in `cert/helpers.do`.

## CI

`.github/workflows/stata.yml` runs `stata-lint` and `stata-test` on every pull request from this
repository and on every push to `main`. GitHub's hosted runners have no Stata license, so the jobs
run on a self-hosted Windows runner with the requirements above. Pull requests from forks are
skipped so that outside code never runs on that machine.
