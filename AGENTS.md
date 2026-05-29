# opencode-container

Docker images for running OpenCode in various serving modes.

## Containers

| Container | Mode | Purpose |
|---|---|---|
| `opencode-serve` | `serve` | Headless HTTP server with web UI + REST API + OpenAPI doc |
| `opencode-web` | `web` | Same as serve with auto-instantiated project instance |
| `opencode-acp` | `acp` | ACP (Agent Client Protocol) JSON-RPC server over stdio, bridged to TCP via socat |
| `opencode-issue-processor` | `run` | Batch: iterate all open issues from configured repos, piped into `opencode run` |
| `opencode-plan-issue` | `run` | One-shot: clone a repo, analyze an issue, post implementation plan as comment |

## Commands

```bash
make install    # (not needed - containers are self-contained)
make build      # docker compose build
make run        # docker compose up -d
make stop       # docker compose down
make serve      # docker compose up -d opencode-serve
make web        # docker compose up -d opencode-web
make acp        # docker compose up -d opencode-acp
make logs       # docker compose logs -f
make clean      # docker compose down --remove-orphans -v
make process    # docker compose run --rm opencode-issue-processor
make plan       # docker compose run --rm opencode-plan-issue
```

## Usage

### Server containers (long-running)

```bash
# Start all servers
docker compose up -d

# Start individual server
docker compose up -d opencode-serve

# Check
curl -u "opencode:changeme" http://localhost:4096/global/health
```

### Issue processor (batch, then exit)

```bash
GH_TOKEN=$(gh auth token) docker compose run --rm opencode-issue-processor
```

### Issue planner (one-shot, then exit)

```bash
ISSUE_URL=https://github.com/tbrandenburg/pyrag/issues/30 \
  GH_TOKEN=$(gh auth token) \
  docker compose run --rm opencode-plan-issue
```

All runner containers pass `GH_TOKEN` from the host environment as-is — it never enters context.

## Network

| Container | Port | Auth |
|---|---|---|
| `opencode-serve` | 4096 | Basic auth via `OPENCODE_SERVER_PASSWORD` (default: `changeme`) |
| `opencode-web` | 4098 | Basic auth via `OPENCODE_SERVER_PASSWORD` (default: `changeme`) |
| `opencode-acp` | 4097 | None (stdio-based, TCP via socat) |

## Rules

- Only `opencode serve` and `opencode web` support `--port`, `--hostname`, `--cors`, `--mdns`
- `opencode acp` communicates over stdio using JSON-RPC 2.0 — socat bridges it to TCP for container access
- `opencode run` is used for ephemeral batch/plan containers — it needs a git repo and provider credentials in the environment
- Never hardcode `GH_TOKEN`, `OPENCODE_API_KEY`, or any credential in Dockerfiles or scripts
- All `openmode-*` containers use `node:22-slim` base image with `opencode-ai` npm package and `gh` CLI installed via tarball from `cli/cli` releases
- For token safety: `$(gh auth token)` is interpolated by the calling shell, never read into agent context
- Container `profiles: [manual]` services must be run with `docker compose run --rm` — they are not started by `docker compose up`
