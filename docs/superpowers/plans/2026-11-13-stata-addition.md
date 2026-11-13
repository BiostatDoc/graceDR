# gracedr for Stata Implementation Plan

> **For agentic workers:** This plan is carried out as Jira cards, one per task, through the
> `/card` skill. Each task below becomes one card. Steps use checkbox syntax for tracking.

**Goal:** Build the Stata 19 version of graceDR (`gracedr`), a Stata Journal article, and a
replication package, with linting and certification running in CI.

**Architecture:** A `gracedr` dispatcher ado-file calls one ado-file per subcommand. Each
study is a folder of datasets (`design`, `participants`, `codes`, `audit`, `state`).
Internal programs are named `_gracedr_*` and shared helpers live in their own ado-files.
Python is used only by a separate, independent encryption utility.

**Tech Stack:** Stata 19 (StataMP at `C:\Program Files\StataNow19`), `stata_linter`,
certification do-files, Python with `pyzipper`, GitHub Actions on a self-hosted Windows
runner, LaTeX (Stata Journal class) for the article.

**Spec:** `docs/superpowers/specs/2026-11-13-stata-addition-design.md`. The R algorithm is
in `docs/ImplementationPlan.md` section 3 and in `R/`.

## Global Constraints

- Stata 19 only. Windows only. Everything lives under `C:\Users\James\code\grace`.
- All commands are `gracedr <subcommand>` and take `study(folder)`. The encryption utility
  is separate and independent.
- No comparison between R and Stata results. Each language only matches itself.
- No comments in code. Lines under 100 characters. One subject per file.
- Passwords come from `GRACEDR_PASSPHRASE` or a masked Python pop-up. There is no
  `password()` option, and a password never reaches the log.
- Examples and fixtures use small made-up data. The repo is public.
- Work in a worktree per card, PR title `[GRACE-n] Title`, `make pre-pr` before every push.
- Batch run: `"C:/Program Files/StataNow19/StataMP-64.exe" /e do <file>.do`, then check the
  `.log` for `r(` errors.

## Review Focus

- A study folder path with spaces or backslashes must work.
- An id with spaces, mixed case, or a leading zero (`007`) must be stored and matched
  exactly, and a case-only duplicate (`p1` against `P1`) is a different id.
- A continuous value that is missing (`.`) or not a number stops the command with a clear
  message and leaves every dataset unchanged.
- A command interrupted between writes must leave the previous files intact and recoverable
  from the `.bak` copies.
- Randomizing after enrollment is full, or when no unused code is left for the drawn arm,
  stops with a clear message and writes nothing.
- A balance variable named like a fixed column (`id`, `arm`, `code`) is rejected at setup.

## File Structure

```
stata/ado/gracedr.ado                 dispatcher: parses the subcommand, calls the rest
stata/ado/gracedr_setup.ado           gracedr setup
stata/ado/gracedr_randomize.ado       gracedr randomize
stata/ado/gracedr_status.ado          gracedr status
stata/ado/gracedr_override.ado        gracedr override
stata/ado/gracedr_audit.ado           gracedr audit
stata/ado/gracedr_replay.ado          gracedr replay
stata/ado/gracedr_simulate.ado        gracedr simulate
stata/ado/gracedr_codes.ado           gracedr codes
stata/ado/_gracedr_study.ado          read, write, and validate the study datasets
stata/ado/_gracedr_rng.ado            isolated, replayable random number stream
stata/ado/_gracedr_design.ado         design parsing, run-in size, checkpoints, targets
stata/ado/_gracedr_values.ado         parse participant balance values
stata/ado/_gracedr_votes.ado          chi-square, Welch, size votes, tally, tilt
stata/ado/_gracedr_mmsb.ado           modified MSB probabilities
stata/ado/_gracedr_rules.ado          srs, blocks, minimization, MSB
stata/ado/_gracedr_tables.ado         group-size table, balance table, SMD
stata/ado/_gracedr_graphs.ado         imbalance and SMD graphs
stata/ado/_gracedr_generate.ado       iid and drift participant generators
stata/ado/_gracedr_metrics.ado        per-trial simulation metrics and summary
stata/ado/<zip utility>.ado           encryption utility (names chosen in Task 14)
stata/help/*.sthlp                    one help file per command
stata/data/                           example codes and example participants
stata/cert/                           certify_*.do and stored reference results
stata/gracedr.pkg, stata/stata.toc
stata/Makefile
SJarticle/                            article and replication package
```

