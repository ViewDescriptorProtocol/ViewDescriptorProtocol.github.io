SHELL := /usr/bin/env bash

start: ## Start mkdocs server
	@if [[ -f ".venv/bin/activate" && -x ".venv/bin/python" ]]; then \
		echo "Using virtualenv Python"; \
		. .venv/bin/activate; \
		python -m mkdocs serve -a localhost:8884; \
	else \
		echo "Virtualenv not found. Using system Python"; \
		python -m mkdocs serve -a localhost:8884; \
	fi

build: ## Build mkdocs site
	@if [[ -f ".venv/bin/activate" && -x ".venv/bin/python" ]]; then \
		. .venv/bin/activate; \
		python -m mkdocs build; \
	else \
		python -m mkdocs build; \
	fi

help: ## Help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sed 's/Makefile://' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
