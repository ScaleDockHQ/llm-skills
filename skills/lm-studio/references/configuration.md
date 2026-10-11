# Configure LM Studio: models, server, auth, network

> Verified against LM Studio 0.4.26 and lmstudio.ai/docs (cli, developer/core), 2026-10-11

## Models

```bash
lms get <model>                    # search and download; e.g. openai/gpt-oss-20b; no argument shows staff picks
lms get llama-3.1-8b@q4_k_m        # '@' selects a quantization
lms get --mlx <model>              # only MLX results (Apple Silicon); --gguf for GGUF only
lms ls [--llm|--embedding] [--json] [--detailed]
lms import ~/Downloads/model.gguf --copy   # use an existing file; --dry-run first; --user-repo user/repo skips prompts
```

`lms get` flags: `-n/--limit`, `--always-show-all-results`, `-a/--always-show-download-options`. `lms import` moves the file by default; `--copy`, `--hard-link` and `--symbolic-link` are mutually exclusive.

Without `--mlx`/`--gguf`, search results match the installed runtimes. The models directory is shown, and can be changed, in the app's **My Models** tab. Delete models there too.

## Load and unload

```bash
lms load --estimate-only <model> --context-length 32768    # prints memory estimate, loads nothing
lms load <model> --context-length 32768 --gpu max --ttl 3600 --identifier local-model
lms ps [--json]
lms unload <model> | lms unload --all
```

| `lms load` flag    | Meaning                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `--context-length` | Tokens of context. Set it; agents need 25k+.                                               |
| `--gpu`            | `0`-`1` fraction of layers, `off`, or `max`. Unset: LM Studio decides.                     |
| `--ttl`            | Seconds idle before auto-unload. **Models loaded with `lms load` have no TTL by default.** |
| `--identifier`     | Name used as the `model` value in API calls.                                               |
| `--estimate-only`  | Memory estimate (accounts for context, flash attention, vision), no load.                  |
| `-y` / `--yes`     | Skip prompts (used by the systemd recipe).                                                 |
| `--host`           | Operate on a remote LM Studio instance (also on `ls`, `ps`, `unload`).                     |

Per-model defaults: **My Models** tab > gear icon. Those defaults apply whenever the model is loaded, including through `lms load`. The estimator and the app's resource guardrails can refuse a load that will not fit: pick a smaller model, quant or context rather than disabling the guardrail.

## Server

```bash
lms server start [--port N] [--bind 0.0.0.0|127.0.0.1] [--cors]
lms server status [--json] [--quiet]
lms server stop
```

- Default bind `127.0.0.1`. `--port` omitted means the **last used port** (1234 on a fresh install). `--bind` can also come from `LMS_SERVER_HOST`.
- CORS is off unless `--cors` (or the toggle). Upstream warns about the risk and recommends authentication.
- `lms server status --json --quiet` gives `{ "running": true, "port": 1234 }`.

### Server settings (Developer > Server Settings in the app)

| Setting                             | Notes                                                                                         |
| ----------------------------------- | --------------------------------------------------------------------------------------------- |
| Server Port                         | Integer.                                                                                      |
| Require Authentication              | Off by default. Needs LM Studio 0.4.0+.                                                       |
| Serve on Local Network              | Binds a non-localhost address. Upstream recommends authentication.                            |
| Allow per-request MCPs              | Ephemeral remote MCP servers in a request (only remote MCPs supported).                       |
| Allow calling servers from mcp.json | Lets API clients use your configured MCP servers. Risky; **requires Require Authentication.** |
| Enable CORS                         | Cross-origin browser access.                                                                  |
| Just in Time Model Loading          | Load on request. Default on.                                                                  |
| Auto Unload Unused JIT Models       | Unload JIT-loaded models after the idle TTL.                                                  |
| Only Keep Last JIT Loaded Model     | Auto-Evict. Default on.                                                                       |

## JIT loading, TTL, auto-evict

- **JIT on:** `/v1/models` lists every downloaded model; an inference request loads the model if needed. **JIT off:** `/v1/models` lists only loaded models and you must load first.
- **Idle TTL:** JIT-loaded models default to **60 minutes** idle, then unload. The timer resets on each request.
- **Per-request TTL:** add `"ttl": 300` (seconds) to the request body of the first request that triggers the load (documented on the OpenAI-compatible and REST endpoints).
- **Auto-Evict (default on):** at most one JIT-loaded model stays in memory; loading another JIT model unloads the previous one. Models loaded manually are unaffected. Turn it off in Server Settings to keep several resident (watch RAM).

## Authentication

Needs LM Studio 0.4.0+. In **Developer > Server Settings** turn on **Require Authentication**, then **Manage Tokens** > Create Token (name, permissions). The token is shown once: store it in a `0600` file or a secret manager, not in shell history.

```bash
umask 077; mkdir -p ~/.config/lmstudio && ${EDITOR:-nano} ~/.config/lmstudio/token   # paste the token, one line
export LM_API_TOKEN="$(cat ~/.config/lmstudio/token)"
curl -s http://localhost:1234/v1/models -H "Authorization: Bearer $LM_API_TOKEN" | jq '.data | length'
```

With authentication on, LM Studio accepts both `Authorization: Bearer <token>` and `x-api-key: <token>`. All REST, Python SDK and TypeScript SDK calls then need a token. Edit permissions later via the Edit button in the tokens dialog.

## Network exposure

1. Turn on Require Authentication and create a token (above).
2. `lms server start --bind 0.0.0.0` (or the **Serve on Local Network** toggle).
3. Find the LAN address and test from another machine with the token.
4. Prefer a VPN, or LM Link (`combos/lm-link.md`), over opening a port to the internet. The macOS firewall asks to allow incoming connections the first time a binary listens off-loopback; decline unless sharing is intended.

Undo: `lms server stop && lms server start --bind 127.0.0.1`.

## Logs and paths

```bash
lms log stream                          # model input/output as formatted for the model (default source: model)
lms log stream --source server          # HTTP server logs
lms log stream --source model --filter input,output --json --stats
```

`--filter` accepts `input`, `output` or both. Use the model source to debug chat templates. `~/.lmstudio/` holds app data (the Linux systemd recipe uses `~/.lmstudio/bin/lms`); the exact models directory is whatever **My Models** shows.

## Official links

- `lms load`: https://lmstudio.ai/docs/cli/local-models/load
- `lms get`: https://lmstudio.ai/docs/cli/local-models/get
- `lms import`: https://lmstudio.ai/docs/cli/local-models/import
- `lms server start`: https://lmstudio.ai/docs/cli/serve/server-start
- `lms server status`: https://lmstudio.ai/docs/cli/serve/server-status
- `lms log stream`: https://lmstudio.ai/docs/cli/serve/log-stream
- Server settings: https://lmstudio.ai/docs/developer/core/server/settings
- Authentication: https://lmstudio.ai/docs/developer/core/authentication
- Serve on network: https://lmstudio.ai/docs/developer/core/server/serve-on-network
- Idle TTL and auto-evict: https://lmstudio.ai/docs/developer/core/ttl-and-auto-evict
- Per-model defaults: https://lmstudio.ai/docs/app/advanced/per-model