## Task 1: CI, scaffolding, and Makefiles (first card)

**Files:**
- Create: `stata/Makefile`, `stata/ado/gracedr.ado` (placeholder), `stata/cert/certify_all.do`
  (placeholder that passes), `stata/README.md`, `.github/workflows/stata.yml`
- Modify: `Makefile` (root `pre-pr`), `.Rbuildignore` (add `^stata$`, `^SJarticle$`),
  `.gitignore`

**Interfaces:**
- Produces: `make -C stata format|lint|test|pre-pr`; workflow job names `stata-lint` and
  `stata-test`; the batch command in Global Constraints.

- [ ] Write the placeholder `certify_all.do` that fails when the placeholder ado-file is
  missing, run it, and see it fail before the ado-file exists.
- [ ] Create `gracedr.ado` (`program define gracedr`, version 19) so it passes.
- [ ] `stata/Makefile`: `format` runs the `stata_linter` fixer if it has one, otherwise
  checks only; `lint` runs `stata_linter` on `stata/ado` and `stata/cert`; `test` runs
  `certify_all.do` in batch and fails on any `r(` in the log.
- [ ] Root `pre-pr` runs the existing R steps and then `make -C stata pre-pr`.
- [ ] `stata.yml`: `runs-on: [self-hosted, windows]`, triggers on `push` to `main` and on
  `pull_request`, with `if: github.event.pull_request.head.repo.full_name == github.repository`
  for PR runs, so forks never run on the machine.
- [ ] Needs You (exact commands in the card): register the runner, install `stata_linter`
  (the card checks its current install command), install Python and `pyzipper`, and add
  `stata-lint` and `stata-test` as required checks.
- [ ] Verify: `make pre-pr` exits 0, and the workflow shows both jobs green on its own PR.

## Task 2: Study folder datasets and atomic writes

**Files:** `stata/ado/_gracedr_study.ado`, `stata/cert/certify_study.do`

**Interfaces:**
- Produces: `_gracedr_study read, study(str) name(design|participants|codes|audit|state)`
  (loads the named dataset), `_gracedr_study write, study(str) name(str)` (writes `.tmp`,
  keeps the current file as `.bak`, renames), `_gracedr_study exists, study(str)` (sets
  `r(exists)`), `_gracedr_study append_audit, study(str) action(str) id(str) old(str)
  new(str) oldcode(str) newcode(str) reason(str)`.
- Schemas are in the spec section 5: fixed file names, an audit table with `time`,
  `action`, `id`, `old`, `new`, `old_code`, `new_code`, `reason`.

- [ ] Certification: write then read round trip; a second write leaves a `.bak` equal to
  the first; a path with spaces; reading a missing study gives the message
  `gracedr: no study found in <folder>`; a stray `.tmp` file is replaced, not appended.
- [ ] Implement the programs and the datasets' empty-schema creation.

## Task 3: Isolated random number stream

**Files:** `stata/ado/_gracedr_rng.ado`, `stata/cert/certify_rng.do`

**Interfaces:**
- Produces: `_gracedr_rng init, study(str) seed(int)` (creates `state.dta`),
  `_gracedr_rng draw, study(str) probs(str) arms(str)` (returns `r(arm)` and `r(state_before)`,
  and stores the new state), `_gracedr_rng replay, state(str) probs(str) arms(str)` (returns
  `r(arm)` from a given state). The user's `c(rngstate)` is restored after every call.

