---
name: jan
description: Jan, an open-source desktop app that runs GGUF and MLX models offline with a local OpenAI- and Anthropic-compatible API server on :1337 and custom endpoints for vLLM, Ollama or LiteLLM. Use to install (Flatpak, deb, AppImage, dmg, exe), start and secure the Local API Server, import models, add providers or MCP servers, point Claude Code at it, update, and fix port 1337, 401, 404 or models that will not load.
license: MIT
compatibility: Commands assume bash, curl and jq. Jan is a GUI app whose server toggles live in Settings, so the agent mostly verifies over HTTP and reads logs. macOS is Apple Silicon only (13.6+); Windows 10+; Linux needs AVX2. Installs, binding to 0.0.0.0 and API key changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Jan

A working Jan desktop install (`jan`, repo janhq/jan, Apache-2.0) with models loaded and, when needed, the Local API Server reachable at `http://127.0.0.1:1337/v1` for scripts, IDEs and other apps.

**Scope:** this one product: install, local server, models, providers, MCP, update, troubleshoot. Choosing a runtime belongs to `local-llms`; headless or multi-user serving belongs to `llama-cpp`, `ollama` or `vllm`. The Jan Agent CLI (`jan agent`) is a separate preview product and is only mentioned.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values. Jan's data folder: macOS `~/Library/Application Support/Jan/data`, Linux `~/.local/share/Jan/data`, Windows `%APPDATA%\Jan\data` (movable in Settings).

```bash
ls /Applications | grep -i '^jan'; command -v flatpak >/dev/null && flatpak list | grep -i ai.jan.Jan
dpkg -l 2>/dev/null | grep -i ' jan'; command -v jan && jan --version      # jan CLI is a separate install
lsof -nP -iTCP:1337 -sTCP:LISTEN
D="$HOME/Library/Application Support/Jan/data"; [ -d "$D" ] || D="$HOME/.local/share/Jan/data"
tail -n 30 "$D/logs/app.log" 2>/dev/null                                    # [APP] [SERVER] [llamacpp-router] tags
curl -fsS http://127.0.0.1:1337/v1/models ${JAN_API_KEY:+-H "Authorization: Bearer $JAN_API_KEY"} | jq -r '.data[].id'
gh api repos/janhq/jan/releases/latest --jq .tag_name
```

Ask only what discovery cannot show: OS and GPU, which models, whether other devices or containers must reach the server, whether a key is set.

## Decision flow

1. **Not installed:** pick the package for the OS. -> `references/install.md`
2. **Installed, other apps need an API:** Settings -> Local API Server -> Start; set an API key before binding beyond localhost. -> `references/local-api-server.md`
3. **Need a model:** Hub, Hugging Face, or import a GGUF in place. -> `references/models-and-engines.md`
4. **Use a remote or self-hosted backend inside Jan** (vLLM, Ollama, LiteLLM, Claude, OpenAI): custom provider. -> `references/providers-and-integrations.md`
5. **Tools and agents:** MCP servers, Claude Code integration. -> `references/providers-and-integrations.md`
6. **New release:** -> `references/updating.md`
7. **Error:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, package updates, binding to `0.0.0.0` and deleting the data folder need approval and an undo path.
- **Localhost by default.** The server host defaults to `127.0.0.1`. Binding to `0.0.0.0` exposes it to the LAN; set an API key and Trusted Hosts first. Since v0.8.5 a request to a `0.0.0.0` bind whose `Host` is not localhost, `host.docker.internal`, a loopback or private IP, or a Trusted Host gets `403`.
- **A key is optional but empty means open.** Leave the API key empty only on localhost.
- **Custom endpoints need the version path.** Base URL `http://host:8000/v1`, not `http://host:8000`; any non-empty placeholder key for local servers.
- **The engine ships with the app** (v0.8.5+): llama.cpp is not downloaded separately, so engine updates come with Jan updates. Use a custom provider to run a different `llama-server`.
- **Secrets never touch output.** API keys live in Jan's settings or an environment variable you pass; never echo them.
- **Verify upstream.** Behavior comes from jan.ai/docs and release notes; Jan changes quickly (several 0.8.x releases in weeks).

## Workflows

### Install and first chat

- [ ] Install for the OS -> `references/install.md`; launch; finish the first-run wizard.
- [ ] Download a model from the Hub; chat once.

### Serve the local API

- [ ] Settings -> Local API Server: set host, port, API key; Start Server -> `references/local-api-server.md`.
- [ ] `curl http://127.0.0.1:1337/v1/models`, then one chat call and one `/v1/messages` call.

### Add a self-hosted backend

- [ ] Settings -> Model Providers -> Add Provider; pick API format; base URL with `/v1`; add models manually if `/models` is not served -> `references/providers-and-integrations.md`.

### Update

- [ ] Read the changelog and note engine and migration items; back up the data folder -> `references/updating.md`.

## Reference index

| File                                       | Read when                                                 |
| ------------------------------------------ | --------------------------------------------------------- |
| `references/install.md`                    | macOS, Windows, Linux packages, data folder, uninstall    |
| `references/local-api-server.md`           | Host, port, key, Trusted Hosts, CORS, endpoints, examples |
| `references/models-and-engines.md`         | Hub, imports, llama.cpp router, MLX, parameters           |
| `references/providers-and-integrations.md` | Custom endpoints, cloud providers, MCP, Claude Code       |
| `references/updating.md`                   | Update paths per OS, 0.8.x migration notes, backups       |
| `references/troubleshooting.md`            | Symptom to cause to fix                                   |

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `local-llms`: choosing a local runtime.
- `lm-studio`, `ollama`, `llama-cpp`, `mlx`: alternative or underlying engines.
- `litellm`: a gateway Jan can use as a custom endpoint.
- `llm-clients`: pointing other agents and IDEs at an OpenAI-compatible server.
