# flowsh-cli 0.3.0 generic-worker evaluation

Verified on 2026-05-31 with `uvx flowsh-cli --version` resolving to `flowsh-cli 0.3.0` after reinstalling the uv tool.

Target repository for worker runs: `https://github.com/tbrandenburg/pyrag.git`.

## Generated workflows

Source file: `.flowsh-eval/.made/workflows.yml`.

Generated harnesses with:

```bash
uvx flowsh-cli .made/workflows.yml --dry-run
uvx flowsh-cli .made/workflows.yml --force
```

Generated files:

- `.flowsh-eval/.harness/hello_bash.sh`
- `.flowsh-eval/.harness/vars_readonly.sh`
- `.flowsh-eval/.harness/agent_dry_run.sh`
- `.flowsh-eval/.harness/agent_real.sh`
- `.flowsh-eval/.harness/vars_agent_expand.sh`

## Test runs

### 1. Simple bash workflow, harness dry-run

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/.harness/hello_bash.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh --dry-run
```

Container behavior:

- Created the compose network because it did not exist yet.
- Cloned `tbrandenburg/pyrag` into `/repo`.
- Executed `/workflow.sh --dry-run`.
- The harness logged workflow start, one dry-run step, and workflow finish.

Outcome: worked, exit 0.

Experience:

- The worker still clones the repository before the harness dry-run executes.
- Harness dry-run prevents workflow step side effects, but not worker setup effects such as clone/network creation.

### 2. Simple bash workflow, real read-only run

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/.harness/hello_bash.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh
```

Container behavior:

- Cloned `tbrandenburg/pyrag` into `/repo`.
- Ran the generated bash step.
- Printed `/repo` and `https://github.com/tbrandenburg/pyrag.git`.
- `git status --short` produced no output.

Outcome: worked, exit 0.

Experience:

- Basic generated bash harnesses work in the worker.
- Log output goes to stderr and the generated log file inside the ephemeral cloned repo.

### 3. Vars plus bash workflow, real read-only run

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/.harness/vars_readonly.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh
```

Container behavior:

- Cloned `tbrandenburg/pyrag` into `/repo`.
- Ran a stateful vars step that exported `CURRENT_BRANCH`, `FILE_COUNT`, and `README_TITLE`.
- Ran a later bash step that consumed those exported variables.

Observed output:

```text
branch=main
files=105
readme=# PyRAG
```

Outcome: worked, exit 0.

Experience:

- `vars` steps correctly persist values for later steps because flowsh renders them with `run_stateful_step`.
- The generated commands are suitable for read-only repo inspection.

### 4. Agent workflow, harness dry-run

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/.harness/agent_dry_run.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh --dry-run
```

Container behavior:

- Cloned `tbrandenburg/pyrag` into `/repo`.
- Executed `/workflow.sh --dry-run`.
- The harness logged only `[DRY-RUN] would run: step_ask_default_agent_dry_run_only`.

Outcome: worked, exit 0.

Experience:

- Agent dry-run does not invoke `opencode`.
- Dry-run currently logs the generated step function name, not the underlying `opencode run --format json` command or agent selector. The rendered `run_agent()` has its own dry-run logging, but it is not reached because `run_step()` returns before calling the step function.

### 5. Real custom-agent workflow

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/agent:/opencode-config/agent:ro" \
  -v "$PWD/.flowsh-eval/.harness/agent_real.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh
```

Container behavior:

- Cloned `tbrandenburg/pyrag` into `/repo`.
- Bootstrapped `/opencode-config/agent/test.md` into `/root/.config/opencode/agent/test.md`.
- Ran the generated agent step with `opencode run --format json --agent test -- "$prompt"`.
- OpenCode emitted JSON events and the custom agent answered `My name is test.`.

Outcome: worked, exit 0.

Experience:

- Mounted custom agent definitions are copied correctly by the generic worker.
- Generated `agent` steps work with the custom `agent` field.
- OpenCode JSON event output is streamed into the harness output.

### 6. Vars plus expanded prompt plus real custom agent

Command shape:

```bash
REPO_URL=https://github.com/tbrandenburg/pyrag.git docker compose run --rm \
  -v "$PWD/.flowsh-eval/agent:/opencode-config/agent:ro" \
  -v "$PWD/.flowsh-eval/.harness/vars_agent_expand.sh:/workflow.sh:ro" \
  opencode-generic-worker /workflow.sh
```

Container behavior:

- Cloned `tbrandenburg/pyrag` into `/repo`.
- Bootstrapped the custom test agent.
- Exported `README_HEADING` from `README.md`.
- Built an agent prompt with `expandPrompt: true`, expanding `${README_HEADING}` in the heredoc.
- Ran the custom agent.

Observed agent text event:

```text
test: # PyRAG
```

Outcome: worked, exit 0.

Experience:

- `expandPrompt: true` works for shell variable interpolation into agent prompts.
- The model used a read tool despite the heading being in the prompt. This is not a flowsh failure, but it means real agent runs can perform tool calls unless constrained by agent/runtime config.

## Compatibility check against existing repo workflow

Command:

```bash
uvx flowsh-cli workflows/issue-resolution/.made/workflows.yml --dry-run
```

Outcome: failed schema validation.

Observed error:

```text
ERROR: Invalid workflow YAML: workflows.0.enabled: Extra inputs are not permitted; workflows.0.schedule: Extra inputs are not permitted; workflows.0.shellScriptPath: Extra inputs are not permitted
```

Experience:

- `flowsh-cli 0.3.0` still uses a strict schema and rejects existing metadata fields used by `workflows/issue-resolution/.made/workflows.yml`.
- Either the existing workflow metadata must be reduced to the supported schema before generation, or `flowsh-cli` should intentionally support fields such as `enabled`, `schedule`, and `shellScriptPath` if those are part of the expected MADE workflow format.

## Summary

Worked:

- `uvx flowsh-cli` default resolution after reinstalling to 0.3.0.
- Harness generation dry-run and real generation.
- Worker execution of generated bash steps.
- Worker execution of generated vars steps with state carried forward.
- Worker execution of generated custom-agent steps.
- `expandPrompt: true` for variable expansion in agent prompts.
- Generic worker config bootstrap via `/opencode-config`.

Did not work:

- Existing `workflows/issue-resolution/.made/workflows.yml` is rejected by `flowsh-cli 0.3.0` because it contains strict-schema extra fields.

Should work or could be improved:

- Harness dry-run for agent steps should probably expose the concrete `opencode run` command and selected agent, not only the generated function name.
- If `enabled`, `schedule`, and `shellScriptPath` are canonical MADE workflow metadata, `flowsh-cli` should accept them or document that it only consumes a reduced generation schema.
- If users expect host-visible logs, the worker command should mount a log directory or set `FLOWSH_LOG_DIR` to a mounted relative path inside `/repo`; otherwise logs disappear with the ephemeral container.

Safety notes:

- No destructive workflow steps were used.
- The only repository writes were temporary evaluation files under `.flowsh-eval/` in this workspace and generated `.flowsh/logs` inside ephemeral cloned containers.
- Compose containers were run with `--rm`; `docker compose ps -a` showed no remaining containers after the runs.
