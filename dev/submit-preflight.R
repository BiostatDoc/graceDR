if (!file.exists("DESCRIPTION")) {
  cli::cli_abort("Run this script from the repository root.")
}

source("dev/set-pandoc.R")
Sys.setenv(GIT_TERMINAL_PROMPT = "0")

fields <- read.dcf("DESCRIPTION", c("Package", "Version"))
package <- fields[1, "Package"]
version <- fields[1, "Version"]
if (!grepl("^[A-Za-z][A-Za-z0-9.]*$", package) || !grepl("^[0-9][0-9.-]*$", version)) {
  cli::cli_abort("DESCRIPTION has an unusual Package or Version field.")
}
tag_name <- paste0("v", version)
cran_url <- paste0("https://CRAN.R-project.org/package=", package)

pass <- function(note = "") {
  list(ok = TRUE, note = note)
}

fail <- function(reason) {
  list(ok = FALSE, note = reason)
}

run_tool <- function(tool, args) {
  if (!nzchar(Sys.which(tool))) {
    stop(tool, " not found", call. = FALSE)
  }
  output <- suppressWarnings(system2(tool, args, stdout = TRUE, stderr = FALSE))
  status <- attr(output, "status")
  if (!is.null(status) && status != 0) {
    stop(tool, " exited with status ", status, call. = FALSE)
  }
  output
}

check_branch <- function() {
  branch <- run_tool("git", c("rev-parse", "--abbrev-ref", "HEAD"))
  if (branch %in% c("HEAD", "main")) {
    return(pass())
  }
  fail(paste0("on branch ", branch))
}

check_clean <- function() {
  changes <- run_tool("git", c("status", "--porcelain"))
  if (length(changes) == 0) {
    return(pass())
  }
  fail(paste(length(changes), "uncommitted or untracked paths"))
}

check_tag <- function() {
  tags <- run_tool("git", c("tag", "--points-at", "HEAD"))
  if (tag_name %in% tags) {
    return(pass())
  }
  found <- if (length(tags) == 0) "no tags" else paste(tags, collapse = ", ")
  fail(paste0("HEAD is not tagged ", tag_name, " (found ", found, ")"))
}

check_tag_pushed <- function() {
  refs <- run_tool("git", c("ls-remote", "--tags", "origin", tag_name))
  ref_name <- paste0("\trefs/tags/", tag_name)
  tag_line <- refs[endsWith(refs, ref_name)]
  peeled_line <- refs[endsWith(refs, paste0(ref_name, "^{}"))]
  if (length(tag_line) == 0) {
    return(fail(paste0(tag_name, " is not on origin")))
  }
  remote_commit <- sub("\t.*", "", c(peeled_line, tag_line)[[1]])
  head_commit <- run_tool("git", c("rev-parse", "HEAD"))
  if (remote_commit == head_commit) {
    return(pass())
  }
  fail(
    sprintf(
      "origin's %s is at %s but HEAD is %s",
      tag_name,
      substr(remote_commit, 1, 7),
      substr(head_commit, 1, 7)
    )
  )
}

check_maintainer <- function() {
  maintainer <- desc::desc_get_maintainer()
  if (length(maintainer) == 1 && grepl("@", maintainer, fixed = TRUE)) {
    return(pass())
  }
  fail("no maintainer email in DESCRIPTION")
}

check_comments <- function() {
  if (!file.exists("cran-comments.md")) {
    return(fail("cran-comments.md not found"))
  }
  lines <- trimws(readLines("cran-comments.md", warn = FALSE))
  headings <- c("## Test environments", "## R CMD check results")
  missing <- setdiff(headings, lines)
  if (length(missing) > 0) {
    return(fail(paste0("missing heading ", missing[[1]])))
  }
  if (any(grepl("<", lines, fixed = TRUE))) {
    return(fail("unfilled placeholder: a line contains <"))
  }
  pass()
}

check_news <- function() {
  if (!file.exists("NEWS.md")) {
    return(fail("NEWS.md not found"))
  }
  lines <- readLines("NEWS.md", warn = FALSE)
  if (any(startsWith(lines, paste0("# ", package, " ", version)))) {
    return(pass())
  }
  fail(paste0("no '# ", package, " ", version, "' heading in NEWS.md"))
}

check_urls <- function() {
  urls <- urlchecker::url_check(fail = FALSE, progress = FALSE)
  if (nrow(urls) == 0) {
    return(pass())
  }
  fail(paste(nrow(urls), "URLs failed"))
}

check_tarball <- function() {
  build_dir <- tempfile(paste0(package, "-build-"))
  dir.create(build_dir)
  path <- devtools::build(path = build_dir, quiet = TRUE)
  expected <- paste0(package, "_", version, ".tar.gz")
  if (!file.exists(path) || basename(path) != expected) {
    return(fail(paste("expected", expected)))
  }
  size_kb <- file.size(path) / 1024
  note <- sprintf("%s, %.0f KB", path, size_kb)
  if (size_kb >= 5000) {
    return(fail(paste0("over the 5000 KB limit: ", note)))
  }
  pass(note)
}

check_cran_version <- function() {
  code <- run_tool(
    "curl",
    c("-sL", "--max-time", "30", "-o", nullfile(), "-w", "%{http_code}", cran_url)
  )
  if (length(code) != 1 || !nzchar(code)) {
    return(fail("no response from CRAN"))
  }
  if (code == "404") {
    return(pass("not on CRAN yet"))
  }
  if (code != "200") {
    return(fail(paste("unexpected HTTP status", code)))
  }
  published <- utils::available.packages(repos = "https://cloud.r-project.org")
  if (!package %in% rownames(published)) {
    return(fail("CRAN page exists but the package is not in the index"))
  }
  cran_version <- published[package, "Version"]
  if (package_version(version) > package_version(cran_version)) {
    return(pass(paste("CRAN has", cran_version)))
  }
  fail(paste0("version ", version, " is not higher than CRAN's ", cran_version))
}

checks <- list(
  branch = check_branch,
  clean = check_clean,
  tag = check_tag,
  tag_pushed = check_tag_pushed,
  maintainer = check_maintainer,
  comments = check_comments,
  news = check_news,
  urls = check_urls,
  tarball = check_tarball,
  cran_version = check_cran_version
)

run_check <- function(check) {
  tryCatch(
    check(),
    error = function(e) fail(conditionMessage(e))
  )
}

report <- function(name, result) {
  status <- if (result$ok) "PASS" else "FAIL"
  detail <- if (nzchar(result$note)) paste0(" (", result$note, ")") else ""
  cat(name, ": ", status, detail, "\n", sep = "")
}

passed <- logical()
for (name in names(checks)) {
  result <- run_check(checks[[name]])
  report(name, result)
  passed <- c(passed, result$ok)
}

if (!all(passed)) {
  quit(status = 1)
}

address <- sub(".*<([^>]+)>.*", "\\1", desc::desc_get_maintainer())
cat("Preflight passed. To submit, run this yourself in R from this folder:\n")
cat("  devtools::submit_cran()\n")
cat("Then click the confirmation link that CRAN emails to ", address, ".\n", sep = "")
