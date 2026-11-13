.PHONY: format lint test pre-pr

format:
	bash scripts/format.sh

lint:
	bash scripts/lint.sh

test:
	bash scripts/test.sh

pre-pr: format lint test
