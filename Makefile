.PHONY: install build run stop serve web acp logs clean test process plan generic lint

install:
	@echo "Nothing to install locally — containers are self-contained."

build:
	docker compose build
	docker compose --profile manual build

run:
	docker compose up -d

stop:
	docker compose down

serve:
	docker compose up -d opencode-serve

web:
	docker compose up -d opencode-web

acp:
	docker compose up -d opencode-acp

logs:
	docker compose logs -f

clean:
	docker compose down --remove-orphans -v

process:
	docker compose run --rm opencode-issue-processor

plan:
	docker compose run --rm opencode-plan-issue

generic:
	docker compose run --rm opencode-generic-worker

verify-quickstart:
	bash tests/verify-quickstart.sh

lint:
	shellcheck ./*.sh tests/*.sh tests/generic-worker/run-tests.sh tests/generic-worker/.harness/*.sh workflows/*/.harness/*.sh

test-generic-worker:
	bash tests/generic-worker/run-tests.sh

test: lint
	@for t in tests/test-*.sh; do \
		echo "=== Running $$t ==="; \
		(cd "$(CURDIR)" && bash "$$t") || exit 1; \
		echo ""; \
	done
	@# Run extended generic-worker test suite if GH_TOKEN is available
	@if [ -n "$${GH_TOKEN:-}" ]; then \
		echo "=== Running generic-worker extended tests ==="; \
		(cd "$(CURDIR)" && bash tests/generic-worker/run-tests.sh) || exit 1; \
	else \
		echo "=== Skipping generic-worker extended tests (GH_TOKEN not set) ==="; \
	fi
	@echo "All tests passed."