# Ollama

> Verified against Ollama v0.40.3, 2026-10-11

## What it is and when to choose it

Ollama is a local model runner with a curated model library (`ollama pull <name>`), a background server, a CLI, and OpenAI- and Anthropic-compatible endpoints. Choose it when you want the lowest-friction setup that most clients (coding agents, chat UIs, SDKs) already support. Skip it when you need a built-in API key, exact engine flags, or day-zero support for a brand-new architecture; use llama.cpp for those.

## Install

- **macOS:** `curl -fsSL https://ollama.com/install.sh | sh`, or `Ollama.dmg` dragged to Applications. Requires macOS 14+. Uses Metal on Apple Silicon and the CPU on Intel.
- **Windows:** `irm https://ollama.com/install.ps1 | iex`, or `OllamaSetup.exe` (per-user, no admin rights needed).
- **Linux:** `curl -fsSL https://ollama.com/install.sh | sh`. This creates the `ollama.service` systemd unit.
- Also: Homebrew formula `ollama`, and the Docker image `ollama/ollama` (GPU only on Linux/WSL2 with nvidia-container-toolkit).

Ask before running any install script, because it changes the system.

## Minimal working config

```bash
ollama pull <model>              # e.g. a tag from https://ollama.com/library
ollama run <model> "Say hi"
ollama ps                        # NAME, SIZE, PROCESSOR (100% GPU / CPU split), CONTEXT, UNTIL
```

Custom defaults with a Modelfile (see `assets/Modelfile.example`):

```bash
ollama create my-model -f ./Modelfile
ollama run my-model
```

## How it plugs in

| Item                 | Value                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Default bind         | `127.0.0.1:11434` (`OLLAMA_HOST`)                                                                                                |
| Health               | `GET /` returns `Ollama is running`; `GET /api/version`; `GET /api/ps` lists loaded models                                       |
| OpenAI-compatible    | base URL `http://localhost:11434/v1`: `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/v1/embeddings`, `/v1/responses` |
| Anthropic-compatible | base URL `http://localhost:11434` → `/v1/messages` (`ANTHROPIC_BASE_URL=http://localhost:11434`)                                 |
| Native API           | `/api/chat`, `/api/generate`, `/api/embed`, `/api/tags`, `/api/pull`, ...                                                        |
| Auth                 | **None on the local server.** OpenAI clients need _some_ `api_key` string, and Ollama ignores it                                 |

`ollama launch` can configure and start supported integrations (Claude Code, Codex, OpenCode, VS Code, Droid) against your local Ollama. For client setup in general, see the **llm-clients** skill.

## Configuration (environment variables)

Verified in `envconfig/config.go` and the FAQ:

| Variable                   | Default                                                                                                              | Purpose                                                                                                   |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `OLLAMA_HOST`              | `127.0.0.1:11434`                                                                                                    | Bind address. `0.0.0.0:11434` exposes it on every interface                                               |
| `OLLAMA_CONTEXT_LENGTH`    | 4k (<24 GiB VRAM), 32k (24–48 GiB), 256k (≥48 GiB)                                                                   | Default context window. Agents and coding tools want at least 64000                                       |
| `OLLAMA_KEEP_ALIVE`        | `5m`                                                                                                                 | How long a model stays loaded. `-1` keeps it loaded forever, `0` unloads immediately                      |
| `OLLAMA_NUM_PARALLEL`      | `1`                                                                                                                  | Parallel requests per model. Memory scales with parallel × context                                        |
| `OLLAMA_MAX_LOADED_MODELS` | 3 × GPUs (3 on CPU)                                                                                                  | Concurrent models                                                                                         |
| `OLLAMA_MAX_QUEUE`         | `512`                                                                                                                | Queue length before 503s                                                                                  |
| `OLLAMA_FLASH_ATTENTION`   | auto                                                                                                                 | `1` forces it on, `0` forces it off                                                                       |
| `OLLAMA_KV_CACHE_TYPE`     | `f16`                                                                                                                | `q8_0` / `q4_0`. Global, needs flash attention                                                            |
| `OLLAMA_MODELS`            | `~/.ollama/models` (macOS), `/usr/share/ollama/.ollama/models` (Linux service), `C:\Users\%username%\.ollama\models` | Model store                                                                                               |
| `OLLAMA_ORIGINS`           | localhost origins                                                                                                    | Extra CORS origins (browser extensions, web UIs)                                                          |
| `OLLAMA_NO_CLOUD`          | unset                                                                                                                | `1` disables cloud models and web search (also `"disable_ollama_cloud": true` in `~/.ollama/server.json`) |
| `OLLAMA_VULKAN`            | enabled when available                                                                                               | `0` disables the Vulkan backend                                                                           |
| `OLLAMA_GPU_OVERHEAD`      | `0`                                                                                                                  | Bytes of VRAM to reserve per GPU                                                                          |
| `OLLAMA_LOAD_TIMEOUT`      | `5m`                                                                                                                 | How long a stalled model load may take before Ollama gives up                                             |
| `OLLAMA_DEBUG`             | unset                                                                                                                | `1` for verbose logs                                                                                      |

