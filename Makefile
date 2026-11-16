UNAME := $(shell uname -s)

ifneq ($(findstring MINGW,$(UNAME))$(findstring MSYS,$(UNAME)),)
ifeq ($(LOCALAPPDATA),)
export LOCALAPPDATA := $(shell cygpath -m "$$HOME/AppData/Local")
endif
ifeq ($(TEMP),)
export TEMP := $(LOCALAPPDATA)/Temp
endif
ifeq ($(TMP),)
export TMP := $(LOCALAPPDATA)/Temp
endif
ifeq ($(PROCESSOR_ARCHITECTURE),)
ifeq ($(shell uname -m),x86_64)
export PROCESSOR_ARCHITECTURE := AMD64
else
export PROCESSOR_ARCHITECTURE := ARM64
endif
endif
endif

.PHONY: format lint test check stata-pre-pr pre-pr cran-local cran-win-devel cran-rhub

format:
	Rscript -e "styler::style_pkg()"

lint:
	Rscript -e "pkgload::load_all(quiet = TRUE); \
		l <- lintr::lint_package(); \
		print(l); \
		quit(status = length(l) > 0)"

test:
	Rscript -e "devtools::test(stop_on_failure = TRUE)"

check:
	Rscript -e "devtools::check(error_on = 'warning', args = '--no-manual')"

stata-pre-pr:
	$(MAKE) -C stata pre-pr

pre-pr: format lint test stata-pre-pr

cran-local:
	Rscript dev/check-local.R

cran-win-devel:
	Rscript dev/check-win-devel.R --yes

cran-rhub:
	Rscript dev/check-rhub.R --yes
