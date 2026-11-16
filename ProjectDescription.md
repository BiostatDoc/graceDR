# graceDR: project description

graceDR is an R package that randomizes clinical trial participants one at a time into one of
`k` groups while keeping the groups balanced on chosen baseline variables and, at chosen
enrollment totals, exactly the prescribed sizes. It was built by Dr. James W. Hardin (Professor
of Biostatistics, Department of Epidemiology and Biostatistics, University of South Carolina)
and Grace Huiyi Ma (a junior in the Dutch Fork High School STEM Magnet Program, Irmo, South
Carolina), with Claude, from a written specification. Version 0.1.0 is licensed under GPL-3 and
lives in the public repository `BiostatDoc/graceDR`.

The package is named `graceDR`, not `grace` as in the specification, because the name `grace`
conflicts with an archived CRAN package named Grace.

A Stata 19 version of the package, the command `gracedr`, is in the same repository. It
is described in the section "The Stata version".

## What the package does

The package modifies the minimal sufficient balance (MSB) algorithm of Zhao, Hill, and Palesch
([doi:10.1177/0962280212436447](https://doi.org/10.1177/0962280212436447)). At setup the user
specifies:

- the variables over which balance is wanted (for example sex, race, and age category) and the
  values each can take, categorical or continuous;
- a weight for each variable, which expresses its importance to the balance;
- the randomization proportions for the groups, for any number of groups and any ratio;
- the enrollment totals at which the proportions must hold exactly;
- an optional file of treatment codes, and a seed.

At each randomization the user supplies a participant ID and the values of the balance
variables. The program draws the assignment, saves the record, and, if codes are used, returns
an unused treatment code for the assigned group.

The modifications to MSB are:

- **Weights.** Balance variables carry weights that are rescaled to add to one.
- **Biased coin.** The coin probability is an option and defaults to the 0.65 recommended for
  the original algorithm.
- **Run-in.** The first `max(10, ceiling(0.10 N))` participants, rounded up to a size that the
  allocation ratios divide exactly, are held to the prescribed proportions. For two equal groups
  and a run-in of 10, that means exactly 5 and 5.
- **Forced totals.** The prescribed proportions are also forced at any list of enrollment totals
  and at the final sample size.
- **Group size controls.** A group-size vote and a bound on how far a group may drift from its
  target (3 by default) pull a group that falls behind back toward its target.
- **Many groups.** With two groups the rule reduces to the original MSB algorithm.

A missing balance value is allowed. That variable does not vote for that participant, and the
program prints a warning. Deterministic assignments (probability 0 or 1) near the enrollment
totals are expected, because they keep the prescribed proportions.

## Who uses it

Only the unblinded statistician uses the program. One statistician runs every randomization from
one computer, so the program does not handle two people at once and does not lock files. The
statistician can:

- randomize each participant, with a participant ID that can be any string and is rejected if it
  repeats;
- print the current group sizes and balance without randomizing anyone;
- override an assignment through a function that records the time, the old value, the new value,
  and a required reason;
- replay any past assignment for an audit;
- run simulations of the algorithm against other methods.

Users never edit the saved trial by hand.

## Outputs

After each randomization, and from the status-only function, the program returns data frames and
ggplot objects and prints a short summary:

- a group size table with the count and percent in each group and the target count at the next
  enrollment total;
- a covariate balance table with counts and percents by group for categorical variables, the mean
  and standard deviation by group for continuous variables, and a standardized mean difference
  (SMD) for each variable;
- a cumulative imbalance plot showing each group's deviation from its target count by enrollment
  order, with the enrollment totals marked;
- an SMD (Love) plot of the absolute SMD of each variable, with a reference line at 0.1.

The status report can be limited to an enrollment range (for example participants 41 to 80), to
the state at a named enrollment total, or to a subset of the balance variables.

## Metrics

The simulation reports these measures for each allocation method, with the 95th and 99th
percentiles and the maximum over the simulated trials to show worst cases:

- **Covariate balance.** The largest absolute SMD over the variables, and the SMD of each
  variable, at the end of the run-in, at each enrollment total, and at the end. For a binary
  indicator with proportions 0.60 and 0.50 in the two groups, the SMD is
  (0.60 - 0.50) / sqrt((0.60 x 0.40 + 0.50 x 0.50) / 2) = 0.10 / 0.495, which is 0.20.
- **Size deviation.** The absolute difference between a group's count and its target count, at the
  same points. With 7 participants and two equal groups the targets are 4 and 3, with the extra
  place going to the first group.
- **Predictability.** The percent of assignments that are deterministic, the longest run of
  consecutive forced assignments to the same group, and the Blackwell–Hodges correct-guess
  probability ([doi:10.1214/aoms/1177706973](https://doi.org/10.1214/aoms/1177706973)), which is
  the expected chance that a guesser who always picks the group furthest behind its target is
  right.

The comparison methods are simple random allocation, permuted blocks, Pocock–Simon minimization
([doi:10.2307/2529712](https://doi.org/10.2307/2529712)), and unmodified MSB. Synthetic
participants come from the trial's own balance variables, with level probabilities (or a mean and
standard deviation for continuous variables) and an optional linear drift from start to end values
over enrollment. A user can instead supply a function that returns participants. The package ships
example generators with and without drift.

## Data handling

- **One encrypted file.** The trial state is one `.rds` file encrypted with a passphrase. It holds
  the design, participants, assignments, treatment codes, random-number states, and audit log.
  The passphrase is entered each session or read from an environment variable, and is never
  written to disk.
- **Safe writes.** Before each write the program keeps a backup of the previous version.
- **Audit log.** Every randomization and override adds an entry to an append-only log.
- **Replay.** Setup takes a seed, and each record stores the random-number state used for its
  draw, so any assignment can be replayed. The program saves and restores the user's own
  random-number state, so it never disturbs their session.
- **Treatment codes.** The codes come from a CSV file with columns `code` and `arm`. Each
  randomization takes a random unused code for the assigned group and marks it used. If the group
  has no codes left, the program stops with an error and saves nothing. An example code list ships
  with the package.
- **Trial database.** The trial measurements live in a separate database, likely REDCap. The
  statistician copies the participant ID and treatment code into it by hand.
- **Size.** The specification targets trials up to N = 5,000 and simulations up to 10,000 trials.
  The package updates its state incrementally in simulation and offers optional parallel
  simulation. A single simulated trial of 5,000 participants ran in about 3 seconds on a laptop.

All examples and tests use small made-up data. The repository contains no real patient or
company data.

## Access

Only the unblinded statistician runs the program or sees its output, and access depends on the
passphrase for the encrypted file. The program produces nothing for blinded staff.

## Out of scope

- Connecting to the trial database.
- Several people randomizing at once, and file locking.
- Blinded exports and blinded reports.

## The Stata version

The package is also built for Stata 19 as the command `gracedr`, in the `stata` folder of
the same repository. It follows the same method and the same workflow as the R package, in a
Stata idiom. It runs on Windows only, and its design is in
`docs/superpowers/specs/2026-11-13-stata-addition-design.md`.

### Commands and study folder

Every command is a subcommand of `gracedr` and takes `study(folder)`, the one folder that holds
the study. The folder holds `design.dta` (the study definition), `participants.dta` (one row
per participant, in enrollment order), `codes.dta` (treatment codes and their status),
`audit.dta` (the append-only audit log), and `state.dta` (the current random-number state).
A trial can be stopped and picked up later by pointing the commands at its folder.

| Subcommand | What it does |
|:--|:--|
| `gracedr setup` | Defines a study and creates its files |
| `gracedr codes` | Checks and loads a treatment codes file |
| `gracedr randomize` | Assigns one participant, with one option per balance variable |
| `gracedr status` | Group sizes, balance table, and graphs, with the same filters as R |
| `gracedr override` | Changes one assignment and records a required reason |
| `gracedr audit` | Lists the audit log |
| `gracedr replay` | Redoes a past draw and reports whether it matches |
| `gracedr simulate` | Simulates trials under the five allocation methods |

An override marks the old treatment code `voided`, and a voided code is never reused. Graphs
are drawn only when the user asks for them. Simulation runs one trial at a time, reads only
`design.dta`, and writes nothing to the study folder. Each Stata file keeps to one subject:
one ado-file per subcommand, with the numerical code in Mata files.

### Random numbers and replay

Like the R package, each Stata trial keeps its own random-number stream. A command saves the
user's state, installs the trial's state, draws, stores the new state in the study files, and
restores the user's state. Each participant row stores the state in force before the draw, so
`gracedr replay` can redo any draw. A draw takes one uniform number for the arm and, when
treatment codes are used, a second from the same state for the treatment code, so one stored
state reproduces both. The new state is saved last, after the other files are written.

### Checks

Stata cannot run on GitHub's hosted runners because it needs a license. A self-hosted Windows
runner runs the Stata checks on every pull request from the repository and on every change to
`main`. `make -C stata pre-pr` runs three steps:

- `format` replaces tabs and removes trailing spaces;
- `lint` runs `stata_linter` on every ado-file and do-file;
- `test` runs the certification do-files in `stata/cert` under Stata 19 in batch mode.

The root `make pre-pr` runs the R checks and then the Stata checks, so it fails on a machine
without Stata. The certification checks that a fixed seed gives the same results on repeated
runs, that group sizes are exact at the forced totals, that probabilities stay within bounds,
that an override is logged and its code voided, that replaying every logged assignment gives the
same arm, and that each error case stops with its message. Each language is only expected to
match its own results across machines. The Stata certification does not use R output.

### Encrypted datasets

Stata has no encrypted files, so the package has a separate command pair, built on the Python
package `pyzipper`, that saves a dataset as an AES-256 zip file and loads it again. It does
not know about randomization. A study can be chosen at setup to be encrypted, in which case
every dataset in its folder is an encrypted zip. The passphrase comes from the environment
variable `GRACEDR_PASSPHRASE` or a masked pop-up, never from a command option, so it never
reaches the log.

### Distribution, article, and replication package

The package is installed with `net install gracedr` from the `stata` folder of the repository,
which holds the package file `gracedr.pkg` and the table of contents `stata.toc`. `net get gracedr`
copies the example data. The Stata Journal article is in `SJarticle/article.tex`. It has Grace
Huiyi Ma as first author and Dr. Hardin as corresponding author, and it includes the development
of saving and using encrypted Stata datasets. The journal's article tag, volume, and issue are
placeholders for the editors. Its replication package is in `SJarticle/replication`. It holds
do-files that install `gracedr` and `pyzipper` and reproduce every table and figure, and the log
of the run.

## How the work was managed

### From specification to pull requests

The work moved through four stages.

1. **Specification.** `Specification.md` describes what the product does, who uses it, the
   screens, the metrics, the data, access, known problems in an earlier version, and what is out
   of scope. It also fixes the engineering conventions: R 4.6 or higher, `styler`, `lintr`, and
   `testthat`, a Makefile with `format`, `lint`, `test`, and `pre-pr` targets, and a GPL-3 license.
2. **Implementation plan.** `docs/ImplementationPlan.md` turns the specification into a package
   layout, data shapes, the algorithm step by step, the comparison methods, the CI jobs, and an
   ordered list of work.
3. **Jira cards.** The plan was split into cards in the Jira project GRACE, grouped into six
   epics. Each card was written so that a smaller model could implement it without the planning
   conversation: it names the files to create or change, the commands, the function signatures,
   the data shapes, and the edge cases, and its acceptance criteria name the tests that must pass.
   Cards list which cards block them, so the work was done in dependency order.
4. **Pull requests.** Each card was implemented on its own branch in its own git worktree, named
   after the card, and delivered as one GitHub pull request titled `[GRACE-n] Card title`.

### Checks on every change

Before a branch is pushed, `make pre-pr` runs the formatter, the linter, and the tests, in that
order, and must pass. On GitHub, continuous integration runs three jobs on every pull request and
every change to `main`:

- `lint` checks the formatting with `styler` and runs `lintr`;
- `test` runs the `testthat` tests;
- `check` runs `R CMD check` with warnings treated as errors, on Linux and Windows.

The Stata work adds two jobs, `stata-lint` and `stata-test`, which run on a self-hosted Windows
runner because Stata needs a license. They run only for pull requests from the repository itself,
so code from a fork never runs on that machine.

The repository allows only squash merges and deletes each branch after it merges. A ruleset named
"Protect main" blocks deleting `main` and force pushes, requires a pull request, and requires the
`lint` and `test` checks to pass. Dr. Hardin reviews each pull request and approves it with a
comment before it is merged, and a card moves to Done only after its pull request merges. The
19 squashed commits that delivered the cards each list Claude Sonnet 5.5 as co-author.

### The local Stata runner

GitHub's hosted machines have no Stata license, so the Stata checks needed a machine that does.
The project's own Windows computer became that machine.

What was added:

- The GitHub Actions runner program, version 2.338.2, in a folder on the computer's C drive.
  `config.cmd` registered it to the repository with the default labels `self-hosted`, `Windows`
  and `X64`. The workflow in `.github/workflows/stata.yml` asks for `[self-hosted, windows]`, so
  only this runner takes the Stata jobs.
- A guard that keeps outside code off the machine: the Stata jobs run only for pull requests from
  the repository itself, never from forks.
- The tools the jobs call, all installed on that computer: Stata 19, the `stata_linter` package,
  Python with `pyzipper`, Git, and Git Bash from Rtools.

How it became an automatic service:

1. The first setup ran the runner by hand with `run.cmd` in a PowerShell window. The checks only
   ran while that window stayed open, and the answer to the setup question about installing a
   service had been No.
2. A short PowerShell script, run once from an administrator window, did the conversion. It first
   checked the Windows password against the account, with three tries and no changes if all
   failed, so a typo could not leave a half-configured runner. It then stopped the hand-run
   runner, asked GitHub for a fresh removal token and a fresh registration token with the
   `gh` login, removed the old registration, and registered the runner again with the options
   `--runasservice`, `--windowslogonaccount` and `--windowslogonpassword`. The tokens and the
   password were never written to a file.
3. The service runs as the user's own account, not the default `NETWORK SERVICE` account. Only
   the user's account can see the Stata license and ado-path, the Python packages, and the Git and
   Rtools setup. The service starts when the computer starts and shows as `Running` with start
   type `Automatic` in the Windows service list.
4. A re-run of the Stata workflow with no PowerShell window open passed both `stata-lint` and
   `stata-test`, which showed that the service can start Stata, the linter and Python.

What it gained:

- `stata-lint` and `stata-test` run on every pull request and every change to `main` with no one
  starting anything, so a pull request cannot reach review without the Stata certification.
- The checks use the real licensed Stata 19 that the package targets, not a substitute.
- No terminal window has to stay open.

Limits: the computer must be on and online for a check to start, and a check waits in the queue
while it is off. If the Windows password changes, the service logon must be
updated, either by running the script again or in the Windows services tool. Starting after a
reboot has not been tested.

### Jira cards and pull requests

The Jira project GRACE has six epics and 21 cards. This table lists each card with the pull
request that delivered it.

| Epic | Card | Title | Pull request |
|:--|:--|:--|:--|
| GRACE-1 Setup and CI | GRACE-7 | Package skeleton, Makefile, and CI | [#1] |
| | GRACE-8 | Add lint and test as required status checks | Settings only, no pull request |
| GRACE-2 Data loading | GRACE-9 | Balance variables, trial design, and checkpoints | [#2] |
| | GRACE-10 | Isolated random-number stream and file encryption | [#3] |
| | GRACE-11 | Trial file, audit log, and treatment codes | [#5] |
| GRACE-3 Calculations | GRACE-12 | Running balance state and value cleaning | [#4] |
| | GRACE-13 | MSB imbalance votes and biased-coin tilt for k arms | [#8] |
| | GRACE-14 | Checkpoint quotas, size bound, and modified MSB probabilities | [#9] |
| | GRACE-15 | Live randomization and audit replay | [#10] |
| | GRACE-16 | Assignment overrides with audit trail | [#11] |
| | GRACE-17 | Comparison allocation rules for simulation | [#12] |
| GRACE-4 Screens | GRACE-18 | Standardized mean differences and balance tables | [#7] |
| | GRACE-19 | Cumulative imbalance plot and SMD (Love) plot | [#13] |
| | GRACE-20 | Status report, filters, and print methods | [#15] |
| GRACE-5 Simulation | GRACE-21 | Synthetic participant generators and example design | [#6] |
| | GRACE-22 | Simulation engine and per-trial metrics | [#14] |
| | GRACE-23 | Simulation summary and parallel runs | [#16] |
| GRACE-6 Documentation and release | GRACE-24 | Example data, vignette, and README | [#17] |
| | GRACE-25 | Rewrite the JSS article from the new package | [#19] |
| | GRACE-26 | Project description and project report | This pull request |
| | GRACE-27 | CRAN readiness and version 0.1.0 | [#18] |

[#1]: https://github.com/BiostatDoc/graceDR/pull/1
[#2]: https://github.com/BiostatDoc/graceDR/pull/2
[#3]: https://github.com/BiostatDoc/graceDR/pull/3
[#4]: https://github.com/BiostatDoc/graceDR/pull/4
[#5]: https://github.com/BiostatDoc/graceDR/pull/5
[#6]: https://github.com/BiostatDoc/graceDR/pull/6
[#7]: https://github.com/BiostatDoc/graceDR/pull/7
[#8]: https://github.com/BiostatDoc/graceDR/pull/8
[#9]: https://github.com/BiostatDoc/graceDR/pull/9
[#10]: https://github.com/BiostatDoc/graceDR/pull/10
[#11]: https://github.com/BiostatDoc/graceDR/pull/11
[#12]: https://github.com/BiostatDoc/graceDR/pull/12
[#13]: https://github.com/BiostatDoc/graceDR/pull/13
[#14]: https://github.com/BiostatDoc/graceDR/pull/14
[#15]: https://github.com/BiostatDoc/graceDR/pull/15
[#16]: https://github.com/BiostatDoc/graceDR/pull/16
[#17]: https://github.com/BiostatDoc/graceDR/pull/17
[#18]: https://github.com/BiostatDoc/graceDR/pull/18
[#19]: https://github.com/BiostatDoc/graceDR/pull/19

## Where the project stands

The package has more than 800 passing test expectations, a vignette, a README, and a manuscript
for the Journal of Statistical Software in the `JSSarticle` folder. It is prepared for CRAN as
version 0.1.0.

The specification left one question open: whether the modifications to MSB improve performance
over the comparison methods. The manuscript reports simulations of 1,000 trials in each of four
settings (200 or 500 participants, with and without drift in the enrolled population):

- The modified procedure met the run-in and final group sizes in every trial. Unmodified MSB
  missed the final sizes by a mean of 5.7 to 10.7 participants.
- Its covariate balance was better than simple randomization and permuted blocks, and slightly
  worse than unmodified MSB.
- Minimization balanced covariates best in every setting, but its final group sizes were exact in
  fewer than half of the trials.
- Its expected correct-guess probability was 58.5% to 59.4%, compared with 70.8% for permuted
  blocks and 61.6% to 62.2% for minimization.

So the modifications deliver exact group sizes at chosen totals with less predictability than
permuted blocks, at a small cost in balance relative to MSB. They do not give better balance than
minimization in these simulations.

The Stata version has the commands `gracedr setup`, `codes`, `randomize`, `status`, `override`,
`audit`, `replay`, and `simulate`, each with a help file and a certification do-file. The
encrypted datasets (`encsave`, `encuse`, and encrypted studies), the installable package files,
the Stata Journal article, and its replication package are done.

## References

- Zhao W, Hill MD, Palesch Y (2015). Minimal sufficient balance: a new strategy to balance
  baseline covariates and preserve randomness of treatment allocation. *Statistical Methods in
  Medical Research* 24(6), 989–1002.
  [doi:10.1177/0962280212436447](https://doi.org/10.1177/0962280212436447)
- Pocock SJ, Simon R (1975). Sequential treatment assignment with balancing for prognostic
  factors in the controlled clinical trial. *Biometrics* 31(1), 103–115.
  [doi:10.2307/2529712](https://doi.org/10.2307/2529712)
- Blackwell D, Hodges JL Jr (1957). Design for the control of selection bias. *The Annals of
  Mathematical Statistics* 28(2), 449–460.
  [doi:10.1214/aoms/1177706973](https://doi.org/10.1214/aoms/1177706973)