`ollama serve --help` lists all of them for the installed version.

Where to set them:

- **macOS app:** `launchctl setenv OLLAMA_CONTEXT_LENGTH 32768`, then quit and reopen Ollama. These values don't survive a reboot.
- **Linux service:** `sudo systemctl edit ollama`, add `[Service]` / `Environment="OLLAMA_CONTEXT_LENGTH=32768"`, then `sudo systemctl daemon-reload && sudo systemctl restart ollama`.
- **Windows:** quit from the tray, set the user environment variable, then start Ollama from the Start menu.
- **Foreground:** `OLLAMA_CONTEXT_LENGTH=32768 ollama serve`. Quit the app first so the two don't both use 11434.

## Operating

- Start/stop: the app or tray item; `ollama serve` (foreground); Linux: `sudo systemctl start|stop|restart ollama`.
- Load/unload: `ollama run <m> ""` preloads; `ollama stop <m>` unloads.
- Logs: macOS `~/.ollama/logs/server.log`; Linux `journalctl -u ollama --no-pager --follow --pager-end`; Windows `%LOCALAPPDATA%\Ollama\server.log`.
- Update: macOS/Windows apps update themselves ("Restart to update"); Linux re-runs the install script (`OLLAMA_VERSION=<ver>` pins a version).
- Disk: `ollama ls` shows sizes; `ollama rm <model>` deletes. Blobs are shared between tags.

## Tuning knobs worth knowing

- Per-request context: `"options": {"num_ctx": 32768}` on `/api/chat` and `/api/generate`. In the REPL: `/set parameter num_ctx 32768`. Over `/v1`, use the server default or a Modelfile with `PARAMETER num_ctx`.
- Check `ollama ps`: `PROCESSOR` should read `100% GPU`. Any CPU share means the model plus context doesn't fit, so reduce the context or pick a smaller quant.
- `OLLAMA_KV_CACHE_TYPE=q8_0` roughly halves KV memory with little quality loss.
- Import a GGUF: a Modelfile with `FROM ./model.gguf`. LoRA adapters are rejected on current versions (`ADAPTER` fails with "LoRA adapters are no longer supported"), so merge a fine-tune into the base and import the merged GGUF.

## Known pitfalls

- **Truncated prompts / agents "forgetting":** the default context is only 4k on smaller GPUs. Raise `OLLAMA_CONTEXT_LENGTH`.
- **403 behind a proxy or tunnel while bound to localhost:** Ollama rejects unfamiliar `Host` headers when it listens on loopback (allowed: `localhost`, the machine hostname, `*.local`, `*.localhost`, `*.internal`, private IPs). Set the proxy's Host header to `localhost:11434`, as the FAQ shows for nginx, ngrok, and cloudflared.
- **No API key:** setting `OLLAMA_HOST=0.0.0.0` exposes the server unauthenticated to the whole network. See `sharing-on-lan.md`.
- **Two servers on 11434:** the desktop app and a manual `ollama serve`, or Windows and WSL2. Stop one.
- **Proxy env:** set `HTTPS_PROXY` only. `HTTP_PROXY` can break client connections.

## Official links

- Docs: https://docs.ollama.com
- FAQ: https://docs.ollama.com/faq
- OpenAI compatibility: https://docs.ollama.com/api/openai-compatibility
- Anthropic compatibility: https://docs.ollama.com/api/anthropic-compatibility
- GPU support: https://docs.ollama.com/gpu
- Modelfile: https://docs.ollama.com/modelfile
- Source: https://github.com/ollama/ollama
