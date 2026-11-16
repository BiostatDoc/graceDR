if (!identical(commandArgs(trailingOnly = TRUE), "--yes")) {
  cat("Usage: Rscript dev/check-rhub.R --yes\n")
  quit(status = 2)
}

rhub::rhub_check(platforms = c("linux", "macos", "windows"))
