# gracedr for Stata: design

This document describes the Stata version of the graceDR package. It comes from a planning
conversation with James Hardin and from his specification, `StataAddition.md`. A builder
should be able to plan the work from this document alone. Decisions made by the user are
stated as decisions. Calls made by the author of this document are marked **(my call)**.

## 1. Intent

graceDR (R) randomizes participants one at a time into treatment arms. It keeps groups the
right size and balanced on the participants' characteristics (modified minimal sufficient
balance, MMSB). Only the unblinded person runs it. This work builds the same method in
Stata 19 so that a Stata user does the same things an R user does, and it adds a Stata
Journal article with a replication package.

Success means:

- A Stata user can define a study, randomize participants one at a time, view balance, make
  and audit overrides, replay any past assignment, and run simulations, with behavior that
  follows the R package.
- A trial can be stopped and picked up later by pointing the commands at its study folder.
- The Stata package, its tests, and its article can all be rebuilt from this repository.

## 2. Goals, non-goals, anti-goals

Goals:

- The same method and the same workflow as the R package, in a Stata idiom.
- An optional encryption utility for saving and using datasets, built on Python.
- Linting and certification that run on every pull request and every change to `main`.
- A Stata Journal article (first author Grace Huiyi Ma, corresponding author James W.
  Hardin) and a replication package.

Non-goals:

- No connection to a trial database such as REDCap. The user copies the participant id and
  the treatment code into their own database.
- No matching of results between R and Stata. R and Stata use different random number
  generators. Each language is only expected to give identical results to itself on
  different machines.
- No support for Stata versions before 19, and no Mac or Linux testing.
- No graphical user interface and no dialog files.

Anti-goals (failure even if it technically works):

- A Stata command that behaves differently from the R function in a way the user did not
  ask for, such as a different rule for forcing assignments.
- A plain-text copy of a dataset that the user asked to be encrypted left on disk.
- Any password written to the log, the study folder, or the repository.

## 3. Constraints

- Everything is built on this Windows machine, in `C:\Users\James\code\grace`. Stata is
  StataMP 19 at `C:\Program Files\StataNow19`. Additions to Stata live in
  `C:\Users\James\dropbox\ado\personal` and `C:\Users\James\dropbox\ado\plus`.
- The user's global rules apply: work in worktrees on card branches, PR titles
  `[GRACE-n] Title`, `make pre-pr` before every push, no comments in code, lines under 100
  characters, no real data, cards written so a smaller model can implement them.
- Linter: `stata_linter`. Tests: a certification script, not a test framework.
- Makefile targets: `format`, `lint`, `test`, `pre-pr`.
- The first Jira card sets up CI for the Stata checks (section 9).
- The user's repository, `BiostatDoc/graceDR`, is public. Examples use made-up data only.
- Work goes to `main` through normal PRs. There is no long-lived Stata branch. The Stata
  files are kept apart from the R package and left out of the R build.

## 4. Repository layout

```
grace/
├── stata/
│   ├── ado/        gracedr.ado, one ado-file per subcommand, the encryption utility
│   ├── help/       one .sthlp file per command
│   ├── data/       example treatment codes and example participants
│   ├── cert/       certification do-files and stored reference results
│   ├── gracedr.pkg, stata.toc
│   └── Makefile    format, lint, test, pre-pr
├── SJarticle/      Stata Journal article and its replication package
└── (the R package, JSSarticle/, docs/, as now)
```

**(my call)** `stata/` and `SJarticle/` are added to `.Rbuildignore`. The root `make pre-pr`
runs the R checks and then `make -C stata pre-pr`, always. It fails on a machine without
Stata, since a check that silently skips would weaken `pre-pr`. CI does not call the root
`pre-pr`. The hosted R jobs call the R targets, and the self-hosted job calls the Stata
targets (section 9).

## 5. The commands

All commands are subcommands of `gracedr`, for example `gracedr setup`. Every subcommand
takes `study(folder)`, the single folder that holds the study's files. No other path
option is needed to find a study.

