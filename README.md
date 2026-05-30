# opencode-container

Docker images for running [OpenCode](https://opencode.ai) — an AI coding agent — in every supported mode: HTTP server, web UI, ACP protocol bridge, and ephemeral issue-processing workers.

## Quickstart

**Prerequisites**: [Docker](https://docs.docker.com/engine/install/) (with Compose v2), [gh CLI](https://cli.github.com/) (for runner containers).

```bash
make build
make serve
curl -u "opencode:changeme" http://localhost:4096/global/health
```

That's it. Three commands, zero edits, and you have a running OpenCode server.

## Containers

| Container | Dockerfile | Mode | Port | Profiles | Volumes | Purpose |
|---|---|---|---|---|---|---|---|---|
| `opencode-serve` | `serve.dockerfile` | `serve` | 4096 | — | data, config | Headless HTTP server: web UI + REST API + OpenAPI doc. Starts with an initialized git project. |
| `opencode-web` | `web.dockerfile` | `web` | 4098 | — | data, config | Same as `serve` but uses `opencode web` (auto-instantiates a project on first load). |
| `opencode-acp` | `acp.dockerfile` | `acp` | 4097 | — | — | ACP (Agent Client Protocol) JSON-RPC server over stdio, bridged to TCP via `socat`. For ACP-compatible clients (Cline, continue.dev). |
| `opencode-issue-processor` | `issue-processor.dockerfile` | `run` | — | `manual` | data, config | Batch: iterates all open issues from configured repos, pipes each into `opencode run`. Exits when done. |
| `opencode-plan-issue` | `plan-issue.dockerfile` | `run` | — | `manual` | data, config | One-shot: clones a repo, analyzes a specific issue, posts an implementation plan as a GitHub comment. Exits when done. |
| `opencode-generic-worker` | `generic-worker.dockerfile` | `run` | — | `manual` | data, config | Clone a repo, bootstrap opencode config from a mounted volume, execute a mounted script or inline command. |

### Which container do I pick?

| You want to... | Use |
|---|---|
| Run a headless OpenCode server with a web UI | `opencode-serve` (`make serve`) |
| Run OpenCode web with an auto-created project | `opencode-web` (`make web`) |
| Connect an ACP client (e.g. Cline, continue.dev) | `opencode-acp` (`make acp`) |
| Process all open issues from one or more repos | `opencode-issue-processor` (`make process`) |
| Analyze a single issue and post a plan | `opencode-plan-issue` (`make plan`) |
| Run a custom script inside a cloned repo | `opencode-generic-worker` (`make generic`) |
| Run a continuous issue-resolution workflow | `workflows/issue-resolution/.harness/continuous-issue-resolution.sh` |
| Pass `--help` flags to opencode | `docker compose run --rm opencode-serve --help` |

### Managing repos for the issue processor

The issue processor (`process-issues.sh`) defaults to a hardcoded list:

```bash
REPOS=(
  "tbrandenburg/made"
  "tbrandenburg/pyrag"
)
```

Override at runtime with the `REPOS` environment variable (comma-separated):

```bash
REPOS=tbrandenburg/pyrag,owner/other-repo GH_TOKEN=$(gh auth token) make process
```

Edit the array in `process-issues.sh` to change the default list. Each entry is an `owner/repo` pair understood by `gh issue list`.

## Architecture

### Why this design?

OpenCode supports three runtime modes — `serve` (HTTP API), `web` (HTTP + instant project), and `acp` (JSON-RPC over stdio) — plus a `run` mode for one-off agent invocations. Each mode has different network and lifecycle requirements. Rather than crafting a single monolithic image, each mode gets its own Dockerfile. This gives us:

- **Isolation by purpose**: A `socat` dependency for ACP doesn't bloat the serve image. Git and `gh` CLI for runners don't affect the server image.
- **Independent lifecycle**: Serve/web containers run long-term. Runner containers (issue-processor, plan-issue, generic-worker) are ephemeral — they clone, execute, and exit.
- **Clean `--help` passthrough**: Serve/web use `ENTRYPOINT` so `docker compose run --rm opencode-serve --help` works naturally. Runner containers use `CMD`/`ENTRYPOINT` pointing to their shell scripts.

#### serve vs web — what's the difference?

Both `opencode-serve` and `opencode-web` run HTTP servers. The difference:

- **`serve`** (`opencode serve`): Requires an existing git-initialized project. The Dockerfile creates one at build time (`git init` + commit). Good for teams that want to control the project lifecycle.
- **`web`** (`opencode web`): Auto-instantiates a project on first load. Slightly more self-service for new users.

Pick `serve` for production/team setups where you mount your own project. Pick `web` for quick experiments.

#### Why socat for ACP?

OpenCode's ACP mode speaks JSON-RPC 2.0 over **stdin/stdout** — it's designed for local processes, not network sockets. To make it accessible inside Docker without modifying OpenCode itself, `socat` bridges a TCP listener to the process's stdio:

```
TCP client → socat TCP-LISTEN:4097 → EXEC:"opencode acp" (stdin/stdout)
```

This is a classic Unix pattern: a small, trusted tool adapts a stdio protocol to the network. It works on any port, requires zero OpenCode changes, and the container is completely transparent about it.

#### Why the profile/manual pattern?

```yaml
profiles:
  - manual
```

Containers with `profiles: [manual]` are excluded from `docker compose up` and `make run`. They must be launched explicitly:

```bash
docker compose run --rm opencode-plan-issue
```

This guarantees that ephemeral batch containers never accidentally stay running.

#### Why volume sharing?

All persistent containers share two named Docker volumes:

| Volume | Mount point | Contents |
|---|---|---|
| `opencode-data` | `/root/.local/share/opencode` | Session data, project history, LLM conversation logs |
| `opencode-config` | `/root/.config/opencode` | Global opencode config, agent definitions, custom prompts |

This means:
- Data survives container restarts and rebuilds
- Server and runner containers share the same config and history
- Volumes are created automatically by `docker compose up`

### The workflows pattern

The `workflows/` directory contains reusable OpenCode workflow harnesses — shell scripts that orchestrate multi-step agent tasks in a structured, logged fashion. Each workflow:

1. Clones or assumes a repository working copy
2. Runs a sequence of steps (bash commands and/or `opencode` agent invocations)
3. Logs everything to a dedicated log file with ISO-8601 timestamps
4. Supports `--dry-run` for previewing without side effects

The main workflow:
- **`workflows/issue-resolution/.harness/continuous-issue-resolution.sh`**: A full issue lifecycle workflow — checks for open issues, syncs main, fixes via agent, commits/pushes, resolves CI errors, reviews the PR, raises follow-up issues, and merges. Intended to run inside the `generic-worker` container.

Workflow harness scripts implement these functions:
- `log()` — ISO-8601 UTC timestamped logging to stderr + log file
- `run_step()` — execute a bash function step with failure handling, output streaming via `tee`
- `run_agent()` — pipe a prompt to `opencode run --format json` with optional `--agent` selector
- `catch()` — centralized failure hook that logs the step name and exit code

### Shell script robustness

Every `.sh` file in the repo root uses `set -euo pipefail` and validates required environment variables with descriptive error messages before proceeding. Shell scripts pass `shellcheck` at warning level with zero errors.

### Base image

All containers use `node:22-slim` with:
- `opencode-ai` npm package installed globally (`npm install -g opencode-ai@latest`)
- `gh` CLI installed from GitHub releases tarball (runner containers only)
- `git`, `ca-certificates` for clone operations
- `socat` for the ACP bridge container

### Network ports

### Network isolation

Docker Compose creates a default bridge network (`opencode-container_default`). All containers within `docker-compose.yml` are on this network and can reach each other by service name (e.g., `http://opencode-serve:4096` from another container).

| Container | Host port | Container port | Protocol | Network | Auth |
|---|---|---|---|---|---|---|
| `opencode-serve` | 4096 | 4096 | HTTP | bridge (default) | Basic auth via `OPENCODE_SERVER_PASSWORD` |
| `opencode-web` | 4098 | 4098 | HTTP | bridge (default) | Basic auth via `OPENCODE_SERVER_PASSWORD` |
| `opencode-acp` | 4097 | 4097 | TCP (JSON-RPC) | bridge (default) | None (stdio → TCP via socat) |

Runner containers (`manual` profile) have no published ports but are reachable by service name on the same network for outbound connections.

## Environment Variables

| Variable | Affected containers | Required | Default | Security note |
|---|---|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | `opencode-serve`, `opencode-web` | no | `changeme` | HTTP Basic auth password. Override in docker-compose.yml or via `-e`. |
| `GH_TOKEN` | `issue-processor`, `plan-issue`, `generic-worker`, workflow harnesses | yes (for GitHub operations) | — | GitHub personal access token. Pass via `GH_TOKEN=$(gh auth token)` at runtime. Never hardcoded in any Dockerfile or script — only interpolated by the calling shell. Never enters agent context. |
| `ISSUE_URL` | `plan-issue` | yes | — | Full GitHub issue URL, e.g. `https://github.com/owner/repo/issues/42`. The script parses owner/repo/number from this URL. |
| `REPO_URL` | `generic-worker` | yes | — | Git clone URL. The generic worker validates this is non-empty before proceeding. |
| `ISSUE` | `generic-worker` | no | empty | Issue number passed as an environment variable to the child command or script. |
| `REPOS` | `issue-processor` | no | hardcoded array in `process-issues.sh` | Comma-separated list of `owner/repo` pairs. Overrides the hardcoded default. Example: `REPOS=owner/repo1,owner/repo2`. |
| `OPENCODE_CONFIG_DIR` | `generic-worker` | no | `/opencode-config` | Source directory (inside container) to copy config from when bootstrapping. Mount a host config directory here to inject custom agents. |
| `WORK_DIR` | `generic-worker` | no | `/repo` | Destination directory for `git clone`. |
| `OPENCODE_GLOBAL_DIR` | `generic-worker` | no | `/root/.config/opencode` | Target directory for bootstrapped opencode global config. |
| `TARGETARCH` | `issue-processor`, `plan-issue`, `generic-worker` | no (build ARG) | `amd64` | Docker build `--build-arg` for architecture-specific `gh` CLI download. Set `--build-arg TARGETARCH=arm64` on ARM hosts. |
| `ARCH` | `issue-processor`, `plan-issue`, `generic-worker` | — | — | Internal variable derived from `TARGETARCH` in Dockerfile RUN commands. Not user-configurable. |
| `FLOWSH_LOG_DIR` | Test harness scripts (`tests/generic-worker/.harness/*.sh`) | no | `.flowsh/logs` | Override the log directory for generated flowsh harness scripts. Only relevant when developing or debugging test harnesses. |

### Env var security rules

- `GH_TOKEN` is **never hardcoded** in any Dockerfile or `.sh` file. It is passed at container runtime from the calling shell's `gh auth token` output.
- `OPENCODE_SERVER_PASSWORD` has a default value of `changeme` in both Dockerfiles and `docker-compose.yml`. Change it in production.

## Commands

| Command | Description |
|---|---|
| `make install` | No-op (containers are self-contained). Prints informational message. |
| `make build` | `docker compose build` — builds all container images. |
| `make run` | `docker compose up -d` — starts all server containers in background. |
| `make stop` | `docker compose down` — stops all containers. |
| `make serve` | `docker compose up -d opencode-serve` — start only the headless server. |
| `make web` | `docker compose up -d opencode-web` — start only the web UI server. |
| `make acp` | `docker compose up -d opencode-acp` — start only the ACP bridge. |
| `make logs` | `docker compose logs -f` — follow logs from all running containers. |
| `make clean` | `docker compose down --remove-orphans -v` — stop and remove all containers, networks, and volumes. |
| `make process` | `docker compose run --rm opencode-issue-processor` — run the issue processor (exit when done). |
| `make plan` | `docker compose run --rm opencode-plan-issue` — run the issue planner (exit when done). |
| `make generic` | `docker compose run --rm opencode-generic-worker` — run the generic worker (exit when done). |
| `make lint` | `shellcheck` on all shell scripts (root + tests). |
| `make test` | Build + shellcheck + integration tests for all containers. |
| `make verify-quickstart` | Automated quickstart verification: build, serve, health-check, cleanup. |
| `make test-generic-worker` | Extended generic-worker integration tests (agent harness + repo inspection). |

### --help passthrough

Because the serve/web containers use the pattern `ENTRYPOINT ["opencode", "serve|web"]` with `CMD` for flags, you can pass `--help` directly:

```bash
docker compose run --rm opencode-serve --help
docker compose run --rm opencode-web --help
```

## Usage

### Server containers (long-running)

```bash
# Build everything
make build

# Start all servers
make run

# Start individual server
docker compose up -d opencode-serve

# Health check
curl -u "opencode:changeme" http://localhost:4096/global/health

# View logs
make logs

# Stop everything
make stop
```

### Issue processor (batch, then exit)

```bash
GH_TOKEN=$(gh auth token) make process
```

The processor (`process-issues.sh`) iterates all open issues from hardcoded repos, piping each issue number into `opencode run`. Configure which repos to scan by editing `process-issues.sh`.

### Issue planner (one-shot, then exit)

```bash
ISSUE_URL=https://github.com/owner/repo/issues/30 \
  GH_TOKEN=$(gh auth token) \
  make plan
```

The planner (`plan-issue.sh`) parses the issue URL to extract owner/repo/number, clones the repo, then pipes a prompt into `opencode run` instructing it to read the issue, understand the codebase, and post a plan as a GitHub comment.

### Generic worker (one-shot, clone + exec)

```bash
# Mount a local script and execute it in the cloned repo:
docker compose run --rm opencode-generic-worker \
  -e REPO_URL=https://github.com/owner/repo.git \
  -e ISSUE=42 \
  -v ./workflows/issue-resolution/.opencode:/opencode-config:ro \
  -v ./my-script.sh:/script.sh:ro \
  /script.sh

# Pass an inline command instead:
docker compose run --rm opencode-generic-worker \
  -e REPO_URL=https://github.com/owner/repo.git \
  -e ISSUE=42 \
  sh -c 'echo "Issue: $ISSUE" && cat README.md'
```

The worker (`generic-worker.sh`):
1. Validates `REPO_URL` is set
2. Clones the repo to `WORK_DIR` (default `/repo`)
3. If `/opencode-config` exists (from a mounted volume), copies it to `OPENCODE_GLOBAL_DIR` to bootstrap custom agent definitions
4. Exports `ISSUE` as an environment variable
5. Executes the provided command (or exits with clone info if no command given)

**Security**: `GH_TOKEN`, `ISSUE_URL`, `REPO_URL`, and `ISSUE` are passed from the host environment and never read into agent context.

## Testing

```bash
make build    # Build all images first (required)
make test     # Run shellcheck + all integration tests
make verify-quickstart  # Full quickstart verification (build → serve → curl → cleanup)
```

The test suite (`tests/`) exercises:

| Test file | What it validates |
|---|---|---|
| `test-serve.sh` | `opencode-serve --help` returns help text; health-check endpoint returns `{"healthy":true}` |
| `test-web.sh` | `opencode-web --help` returns help text; health-check endpoint returns `{"healthy":true}` |
| `test-acp.sh` | socat binary is present, opencode binary is present, TCP listener on port 4097 is reachable |
| `test-generic-worker.sh` | Missing `REPO_URL` triggers error; clone-and-inspect on a public repo |
| `test-issue-processor.sh` | Missing `GH_TOKEN` triggers error |
| `test-plan-issue.sh` | Missing `ISSUE_URL` triggers error |
| `verify-quickstart.sh` | E2E: `make build`, `make serve`, curl health-check `{"healthy":true}`, `make stop` |
| `generic-worker/run-tests.sh` | Extended agent harness + repo inspection (requires `GH_TOKEN`). Runs as part of `make test` when `GH_TOKEN` is set. |

### Extended generic-worker test suite

The `tests/generic-worker/` directory contains an extended integration test suite for the generic worker container:

| File | Purpose |
|---|---|
| `run-tests.sh` | Test runner: invokes both harnesses inside the container |
| `.harness/agent_test.sh` | Bootstraps a custom agent and runs `opencode run --agent test` |
| `.harness/repo_inspect.sh` | Non-destructive: git log, file count, README check on a cloned repo |
| `agent/test.md` | Custom test agent definition ("test" agent) |
| `.made/workflows.yml` | Workflow definition metadata |

These tests require `GH_TOKEN` for GitHub operations and are skipped by `make test` if the token is unavailable. Run them explicitly:

```bash
GH_TOKEN=$(gh auth token) make test-generic-worker
```

### Workflow harness tests

The `workflows/issue-resolution/` directory contains a continuous issue-resolution workflow:

| Path | Purpose |
|---|---|
| `.harness/continuous-issue-resolution.sh` | Full issue lifecycle: check issues, sync, fix, commit, review, merge |
| `.opencode/opencode.jsonc` | OpenCode config for the workflow (Context7 + sequential thinking MCP) |
| `.opencode/agent/review.md` | Custom review agent definition |
| `.opencode/commands/` | Command files: `prp-issue-fix.md`, `prp-review.md`, `commit-push.md`, `resolve-ci-errors.md`, and `ghar-*` variants |
| `.made/workflows.yml` | Workflow metadata |

Run the continuous resolution workflow inside the generic-worker:

```bash
docker compose run --rm \
  -e REPO_URL=https://github.com/owner/repo.git \
  -e GH_TOKEN=$(gh auth token) \
  -v "$(pwd)/workflows/issue-resolution/.opencode:/opencode-config:ro" \
  opencode-generic-worker \
  /path/to/continuous-issue-resolution.sh
```

## Security Rules

1. **Never hardcode `GH_TOKEN`** in Dockerfiles or scripts. Always pass via `GH_TOKEN=$(gh auth token)` from the calling shell.
2. **Change the default password** in production: set `OPENCODE_SERVER_PASSWORD` to a strong value.
3. **`profiles: [manual]`** containers must be run with `docker compose run --rm` — never started by `docker compose up`.
4. **Container entrypoints use `set -euo pipefail`** and validate required environment variables before proceeding.
5. **Secrets never enter agent context** — runner containers pass tokens as env vars only, not as part of agent prompts.

## Prerequisites

| Tool | Minimum version | Purpose |
|---|---|---|
| [Docker](https://docs.docker.com/engine/install/) | 24+ (Compose v2) | Container runtime |
| [gh CLI](https://cli.github.com/) | 2.x | GitHub authentication for runner containers |

Docker must be installed and the Docker socket accessible. The `gh` CLI is only required if you use the runner containers (`issue-processor`, `plan-issue`, `generic-worker`).

## Project Structure

```
.
├── serve.dockerfile          # HTTP server image
├── web.dockerfile            # Web UI server image
├── acp.dockerfile            # ACP protocol bridge image
├── issue-processor.dockerfile # Batch issue processor image
├── plan-issue.dockerfile      # Single-issue planner image
├── generic-worker.dockerfile  # Generic clone-and-exec worker image
├── generic-worker.sh          # Entrypoint script for generic-worker
├── plan-issue.sh              # Entrypoint script for plan-issue
├── process-issues.sh          # Entrypoint script for issue-processor
├── docker-compose.yml         # All service definitions, volumes, profiles
├── Makefile                   # All make targets (build/run/test/lint/clean/verify-quickstart)
├── tests/                     # Integration test suite
│   ├── test-serve.sh
│   ├── test-web.sh
│   ├── test-acp.sh
│   ├── test-generic-worker.sh
│   ├── test-issue-processor.sh
│   ├── test-plan-issue.sh
│   ├── verify-quickstart.sh
│   └── generic-worker/        # Extended generic-worker tests
│       ├── run-tests.sh
│       ├── .harness/          # Test harness scripts
│       └── agent/             # Custom test agent definitions
├── workflows/                 # Workflow harness definitions
│   └── issue-resolution/      # Continuous issue resolution workflow
│       ├── .harness/
│       ├── .opencode/         # OpenCode config, agents, commands
│       └── .made/
└── AGENTS.md                  # Project-level agent instructions
```

## Dockerfiles detail

### Base pattern (all containers)

```dockerfile
FROM node:22-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates [socat] [curl] && rm -rf /var/lib/apt/lists/*
RUN npm install -g opencode-ai@latest
```

### Serve & Web

```dockerfile
ENV OPENCODE_SERVER_PASSWORD=changeme
EXPOSE 4096
ENTRYPOINT ["opencode", "serve"]
CMD ["--port", "4096", "--hostname", "0.0.0.0"]
```

### ACP

```dockerfile
EXPOSE 4097
CMD socat TCP-LISTEN:4097,reuseaddr,fork EXEC:"opencode acp",pty,stderr
```

No `ENTRYPOINT` — uses `CMD` directly so socat is the main process.

### Runner containers (issue-processor, plan-issue, generic-worker)

```dockerfile
ARG TARGETARCH
RUN case "$TARGETARCH" in ... download gh CLI ... esac
COPY *.sh /usr/local/bin/
CMD ["/usr/local/bin/script.sh"]  # or ENTRYPOINT for generic-worker
```

## License

MIT — see [LICENSE](LICENSE).