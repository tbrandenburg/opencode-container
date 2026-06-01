# Clean worker results

Verified on 2026-05-31 from this clean subfolder.

## Commands verified

```bash
uvx --from flowsh-cli==0.3.0 flowsh-cli .made/workflows.yml --dry-run
uvx --from flowsh-cli==0.3.0 flowsh-cli .made/workflows.yml --force
docker compose build generic-worker
```

## Worker runs

Target repo: `https://github.com/tbrandenburg/pyrag.git`.

### Dry-run bash harness

Worked. The worker cloned the repo, then the generated harness skipped the bash step:

```text
[DRY-RUN] would run: step_inspect_clone
```

### Real bash harness

Worked. Observed:

```text
/repo
https://github.com/tbrandenburg/pyrag.git
# PyRAG
```

### Real vars harness

Worked. Observed:

```text
branch=main
heading=# PyRAG
```

### Real custom-agent harness

Worked. The worker copied `.opencode` from `/opencode-config`, ran `opencode`, and the custom agent answered:

```text
My name is test. The repository heading is "# PyRAG".
```

## Notes

- This folder is self-contained for the worker image and compose service.
- `flowsh-cli` still runs on the host via `uvx`; it is not installed in the worker image.
- The worker image installs `opencode-ai@latest`, `git`, and CA certificates.
- Harness `--dry-run` does not skip the worker clone step.
- `docker compose ps -a` showed no remaining containers after `--rm` runs.