- [ ] Certification: the user's state is unchanged after `draw`; the same seed gives the same
  sequence on two runs; `replay` of a stored state returns the arm `draw` returned; the state
  string is stored in a `strL` and survives a write and read.
- [ ] Implement with `c(rngstate)` and `set rngstate`.

## Task 4: Design, run-in size, checkpoints, and targets

**Files:** `stata/ado/_gracedr_design.ado`, `stata/cert/certify_design.do`

**Interfaces:**
- Produces: `_gracedr_design runin_size, n(int) ratio(numlist)` returns `r(n)`;
  `_gracedr_design targets, n(int) ratio(numlist)` returns the whole-number arm counts in
  `r(targets)` (largest remainder, ties to the earlier arm); `_gracedr_design checkpoints`
  returns a dataset of `n`, `type` (run-in, forced, final), `target1 ... targetK`;
  `_gracedr_design validate` implements all errors from `docs/ImplementationPlan.md`
  section 3 and rejects balance variable names `id`, `arm`, `code`, `seq`.

- [ ] Certification, with the spec's examples: `ratio(1 1)` gives run-in 10, 20, 100 for
  N = 60, 200, 1000; `ratio(2 1)` and N = 60 gives 12; the targets sum to the checkpoint
  and ties go to the earlier arm; each validation error has a case.
- [ ] Implement.

## Task 5: gracedr setup, gracedr codes, and example data

**Files:** `stata/ado/gracedr.ado`, `gracedr_setup.ado`, `gracedr_codes.ado`,
`stata/data/example_codes.csv` and `.dta`, `stata/data/example_participants.dta`,
`stata/help/gracedr_setup.sthlp`, `stata/help/gracedr_codes.sthlp`,
`stata/cert/certify_setup.do`

**Interfaces:**
- Consumes: Tasks 2, 3, 4.
- Produces: `gracedr setup, study(str) n(int) arms(str) [ratio() weights() pstar() xi()
  runin() runinmethod() forcedat() sizebound() categorical() continuous() codes() seed()]`
  and `gracedr codes using <file>, arms(str)`; the example files (the same 200 codes as
  `inst/extdata/example_codes.csv` and 40 made-up participants).

- [ ] Certification: setup creates the five datasets; setup on an existing study fails;
  a codes file with a missing column, a duplicate, an empty code, or an unknown arm fails
  with the intended message; both CSV and `.dta` codes load to the same `codes.dta`.
- [ ] Implement the dispatcher, both commands, and the help files with runnable examples.

## Task 6: Participant values

**Files:** `stata/ado/_gracedr_values.ado`, `stata/cert/certify_values.do`

**Interfaces:**
- Produces: `_gracedr_values parse, study(str) options(str)` reads `design.dta`, parses
  options such as `sex(male) age(45)`, and returns one stored row (scalars in `r()`).

- [ ] Certification: missing, repeated, and unknown variables; unknown level; missing or
  non-numeric continuous value; option order does not matter; levels are trimmed and
  lower-cased as in R; ids with spaces and leading zeros pass through unchanged.
- [ ] Implement by catching the remaining options (`syntax ..., [*]`) and parsing them.

## Task 7: Votes and tilt

**Files:** `stata/ado/_gracedr_votes.ado`, `stata/cert/certify_votes.do`

**Interfaces:**
- Produces: `_gracedr_votes categorical`, `continuous`, `size`, `tally`, and
  `_gracedr_votes tilt, base(numlist) winner(int) xi(real)` returning `r(probs)`. Rules
  follow `R/votes.R` and `R/tilt.R`.

- [ ] Certification with hand-derived cases: chi-square vote for the arm with the lowest
  proportion, a tie means no vote; Welch's t and one-way for more than two arms, vote only
  when the value is outside the arm means; size vote at `D <= -1`; tilt gives
  `o = b/(1-b) * xi/(1-xi)` and leaves `b` unchanged when the base is 0 or 1.