| Subcommand | R counterpart | Purpose |
|---|---|---|
| `gracedr setup` | `grace_design`, `create_trial` | Define a study and create its files |
| `gracedr randomize` | `randomize` | Assign one participant |
| `gracedr status` | `trial_status` | Group sizes, balance table, and graphs |
| `gracedr override` | `override_assignment` | Change one assignment, with a reason |
| `gracedr audit` | `audit_log` | List the audit log |
| `gracedr replay` | `replay_assignment` | Redo a past draw and report whether it matches |
| `gracedr simulate` | `simulate_trials` | Simulate trials for one or more methods |
| `gracedr codes` | `read_codes` | Check and load a treatment codes file |

The encryption utility is a separate, independent command (section 7). It is not a
subcommand and it does not know about randomization.

### Studies and the study folder

A study folder holds five datasets with fixed names (the fifth, `state.dta`, is described
under "Random numbers"):

- `design.dta`: the study definition, one row per setting (a name column, a value column,
  and an order column). It is a dataset and not a set of characteristics, so any item can
  change in the future. It holds the sample size, arm labels, ratio, weights, `p_star`,
  `xi`, run-in size, forced checkpoints, size bound, run-in method, and the balance
  variables in order. Each balance variable has a type (categorical or continuous) and
  its levels.
- `participants.dta`: the dynamic dataset. One row per participant, in enrollment order,
  with the sequence number, id, one variable per balance variable, arm, treatment code (or
  missing), the allocation probabilities, the phase, the random number generator state used
  for the draw, and the time (UTC).
- `codes.dta`: the treatment codes with status (`unused`, `used`, `voided`) and the id.
- `audit.dta`: the append-only audit log: time, action (`create`, `randomize`,
  `override`), id, old, new, and reason. **(my call)** `old` and `new` hold the arm, and
  there are separate `old_code` and `new_code` columns. A `randomize` row has an empty
  `old`.

`gracedr setup` refuses to run if the study folder already holds a study.

### Setup

```
gracedr setup, study(folder) n(#) arms(string) [ratio(numlist) weights(numlist)
    pstar(#) xi(#) runin(#) runinmethod(tilted|rar) forcedat(numlist) sizebound(#)
    categorical(...) continuous(...) codes(file) seed(#)]
```

Defaults and validation match the R `grace_design` (see section 3 of
`docs/ImplementationPlan.md`): same defaults, same run-in size rule, same errors. The
balance variables are declared in order, and the order is stored. **(my call)** The exact
option syntax for declaring variables, for example `categorical(sex: male female)` and
`continuous(age)`, is left to the builder to fix, as long as it records name, type, levels,
and order.

`codes()` accepts a CSV or a Stata dataset with columns `code` and `arm`, as decided by the
user. The checks follow R: no empty codes, no duplicates, and every arm known.

### Randomize

```
gracedr randomize, study(folder) id(string) <one option per balance variable> [graphs]
```

Participant values are given as one option per balance variable, named after the variable:
`gracedr randomize, study(folder) id(P041) sex(male) age(45)`. This is a decision by the
user. Stata's `syntax` cannot declare options whose names come from the study, so the
command catches the remaining options and parses them itself against `design.dta`.

Stop with a clear message on a missing, repeated, or unknown balance variable, an unknown
level, a non-numeric value for a continuous variable, a duplicate id, a full enrollment,
and when no unused code exists for the drawn arm. **(my call)** Option order does not
matter, since each option is named.

Algorithm: the same as R's `mmsb_probs` (quota, run-in, bound, votes, tilt, draw), with the
same constants and phases. The balance vote tests use Pearson chi-square for categorical
variables, and Welch's t-test (two arms) or Welch's one-way test (more arms) for continuous
ones. **(my call)** The R source in `R/` is the specification for ties, missing values,
zero denominators, and constants, and the builder reads it. If Stata has no direct Welch
one-way command, the builder codes it. Because the user does not want any R-to-Stata
comparison, the certification checks for these rules are written and hand-derived for
Stata only. The user can reverse this later if fixed-input probability checks against R
output are wanted.
After each assignment the command prints the id, arm, code, and the group-size table, and
adds the participant to `participants.dta`, the code status to `codes.dta`, and a row to
`audit.dta`. With the `graphs` option it also draws the imbalance and SMD graphs. Graphs
are drawn only when asked (user decision).

### Other commands

