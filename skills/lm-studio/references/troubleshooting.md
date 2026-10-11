# Troubleshoot LM Studio

> Verified against LM Studio 0.4.26, lmstudio.ai/docs and lmstudio-ai/lms README, 2026-10-11

Causes marked (likely) are inferred, not stated upstream.

| Symptom                                                               | Cause                                                                                    | Fix                                                                                                                                         |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `lms: command not found`                                              | App never run, or PATH not updated                                                       | Run LM Studio once, open a **new** terminal; else `npx lmstudio install-cli`. llmster: `~/.lmstudio/bin/lms`.                               |
| `lms` says nothing is running / `lms server status` shows not running | `lms status`, `server status` and `server stop` never start an app                       | `lms server start` (starts the app or llmster for most commands).                                                                           |
| `curl localhost:1234` connection refused                              | Server not started, or a different port (the port is sticky)                             | `lms server status --json --quiet`; `lms server start --port 1234`.                                                                         |
| `/v1/models` lists models you did not load                            | JIT loading is on: all downloaded models are listed                                      | Expected. Turn JIT off in Server Settings to list only loaded models.                                                                       |
| First request is slow, model "disappears" later                       | JIT load on demand; idle TTL (60 min default) unloads it; Auto-Evict keeps one JIT model | Preload with `lms load <model> --ttl <s>` (no TTL by default), or raise the TTL; turn Auto-Evict off to keep several.                       |
| 401 / authentication errors                                           | **Require Authentication** is on and no valid token                                      | Send `Authorization: Bearer $LM_API_TOKEN` or `x-api-key`. Create a new token in **Manage Tokens** if lost (shown once).                    |
| Another machine cannot connect                                        | Server bound to `127.0.0.1`                                                              | Enable auth first, then `lms server start --bind 0.0.0.0`; check firewall.                                                                  |
| Browser app blocked by CORS                                           | CORS is off                                                                              | `lms server start --cors` (enable auth too).                                                                                                |
| Model refuses to load: guardrails / may not fit                       | Resource guardrails and estimator                                                        | `lms load --estimate-only <model> --context-length N`; lower context, pick a smaller quant, `--gpu` fraction. Do not disable the guardrail. |
| Slow on Mac, high memory                                              | GGUF where an MLX build exists, or context too large                                     | `lms get --mlx <model>`; shrink `--context-length`.                                                                                         |
| Claude Code or Codex loses context / loops                            | Context length too small                                                                 | Load with 25k+ tokens (upstream tip), `combos/claude-code.md`.                                                                              |
| New model: unsupported architecture (likely)                          | Old runtime                                                                              | `lms runtime update`, or `lms runtime get` / `select` a newer one; update the app.                                                          |
| Request parameters ignored (`flash_attention` etc.)                   | Option applies only to llama.cpp engine                                                  | Expected for MLX models.                                                                                                                    |
| API client cannot use your MCP servers                                | "Allow calling servers from mcp.json" is off, or auth is off (it requires auth)          | Enable Require Authentication, then the toggle; or use an ephemeral remote MCP.                                                             |
| Remote device shows "disconnected" in LM Link                         | Crashed device not yet reported, or app not running                                      | Confirm LM Studio/llmster is running there; `lms link status`; report to bugs@lmstudio.ai if it persists.                                   |
| Several LM Studio products installed, wrong one answers               | `lms` prefers a running LM Studio or llmster over Bionic                                 | `lms daemon status`; stop the one you do not want.                                                                                          |
| llmster service starts but no model                                   | Unit has no `lms load` line and JIT is off                                               | Add the load line or turn JIT on.                                                                                                           |

## Debug a bad prompt or template

```bash
lms log stream --source model --filter input,output --stats
lms log stream --source server
```

`input` shows the exact string sent to the model after the chat template is applied.

## Reporting

Bugs: https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues. Include `lms --help | head -1`, app version, OS, runtime (`lms runtime ls`), the model key and the failing command. Remove tokens and `mcp.json` headers first.

## Official links

- CLI: https://lmstudio.ai/docs/cli
- Headless: https://lmstudio.ai/docs/developer/core/headless
- Server settings: https://lmstudio.ai/docs/developer/core/server/settings
- LM Link FAQ: https://lmstudio.ai/docs/lmlink/basics/faq
- Bug tracker: https://github.com/lmstudio-ai/lmstudio-bug-tracker
