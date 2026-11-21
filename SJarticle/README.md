# The Stata Journal article

`article.tex` is the article about the Stata package `gracedr`, with `references.bib`. It is
written for the Stata Journal class `statapress`. The numbers in the tables, the listings, and
the figures come from the replication package in `replication/`, which holds the do-files and
the log of the run that made them.

## Sections

1. Introduction
2. The algorithm: votes, the biased coin, checkpoints, the run-in, and the fixed choices
3. The commands: setup, codes, randomize, status, override, audit, replay, and simulate, with a
   worked example
4. Encrypted datasets: `encsave`, `encuse`, the password, and encrypted studies
5. Simulation study: the design and the results (tables 3 to 6 and figure 2)
6. Computational details
7. Conclusions

The title page uses the placeholders of the journal (`st0001`, volume and issue). The editors of
the journal fill them in.

## The journal class files

The class files are not in this repository, because the Stata Journal site gives no licence to
redistribute them. Install them with Stata's own command. The folder must not exist yet:

```stata
net from https://www.stata-journal.com/production
net install sjlatex
sjlatex install using "C:/sjclass"
```

Then copy `statapress.cls`, `pagedims.sty`, `sj.sty`, `stata.sty`, and `sj.bst` from that folder to
this folder. `.gitignore` keeps them out of git. The first compile may install other packages, such
as `crop`, through your TeX distribution.

The same install also makes `sj.tex` (the author guide), `sj.bib`, `sj.version`, `tl.eps`,
and `tr.eps`. The article does not use them, and `.gitignore` keeps them out of git too.
`.gitignore` also keeps out the build output: `*.synctex.gz` and the `README.html`
previews. The article was built with MiKTeX and LuaLaTeX.

## Build

The article includes the figures that the replication package makes. Run the replication package
first (see `replication/README.md`), so that `replication/figures/` holds `status-imbalance.pdf`,
`status-smd.pdf`, and `tradeoff.pdf`. Then run this in this folder:

```
lualatex article
bibtex article
lualatex article
lualatex article
```

The listings and tables in `article.tex` are typed from the log `replication/logs/run-all.log`.
When the replication package changes, check them against a new log.