- `status` prints the group-size table (arm, n, percent, target at the next checkpoint,
  final target) and the balance table (per variable and level, `n (pct)` or `mean (sd)`
  per arm, and the largest absolute SMD). It takes the same filters as R (`from`, `to`,
  `checkpoint`, `vars`) and the `graphs` option, plus `saving(filename)` for graphs.
- `override` takes `id`, the new `arm`, and a required `reason`. A used code is marked
  `voided` and never reused, and a new unused code is drawn for the new arm. Both values
  go in the audit row.
- `audit` lists the audit dataset.
- `replay` recreates one past draw from its stored random number generator state and the
  data before it, and reports whether it matches the stored arm.
- `codes` checks a codes file without needing a study.

### Random numbers

R keeps a separate random stream per trial and does not disturb the user's own stream.
Stata commands must do the same: save the user's seed state, install the trial's state,
draw, store the new state in the study files, and restore the user's state. **(my call)**
Use `c(rngstate)` and `set rngstate` with Stata's default generator. Like R, each
participant row stores the state in force before that participant's draw, and a one-row
`state.dta` in the study folder holds the current state, the seed, the generator name, and
a format version. The state string is thousands of characters long, so it is stored in a
`strL` variable. `replay` installs a row's stored state, redoes the draw from the data
before it, and compares the arm. The certification script checks that a fixed seed gives
the same draws on repeated runs and on a second machine. Results are required to match
across machines for the same seed (section 8), not across R and Stata.

**Draw and commit (decision of the user, 2026-11-14).** A draw takes one uniform number from the
study's stored state and uses it to choose the arm from the allocation probabilities. When the
study has treatment codes, the same draw takes a second uniform number from the same state and
uses it to choose among the unused codes of that arm. One stored state therefore reproduces both
the arm and the treatment code, and `replay` checks both. The draw has a `nostore` option. With it,
the new state is returned and `state.dta` is not changed. A separate `commit` subcommand writes a
given state to `state.dta`. Its option `from()` names the state that the draw started from, and
`commit` refuses to write if `state.dta` no longer holds that state. `randomize` and `override`
draw with `nostore`, write the participants, codes, and audit files, and commit the new state
last. If an earlier write fails, the state is unchanged, so the draw can be repeated and gives the
same arm and code. Neither the draw nor the commit changes the user's own random number state.

### Simulation

```
gracedr simulate, study(folder) | <design options> methods(string) nsims(#) seed(#)
    [generator(iid|drift) ...] [saving(filename)]
```

Methods are the same five as R: `mmsb`, `srs`, `blocks`, `minimization`, `msb`. Virtual
participants are generated from distributions the user specifies for each balance variable
(user decision), with `iid` and `drift` built in, following R's `design_generator`,
`example_generator_iid`, and `example_generator_drift`. All methods see the same
participant streams. The metrics are the same as R's `trial_metrics`: maximum and
per-variable absolute SMD at the run-in, at each checkpoint and at the end, group-size
deviations, percent of deterministic assignments, longest run of forced assignments, and
the correct-guess probability. Results go to a dataset with long form `sim`, `method`,
`metric`, `value`, and a summary table (mean, sd, 95th and 99th percentiles, max) is
displayed. There is no parallel option. **(my call)** Simulation runs trials one at a time
in a loop. With `study(folder)` the command reads only `design.dta` and writes nothing to
the folder. Without it, the same design options as `gracedr setup` define the design
through one shared parser. **(my call)** Each balance variable's distribution is given by
a per-variable option (category probabilities, or a mean and sd, plus end-of-enrollment
values for `drift`). User-written generator programs are not part of the first release.

## 6. Treatment codes

A list of treatment codes is generated and kept in a file. An example list ships with the
package in `stata/data/`, and the example matches the R package's `example_codes.csv`
(200 rows, columns `code` and `arm`). A participant's treatment code and id are what the
user copies into their own trial database.

## 7. Encryption utility

Stata has no built-in encrypted files. The user decided on a separate, independent
utility, built on Python, and agreed that users install the Python package themselves.

- One command saves a dataset to a temporary file, zips it with a password, and erases the
  temporary file. Only the zip file remains. Another command unzips to a temporary file,
  loads the data, and erases the temporary file.
