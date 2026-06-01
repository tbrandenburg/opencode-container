<!-- FOR AI AGENTS - Human readability is a side effect, not a goal -->
<!-- Last updated: 2026-06-01 | Last verified: never -->

# AGENTS.md

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. Root holds global defaults only.

## Core rules
- **KISS/YAGNI** — Justify every line; simplicity wins.
- **Evidence-first** — Never claim completion without verified output.
- **Binary outcomes** — Code is 100% working or 100% broken; no partial credit.
- **Forbidden without proof:** "most", "all", "nearly", "already", "looks complete".
- **Lessons-learned loop** — After any session involving pitfalls, unnecessary iterations, or surprising behaviour: ask the developer to update AGENTS.md with a concrete rule that prevents the same issue next time. Never silently discard a hard-won insight.

## Commands (verified)
| Task | Command | ~Time |
|------|---------|-------|
| Build | `make build` | 2–5 min (pulls base image + npm install) |
| Lint | `make lint` | <5 s |
| Test | `make test` | 1–3 min |
| Extended generic-worker tests | `GH_TOKEN=$(gh auth token) make test-generic-worker` | 2–4 min |
| Quickstart verify | `make verify-quickstart` | 2–4 min |
| Serve | `make serve` | <10 s |
| Stop | `make stop` | <5 s |
| Clean (remove volumes) | `make clean` | <10 s |

> If commands fail, verify against `Makefile` or `README.md`. `make test` skips extended generic-worker tests unless `GH_TOKEN` is set.

## Workflow
1. **Before coding**: read the nearest `AGENTS.md` and check Golden Samples for the area you're touching.
2. **After each change**: run `make lint` first, then `make test`.
3. **Before committing**: run the full suite (`make test`) if changes touch more than a couple of files or shared code.
4. **Dockerfiles**: after any change, run `make build && make test` — build failures are silent until you do.

## File map
```
.
├── *.dockerfile              # One Dockerfile per container mode
├── *.sh                      # Entrypoint scripts (generic-worker, plan-issue, process-issues)
├── docker-compose.yml        # All service definitions, volumes, profiles
├── Makefile                  # All make targets
├── tests/                    # Integration test suite
│   ├── test-*.sh             # Per-container smoke tests
│   ├── verify-quickstart.sh  # E2E: build → serve → health-check → cleanup
│   └── generic-worker/       # Extended generic-worker tests (require GH_TOKEN)
│       ├── run-tests.sh
│       ├── .harness/         # Agent + repo-inspect harness scripts
│       └── agent/            # Custom test agent definition
└── workflows/
    └── issue-resolution/     # Continuous issue-resolution workflow
        ├── .harness/         # Workflow harness shell script
        ├── .opencode/        # OpenCode config, agents, commands
        └── .made/            # Workflow metadata (workflows.yml)
```

## Golden samples
- `generic-worker.sh` — Canonical shell entrypoint: `set -euo pipefail`, env-var validation, bootstrap pattern.
- `tests/test-serve.sh` — Integration test pattern: docker run, assert stdout/stderr, exit code checks.
- `tests/generic-worker/.harness/repo_inspect.sh` — Flowsh harness: `run_step`, `run_agent`, `log`, `catch`.

## Coding standards
> Shell: follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).
- **All `.sh` files**: `set -euo pipefail` at the top, no exceptions.
- **Shellcheck clean**: `make lint` must pass with zero warnings before any commit.
- **No silent failures** — always handle or propagate errors explicitly; never use `|| true` without a comment.
- **No magic values** — use named env vars or constants; never inline strings/numbers.
- **Env var validation** — validate all required env vars at script entry with a descriptive `echo … && exit 1`.
- **Secrets** — `GH_TOKEN`, credentials, and tokens are never hardcoded in any Dockerfile or `.sh` file.

## Testing standards
> Strategy follows the [Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html): many unit, fewer integration, minimal E2E.
- **Framework:** Bash integration tests (`tests/test-*.sh`) + shellcheck as lint gate.
- Test location mirrors source: new entrypoint `foo.sh` → `tests/test-foo.sh`.
- Cover success, missing-env-var failure, and key edge cases; never write tests just for coverage.
- No mocks in integration tests — tests run real containers against real Docker images.
- `make test` must pass before any PR. Extended tests (`test-generic-worker`) must pass when `GH_TOKEN` is available.

## Heuristics
| When | Do |
|------|----|
| Committing | Conventional Commits (`feat:`, `fix:`…); message describes user impact, not implementation |
| Adding a new container | Add Dockerfile + entrypoint script + `docker-compose.yml` entry + `tests/test-<name>.sh` + README table row |
| Changing an entrypoint script | Re-run `make lint && make test` — shellcheck catches most issues |
| Adding a dependency | Ask first — minimize layers and image size |
| Unsure about pattern | Check Golden Samples above |

## Boundaries
### Always do
- Run `make lint` and `make test` before committing.
- Write or update a `tests/test-<name>.sh` for any new or changed container or entrypoint.
- Keep `README.md` tables (Containers, Commands, Env vars) in sync with `docker-compose.yml` and `Makefile`.

### Ask first
- Adding new base images or switching from `node:22-slim`.
- Changing public API: ports, env var names, volume mount paths.
- Adding new `make` targets or changing existing target behaviour.

### Never do
- Commit secrets, credentials, or `GH_TOKEN` values.
- Use `--no-verify` to bypass git hooks.
- Suppress shellcheck warnings with inline disables unless absolutely necessary (and always add a comment explaining why).
- Leave failing tests or a broken `make build`.

## References
- `README.md` — full project documentation (containers, env vars, architecture, testing)
- `Makefile` — authoritative list of all make targets
- `docker-compose.yml` — service definitions, volumes, profiles
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — shell scripting standard
- [Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) — test strategy reference
