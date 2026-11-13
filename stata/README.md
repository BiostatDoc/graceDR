# gracedr for Stata

This folder holds the Stata 19 version of graceDR. The design is in
`docs/superpowers/specs/2026-11-13-stata-addition-design.md`. Right now it holds only the
scaffolding: a placeholder `gracedr` command, a certification script, and the checks that run
them.

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

## CI

`.github/workflows/stata.yml` runs `stata-lint` and `stata-test` on every pull request from this
repository and on every push to `main`. GitHub's hosted runners have no Stata license, so the jobs
run on a self-hosted Windows runner with the requirements above. Pull requests from forks are
skipped so that outside code never runs on that machine.