- The zip uses AES-256 through the Python package `pyzipper`. Stata runs it through its
  Python integration, so the password stays in memory and is not put on a command line.
- The utility does not know about GRACE. The randomization commands may call it through an
  optional `encrypt` option. Encryption is never required. **(my call)**
- **(my call)** A study is either plain or encrypted, chosen at `gracedr setup`. An
  encrypted study stores every dataset in its folder as an encrypted zip. A write follows
  R's pattern: write the new file to a `.tmp` name, keep the current file as `.bak`, then
  rename. Temporary plain-text files are erased on every exit path, including errors.
  This work comes last in the card order.
- A clear error message tells the user how to install `pyzipper` and which Python Stata
  is configured to use (`set python_exec`).
- The password is never stored. User decision: the commands read it from the environment
  variable `GRACEDR_PASSPHRASE`. If that is not set, a masked pop-up prompt opens through
  Python. There is no `password()` option, because Stata echoes command lines into the log
  and the command history. **(my call)** The builder checks that the password never
  appears in the log, in `set trace` output, or in a Stata macro that gets displayed.

Names for the two commands are left to the builder. They must not clash with existing
Stata or SSC commands.

## 8. Certification

A certification script replaces a test framework. It is a set of do-files run by
`make test` under Stata 19 in batch mode. The user's decision: no check compares R to
Stata. The checks are:

- **Same seed, same result.** A fixed seed gives identical datasets on repeated runs, and
  identical stored results on other machines. Reference results produced by the Stata
  implementation itself are stored in `stata/cert/` and compared exactly.
- **Rules that must hold:** group sizes are exact at forced checkpoints, probabilities
  stay within bounds, an override is logged and its code is voided, replaying every
  logged assignment gives the same arm, and the error cases in section 5 stop the command
  with the intended message.
- **Encryption utility:** round trip (save, use, compare), wrong password fails, no plain
  file remains, and a missing `pyzipper` gives the install message.
- **Examples in the help files run without error.**

## 9. CI and the first card

The first Jira card sets up automation for the Stata checks and builds nothing else
except what the checks need to run: **(my call)** a placeholder ado-file, a placeholder
certification do-file that passes, and the `stata/Makefile`, so the workflow and its check
names exist before any real Stata code. Stata
cannot run on GitHub's hosted runners because it needs a license. The user decided to use a
self-hosted runner on this Windows machine for pull requests from this repository only, so
a fork cannot run code on the machine. The workflow runs `stata_linter` and the
certification script on every such PR and on every change to `main`. The existing R checks
keep running as they do now.

Needs the user: registering the runner (GitHub gives a token that Claude should not hold),
installing `stata_linter` and the Python package, and confirming that the machine is on
when PRs are opened. The card lists each as a Needs You step with exact commands.

## 10. Article and replication package

- A new article for the Stata Journal in `SJarticle/`, similar in scope to the JSS article
  in `JSSarticle/`. First author Grace Huiyi Ma (junior, Dutch Fork High School STEM Magnet
  Program, Irmo, South Carolina). Corresponding author James W. Hardin (Professor of
  Biostatistics, Department of Epidemiology and Biostatistics, University of South
  Carolina, Columbia, SC).
- The article includes the development of saving and using encrypted Stata datasets.
- A replication package for the article reproduces every table and figure. **(my call)** It
  needs Stata 19 to run, and it includes stored logs of the author's run for readers
  without a license.
  is a folder with do-files and a README, in the style of `JSSarticle/replication`, and it
  lists the Python package setup. The builder decides the exact tooling and how the
  Stata Journal's LaTeX class is handled.
- `ProjectDescription.md` and `ProjectReport.md` are updated to cover the Stata work.

## 11. Distribution

**(my call)** `stata/gracedr.pkg` and `stata/stata.toc` allow `net install` straight from
the GitHub repository. The user has searched SSC and other places for "grace" and found no
exact hit for `gracedr`. Development installs go to `C:\Users\James\dropbox\ado\personal`.

## 12. Left to the builder

- Card order and sizes. The first card is the CI card (section 9).
- The exact option syntax of each subcommand, within section 5.
- The stored format of the random number generator state and the audit rows.
- Names of the encryption commands.
- Splitting the work into small ado-files, one subject per file.
