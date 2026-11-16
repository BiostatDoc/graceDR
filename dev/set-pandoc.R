quarto_tools <- "C:/Program Files/Quarto/bin/tools"
if (!nzchar(Sys.getenv("RSTUDIO_PANDOC")) && dir.exists(quarto_tools)) {
  Sys.setenv(RSTUDIO_PANDOC = quarto_tools)
}
