# gracedr for Stata

This folder holds the Stata 19 version of graceDR. The design is in
`docs/superpowers/specs/2026-11-13-stata-addition-design.md`. Right now it holds the
checks that run the certification scripts, the study folder helpers, and the commands
`gracedr setup`, `gracedr codes`, `gracedr randomize`, `gracedr status`, `gracedr override`,
`gracedr audit`, `gracedr replay` and `gracedr simulate`, and the encryption utility
`encsave` and `encuse`. Later cards add the rest.

## Requirements

- Windows, with Stata 19 installed at `C:/Program Files/StataNow19/StataMP-64.exe`. To use another
  location, set the environment variable `STATA_EXE`.
- `make` and `bash` (Git for Windows provides both).
- The `stata_linter` package (`ssc install stata_linter`), Python, and the Python package
  `pandas`.
- The Python package `pyzipper`, installed in the Python that Stata uses (`python query` shows it),
  for the encryption utility.

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
`example_participants.dta` (40 made-up participants). `help/` holds the `.sthlp` files.

## Install

`gracedr.pkg` and `stata.toc` make this folder a Stata package. From a clone of the repository:

```stata
net install gracedr, from("<path to this folder>") replace
net get gracedr, from("<path to this folder>")
```

`net install` copies the ado-files, the `.mata` files and the help files into the `PLUS`
directory. The `.mata` files go with the ado-files because each command loads its Mata code with
`findfile`. `net get` copies the example data files into the current folder, because `net install`
does not copy data files. The help examples use the file names without a path. To work from the
clone without installing, add the folders to the adopath with `adopath ++ "<this folder>/ado"` and
`adopath ++ "<this folder>/help"`. `cert/certify_install.do` installs the package into a scratch
`PLUS` directory and runs every command from there. It also checks that every file in `ado/`,
`help/` and `data/` is listed in `gracedr.pkg`.

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

## Encryption utility

`encsave using <file>` saves the dataset in memory to an AES-256 zip, and `encuse using <file>`
loads one. They are independent of the `gracedr` commands. The code is in `ado/encsave.ado`,
`ado/encuse.ado` and `python/gracedr_zip.py`, which uses Stata's Python integration and the package
`pyzipper`. The password comes from the environment variable `GRACEDR_PASSPHRASE`, or from a masked
pop-up. There is no `password()` option. `cert/certify_zip.do` certifies the round trip, a wrong
password, leftover files, a missing `pyzipper` and that the password stays out of the log.

## Encrypted studies

`gracedr setup, ..., encrypt` stores `design`, `participants`, `codes`, `audit` and `state` as
AES-256 zips (`design.zip` and so on) written by `encsave`. Every other `gracedr` command treats a
folder that holds any of those zips as an encrypted study, so it needs no option. A write goes to `<name>.tmp.zip`,
keeps the current file as `<name>.bak.zip` and then replaces it, and it is refused unless the
password opens the current file. The password comes from `GRACEDR_PASSPHRASE`, or from one pop-up
per study folder and Stata session whose answer only Python's memory keeps (the `session` option of `encsave` and
`encuse`). Stata's own temporary copies, such as `preserve` files in `c(tmpdir)`, are plain and are
erased when a command ends, so a crash can leave one there. `cert/certify_encrypted.do` runs the
`certify_randomize.do` sequence on an encrypted study, then certifies the reference arms, that
only zip files are left in the study folder after an error, that a wrong password stops every
command and changes nothing, and that the pop-up is asked once.