- [ ] Implement, coding the Welch one-way test if Stata has no direct command.

## Task 8: The MMSB probabilities

**Files:** `stata/ado/_gracedr_mmsb.ado`, `stata/cert/certify_mmsb.do`

**Interfaces:**
- Consumes: Tasks 4, 6, 7.
- Produces: `_gracedr_mmsb probs, study(str)` returns `r(probs)` and `r(phase)` (quota,
  runin, bound, msb-biased, msb-random).

- [ ] Certification: forced assignment when only one arm is short (phase quota); bound
  excludes arms with `D >= size_bound`; with two arms, no forced checkpoints and no run-in
  the result equals the plain MSB rule; probabilities sum to 1 in every phase.
- [ ] Implement steps 1 to 5 of `docs/ImplementationPlan.md` "Modified MSB probabilities".

## Task 9: gracedr randomize

**Files:** `stata/ado/gracedr_randomize.ado`, `stata/help/gracedr_randomize.sthlp`,
`stata/cert/certify_randomize.do`

**Interfaces:**
- Consumes: Tasks 2, 3, 6, 8, 10.
- Produces: `gracedr randomize, study(str) id(str) [graphs] <balance options>`. It prints
  the id, arm, code, and group-size table, and appends to `participants`, `codes`, `audit`,
  and `state`.

- [ ] Certification: a full 40-participant run with a fixed seed matches stored reference
  results exactly; duplicate id, full enrollment, and no unused code each stop with the
  intended message and change nothing; a failure in the middle leaves the previous files
  intact; `graphs` draws two graphs and without it none are drawn.
- [ ] Implement, writing all datasets only after the draw succeeds.

## Task 10: Tables and graphs

**Files:** `stata/ado/_gracedr_tables.ado`, `_gracedr_graphs.ado`,
`stata/cert/certify_tables.do`

**Interfaces:**
- Produces: `_gracedr_tables groupsize` and `balance` (display and return matrices),
  `_gracedr_graphs imbalance` and `smd`, each with `saving(str)`. SMD formulas as in
  `docs/ImplementationPlan.md` "Tables and plots".

- [ ] Certification: hand-computed binary and continuous SMD cases, a zero denominator gives
  0, the categorical SMD is the largest over its levels, and the group-size table's
  next and final targets match the checkpoints.
- [ ] Implement.

## Task 11: gracedr status, override, audit, replay

**Files:** `stata/ado/gracedr_status.ado`, `gracedr_override.ado`, `gracedr_audit.ado`,
`gracedr_replay.ado`, four help files, `stata/cert/certify_ops.do`

**Interfaces:**
- Consumes: Tasks 2, 3, 9, 10.
- Produces: the four subcommands as in the spec section 5.

- [ ] Certification: filters `from`, `to`, `checkpoint`, `vars` and their conflict errors;
  override voids the old code, draws a new unused code, and logs both; unknown id, same arm,
  and empty reason stop with messages; replaying every assignment of the 40-participant run
  reports a match.
- [ ] Implement.

## Task 12: Comparator rules

**Files:** `stata/ado/_gracedr_rules.ado`, `stata/cert/certify_rules.do`

**Interfaces:**
- Produces: `_gracedr_rules srs|blocks|minimization|msb, study(str)` returning `r(probs)`,
  as in `docs/ImplementationPlan.md` "Comparators".

- [ ] Certification: SRS equals the target proportions; blocks of size `2 * sum(ratio)`
  allocate exactly per block; minimization picks the minimizing arm with probability 0.8;
  MSB has no size vote, no quota, and no bound.
- [ ] Implement. This task has no dependence on Tasks 9 to 11 and can run in parallel.

## Task 13: Generators, metrics, and gracedr simulate

**Files:** `stata/ado/_gracedr_generate.ado`, `_gracedr_metrics.ado`, `gracedr_simulate.ado`,
`stata/help/gracedr_simulate.sthlp`, `stata/cert/certify_simulate.do`

