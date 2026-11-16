source("dev/set-pandoc.R")

check_passes <- function(result) {
  only_new_submission <- length(result$notes) <= 1 &&
    all(grepl("New submission", result$notes))
  length(result$errors) == 0 &&
    length(result$warnings) == 0 &&
    only_new_submission
}

results <- c(
  check = check_passes(
    devtools::check(
      remote = TRUE,
      manual = TRUE,
      error_on = "never"
    )
  ),
  url_check = nrow(urlchecker::url_check(fail = FALSE)) == 0,
  spell_check = nrow(spelling::spell_check_package()) == 0
)

cat(paste0(names(results), ": ", ifelse(results, "PASS", "FAIL")), sep = "\n")
if (!all(results)) {
  quit(status = 1)
}
