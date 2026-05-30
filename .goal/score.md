# Goal Scorecard

## Goal
Make this state-of-the-art GitHub repo understandable and user-friendly — comprehensive README, clear usage examples, documented architecture, self-service onboarding, and intuitive developer experience.

## Completion Rule
The goal is COMPLETE only if every attribute score is greater than or equal to its target score. If any attribute is below target, the result is INCOMPLETE.

## Attributes

| Attribute | Target | What 1 Means | What 10 Means | Evidence Required |
|---|---:|---|---|---|
| README Completeness | 9 | README is empty or a single sentence | README documents every container, every command, every environment variable, every port, every profile, every volume, every network detail, and all security rules — no question a new user has is unanswered | Render of the README; manual audit against a checklist of all containers/configs/env-vars/profiles/volumes/ports/rules — every item must be covered |
| Quickstart Friction | 9 | No quickstart; user must reverse-engineer docker-compose.yml to get started | A new user can copy-paste exactly 3 or fewer commands (no edits, no external knowledge) and have a running server verified by a curl health-check | A `make` or script-based quickstart path; a recorded terminal session or deterministic shell test proving `make build && make serve && curl .../health` succeeds with zero manual edits |
| Entrypoint Documentation | 8 | No `--help`, no entrypoint docs, no Makefile | Every Dockerfile's CMD and every mode's CLI flags are documented in README or inline comments; Makefile provides `make install`/`build`/`run`/`stop`/`logs`/`clean` with correct delegation; `--help` passthrough works for serve/web | Listing of every Makefile target; verification that each target works; `docker compose run --rm opencode-serve --help` returns opencode help (not an error) |
| Architecture & Design Rationale | 8 | No architecture docs; each container appears as a black box | README explains why each container exists, when to use which mode (serve vs web vs acp vs run), the design decision behind socat bridging, the profile/manual pattern, and volume-sharing strategy | A dedicated Architecture section in README or AGENTS.md that answers "why this design?" and "which container do I pick?" for every use case |
| Environment Variable Contract | 10 | Env vars are undocumented or only mentioned in Dockerfiles | Every environment variable consumed by every container/script is listed with its purpose, default value, required/optional status, and security notes (e.g., GH_TOKEN never enters context); no undocumented env-var references in any Dockerfile or shell script | Grep all Dockerfiles and `.sh` files for `\$[A-Z_]` / `\$\{[A-Z_]` patterns; cross-reference against a documented env-var table in README; report any undocumented variable as a forced INCOMPLETE |
| Test Coverage & Verifiability | 8 | No tests, no test harness, no CI | Every container has at least one integration-level test that builds the image and exercises its primary contract (serve: health-check; acp: JSON-RPC handshake; run containers: clone + exit-zero); tests are runnable via a single `make test` command | `ls tests/` shows per-container test files or scripts; `make test` completes with zero failures; each test actually validates runtime behavior (not just "builds ok") |
| Shell Script Robustness | 8 | Scripts fail silently, lack input validation, hardcode values | All shell scripts use `set -euo pipefail`, validate required env vars with meaningful error messages, handle missing dependencies gracefully, and avoid secret leakage | `shellcheck` passes on every `.sh` file; manual review confirms every script validates its required env vars before using them |
| Onboarding Self-Service | 8 | New user must guess how to install prerequisites, build, and verify | README states exact prerequisites (docker, gh CLI) with version hints; a single `make build` builds all images; a single `make test` validates the whole system; CI badge (if applicable) shows build status | A prerequisites section in README; `make build` succeeds from clean checkout; `make test` output showing all passing tests |

## Forced INCOMPLETE Conditions

- **Any undocumented environment variable**: grep of all Dockerfiles and shell scripts reveals an env-var reference (`$VAR`, `${VAR}`) that is not listed in an environment-variable table in README.
- **Shellcheck failures**: `shellcheck` reports any error-level (not just warning) finding on any `.sh` file in the repo root.
- **Broken minimal quickstart**: `make build && make serve` and `curl -u "opencode:changeme" http://localhost:4096/global/health` does not succeed on a clean checkout.
- **Zero tests**: No test files exist under `tests/` or no `make test` target exists.
- **README contradicts docker-compose.yml**: Any service, port, environment variable, or volume in `docker-compose.yml` that is absent from the README documentation (or documented incorrectly).
- **Secrets in Dockerfiles or scripts**: Any hardcoded credential, token placeholder (besides `changeme`), or API key in a Dockerfile or `.sh` file.

## Evaluator Instructions
Score each attribute from 1 to 10 using current repository state and concrete evidence. Report <promise>COMPLETE</promise> only when all targets are fulfilled. Otherwise report <promise>INCOMPLETE</promise>.