**Interfaces:**
- Consumes: Tasks 4, 7, 8, 12.
- Produces: `gracedr simulate, [study(str)] methods(str) nsims(int) seed(int)
  [generator(iid|drift)] [saving(str)]`, the long results dataset (`sim`, `method`, `metric`,
  `value`), and the summary table (mean, sd, 95th, 99th, max).

- [ ] Certification: the same seed gives identical results; all methods see the same
  participant streams; `drift` ends at the requested end-of-enrollment values; `study()`
  reads only `design.dta` and writes nothing in the folder; each metric is hand-checked on
  a six-participant case.
- [ ] Implement a single loop without a parallel option.

## Task 14: Encryption utility (independent, parallelizable)

**Files:** two ado-files and two help files (names chosen by the builder after checking
SSC and Stata for clashes), a Python helper in `stata/python/`, `stata/cert/certify_zip.do`

**Interfaces:**
- Produces: one command saves the dataset in memory to an AES-256 zip and erases the
  temporary file; the other loads a dataset from such a zip. The password comes from
  `GRACEDR_PASSPHRASE`, otherwise from a masked Python pop-up. No `password()` option.

- [ ] Certification: round trip equals the original; a wrong password fails and loads
  nothing; no plain `.dta` remains after either command, including after an error; a missing
  `pyzipper` gives the install message; the password never appears in the log.
- [ ] Implement with Stata's Python integration.

## Task 15: Encrypted studies

**Files:** modify `_gracedr_study.ado`, `gracedr_setup.ado`, the help files;
`stata/cert/certify_encrypted.do`

**Interfaces:**
- Consumes: Tasks 2 and 14. Produces: `gracedr setup, ... encrypt` and a study whose
  datasets are all encrypted zips, read and written through the utility with the same
  `.tmp`, `.bak`, and rename pattern.

- [ ] Certification: the Task 9 run repeated on an encrypted study gives the same reference
  results; an error mid-write leaves no plain file; the wrong password stops every command.
- [ ] Implement.

## Task 16: Packaging

**Files:** `stata/gracedr.pkg`, `stata/stata.toc`, `stata/cert/certify_install.do`

- [ ] Certification: `net install gracedr, from(<path to stata folder>) replace` into a
  scratch directory installs every ado-file, help file, and data file, and `gracedr setup`
  runs from there.
- [ ] Write the package files.

## Task 17: Replication package

**Files:** `SJarticle/replication/` with `run-all.do`, numbered do-files, `README.md`,
`.gitignore`, stored logs in `SJarticle/replication/logs/`

- [ ] The do-files install `gracedr` from the repository, install `pyzipper`, and
  reproduce every table and figure of the article. The README lists the zip command and the
  caveats, as in `JSSarticle/replication/README.md`.
- [ ] Verify: a run from an unzipped copy exits cleanly and the output matches the stored
  logs.

## Task 18: The Stata Journal article

**Files:** `SJarticle/article.tex`, `references.bib`, `SJarticle/README.md`

- [ ] Write the article with Grace Huiyi Ma as first author and James W. Hardin as
  corresponding author, covering the method, the commands, the encrypted dataset
  development, and the simulation results from Task 17. Compiles with the Stata Journal
  class. The card lists the sections and the user supplies any journal-specific formatting.

## Task 19: Project documents

**Files:** `ProjectDescription.md`, `ProjectReport.md`

- [ ] Add the Stata work to both documents, and keep the existing R and JSS content.

## Order and dependencies

1 first. Then 2, 3, 4 in any order. Then 5 after 2, 3, 4. Then 6, 7 in any order. 8 after
4, 6, 7. 10 after 2, 4. 9 after 8 and 10. 11 after 9. 12 any time after 4. 13 after 8 and
12. 14 any time after 1. 15 after 9 and 14. 16 after 11 and 13. 17 after 13 and 16. 18 after
17. 19 any time after 5.
