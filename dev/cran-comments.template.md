## Test environments

* Local: <OS and version>,
  R <version>, fresh clone of the repository
  (`devtools::check(remote = TRUE, manual = TRUE)`)
* GitHub Actions: ubuntu-latest and windows-latest, current R release
  (`.github/workflows/ci.yml`)
* win-builder: <Windows version>,
  R Under development (<date and revision>)
* R-hub: <platform names>, <date>

## R CMD check results

<N> errors | <N> warnings | <N> notes

<One bullet per note, explaining it. For a first release: "This is a new submission.">

## Reverse dependencies

<"There are no reverse dependencies." for a first release>
