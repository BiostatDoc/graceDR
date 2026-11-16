if (!identical(commandArgs(trailingOnly = TRUE), "--yes")) {
  cat("Usage: Rscript dev/check-win-devel.R --yes\n")
  quit(status = 2)
}

source("dev/set-pandoc.R")

notice <- paste(
  "This uploads the package to win-builder and emails the maintainer",
  "address in DESCRIPTION. Paste the email text into the PR."
)
cat(notice, "\n", sep = "")
devtools::check_win_devel()
