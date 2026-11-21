# Replication package for the gracedr Stata article

These do-files reproduce all tables and figures of the article, without the text. They install
`gracedr` from the repository, run the simulation study, and show the worked example of the
commands. All paths are relative to this folder.

## Requirements

- Windows with Stata 19. The package was tested on Windows only.
- Internet access, to install `gracedr` from GitHub and `pyzipper` from PyPI.
- Python, configured for Stata (`python query` shows it). The do-files install `pyzipper` into
  that Python with `pip` when it is missing.
- No Stata license? Read `logs/run-all.log`. It holds the output of the author's run.

## Steps

1. Unzip `replication.zip`. This creates the folder `replication`.
2. Start Stata and make this folder the working directory:

   ```stata
   cd "<path to>/replication"
   ```

3. Run everything:

   ```stata
   do run-all.do
   ```

   Or from a terminal in this folder:

   ```
   "C:/Program Files/StataNow19/StataMP-64.exe" /e do run-all.do
   ```

Run only `run-all.do`. Later files use the globals and the results of earlier files, so they do not
work one at a time.

`run-all.do` writes the log `logs/run-all.log` and runs these files in order:

| File | Content |
|------|---------|
| `00-setup.do` | Installs `gracedr` and its example files, installs `pyzipper`, sets the globals |
| `helpers.do` | Small programs used by the later files |
| `01-simulate.do` | Runs 1,000 trials in each of four settings and saves them in `results/` |
| `02-summarize.do` | Reads `results/` and computes the summaries |
| `03-package-tables.do` | The tables of commands and options |
| `04-package-demo.do` | The worked example of the commands, with the status graphs |
| `05-encrypted-demo.do` | The same study stored as encrypted zip files |
| `06-simulation-tables.do` | The tables of the simulation study |
| `07-figure.do` | The figure of the simulation study |

## Output

- `results/`: the simulation results (`sim_*.dta`, `summary_*.dta`) and the summaries
  (`stats_*.dta`, `paired_*.dta`).
- `figures/`: `status-imbalance.pdf`, `status-smd.pdf`, the Stata graphs `status_imbalance.gph` and
  `status_smd.gph`, and `tradeoff.pdf`.
- `studies/`: the study folders of the worked example, one plain and one encrypted.
- `data/`: the example codes and participants that `net get gracedr` copies.
- `logs/run-all.log`: the log of the run.

`data/`, `results/`, `figures/` and `studies/` start empty and their contents are not kept in git.
Every run overwrites them and deletes the two study folders first.

## Stored log

`logs/run-all.log` is the log of the author's run, without the first lines that Stata writes when
it opens a log and the last lines that it writes when it closes the log, because those hold the
path of the folder and the time. A new run gives the same text from the line `. do "00-setup.do"`
on, because the log holds no times and no paths. To compare, cut your own log the same way:

```
sed -n '/^\. do "00-setup.do"/,/^\. log close/p' logs/run-all.log | diff - <stored log>
```

A line that differs means that the Stata version or the `gracedr` version differs.

## Run time

The simulations rerun every time: 4,000 simulated trials in all. The whole run took about
9 minutes on the author's Windows computer. The worked example randomizes 40 participants
twice, and that takes the rest of the time. The number of trials, the seed, and the settings are
fixed in `00-setup.do` and `01-simulate.do` to match the article.

## The Python password

`05-encrypted-demo.do` sets the environment variable `GRACEDR_PASSPHRASE` inside Stata's Python to
a random value for the length of the file, so no pop-up opens and no password is written in a file
or in the log. The file puts back your own value when it ends. It does not end early on an error,
so after a failed run, restart Stata.

## Where gracedr comes from

`00-setup.do` runs `net install gracedr` and `net get gracedr` (into `data/`) from this address:

```
https://raw.githubusercontent.com/BiostatDoc/graceDR/stata-v1.0.1/stata
```

That is the release tag `stata-v1.0.1`, so every run installs the same package code and gives the
same log. To use a newer release, change `release` in `00-setup.do`. `pyzipper` is installed at
version 0.4.0, the version of the stored log, when it is missing. To install from another place,
such as a clone of the repository, set the environment variable `GRACEDR_SOURCE` to its `stata`
folder before you start Stata. The
install goes to your `PLUS` folder and replaces an older `gracedr` there. A copy of `gracedr` in a
folder that comes before `PLUS` in the ado-path, such as `PERSONAL`, would hide it, so
`00-setup.do` stops with an error when it finds one.

## Building the zip archive

For the maintainer. Check out an up-to-date `main`, then run this in the repository root:

```
git archive --format=zip --prefix=replication/ -o replication.zip HEAD:SJarticle/replication
```

Build the zip from git, not from the working folder. `git archive` leaves out the untracked and
ignored files, such as the old contents of `results/`, `figures/`, `studies/` and `data/`.
