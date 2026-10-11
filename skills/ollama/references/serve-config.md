# Ollama: serve configuration

> Verified against Ollama v0.40.3, 2026-10-11

Envconfig/config.go, docs: faq, context-length, gpu, docker, linux

Ollama is configured with environment variables only (plus `~/.ollama/server.json` for one cloud flag). `ollama serve --help` lists the variables of the installed version. Check the effective values with the discovery block in `SKILL.md`.

## Where to set them

- **macOS app:** `launchctl setenv OLLAMA_CONTEXT_LENGTH 32768` for each variable, then quit and reopen the app. They do not survive a reboot; re-run or use a LaunchAgent.
- **macOS Homebrew service:** edit the plist or run `OLLAMA_...=... ollama serve` yourself.
- **Linux systemd:** `sudo systemctl edit ollama` and add under `[Service]`, or write `/etc/systemd/system/ollama.service.d/override.conf` (`templates/ollama.service.d/override.conf`), then `sudo systemctl daemon-reload && sudo systemctl restart ollama`.
- **Windows:** quit the tray app, set user environment variables (Settings, search "environment variables"), start Ollama from the Start menu.
- **Docker:** `-e VAR=value` or the `environment:` block (`templates/docker-compose.yml`).
- **Foreground:** `OLLAMA_CONTEXT_LENGTH=64000 ollama serve` (quit the app first).

## Variables

| Variable                                                                                                               | Default                                                | Purpose                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OLLAMA_HOST`                                                                                                          | `127.0.0.1:11434` (container image: `0.0.0.0:11434`)   | Bind address and port. `0.0.0.0:11434` listens on every interface                                                                                                          |
| `OLLAMA_ORIGINS`                                                                                                       | localhost origins                                      | Extra CORS origins, comma separated (browser extensions: `chrome-extension://*,moz-extension://*,safari-web-extension://*`)                                                |
| `OLLAMA_MODELS`                                                                                                        | per OS, see below                                      | Model store directory. On Linux the `ollama` user needs read/write (`sudo chown -R ollama:ollama <dir>`)                                                                   |
| `OLLAMA_CONTEXT_LENGTH`                                                                                                | 4k (<24 GiB VRAM), 32k (24 to 48 GiB), 256k (>=48 GiB) | Default context unless a request or model says otherwise. Cloud models default to their maximum                                                                            |
| `OLLAMA_KEEP_ALIVE`                                                                                                    | `5m`                                                   | Time an idle model stays loaded. Duration string (`10m`, `24h`), seconds, negative = forever, `0` = unload after each response                                             |
| `OLLAMA_MAX_LOADED_MODELS`                                                                                             | 3 x GPUs (3 on CPU)                                    | Models loaded at once per GPU, if they fit                                                                                                                                 |
| `OLLAMA_NUM_PARALLEL`                                                                                                  | `1`                                                    | Parallel requests per model. Memory scales with this times the context                                                                                                     |
| `OLLAMA_MAX_QUEUE`                                                                                                     | `512`                                                  | Queued requests before HTTP 503                                                                                                                                            |
| `OLLAMA_LOAD_TIMEOUT`                                                                                                  | `5m`                                                   | How long a stalled model load may take                                                                                                                                     |
| `OLLAMA_FLASH_ATTENTION`                                                                                               | auto when supported                                    | `1` forces on, `0` forces off                                                                                                                                              |
| `OLLAMA_KV_CACHE_TYPE`                                                                                                 | `f16`                                                  | `q8_0` (about half the KV memory) or `q4_0` (about a quarter). Global; needs flash attention                                                                               |
| `OLLAMA_SCHED_SPREAD`                                                                                                  | off                                                    | Always spread a model across all GPUs instead of the fewest that fit                                                                                                       |
| `OLLAMA_GPU_OVERHEAD`                                                                                                  | `0`                                                    | Bytes of VRAM to reserve per GPU                                                                                                                                           |
| `OLLAMA_VULKAN`                                                                                                        | on when available                                      | `0` disables the Vulkan backend                                                                                                                                            |
| `OLLAMA_IGPU_ENABLE`                                                                                                   | unset                                                  | Allow integrated GPUs                                                                                                                                                      |
| `OLLAMA_LLM_LIBRARY`                                                                                                   | autodetect                                             | Force a backend library (for example `cpu_avx2`); experimental, for crashes                                                                                                |
| `OLLAMA_NOPRUNE`                                                                                                       | off                                                    | Do not prune unused blobs at startup (needed when several servers share one store)                                                                                         |
| `OLLAMA_NO_CLOUD`                                                                                                      | off                                                    | `1` disables cloud models and web search (same as `"disable_ollama_cloud": true` in `~/.ollama/server.json`); the log then shows `Ollama cloud disabled: true`             |
| `OLLAMA_REMOTES`                                                                                                       | `ollama.com`                                           | Allowed hosts for remote models                                                                                                                                            |
| `OLLAMA_MAX_TRANSFER_STREAMS`                                                                                          | `4`                                                    | Parallel streams for safetensors pulls and pushes                                                                                                                          |
| `OLLAMA_CREATE_REMOTE`                                                                                                 | off                                                    | Force `ollama create` through the server API even when it is local                                                                                                         |
| `OLLAMA_GO_TEMPLATE`                                                                                                   | on                                                     | Use Modelfile `TEMPLATE` rendering when a model has one                                                                                                                    |
| `OLLAMA_DEBUG`                                                                                                         | off                                                    | `1` for debug logs (also shows GPU discovery detail)                                                                                                                       |
| `OLLAMA_DEBUG_LOG_REQUESTS`                                                                                            | off                                                    | Log inference request bodies and replay curl commands to a temp directory (contains prompts; treat as sensitive)                                                           |
| `OLLAMA_NOHISTORY`, `OLLAMA_EDITOR`                                                                                    | unset                                                  | CLI only: no readline history; editor for Ctrl+G                                                                                                                           |
| `OLLAMA_TMPDIR`                                                                                                        | system tmp                                             | Where temporary executables go; set it when `/tmp` is `noexec` (documented in troubleshooting)                                                                             |
| `HTTPS_PROXY`, `NO_PROXY`                                                                                              | unset                                                  | Outbound proxy for model pulls. Do not set `HTTP_PROXY`; it can break client connections to the server                                                                     |
| `CUDA_VISIBLE_DEVICES`, `HIP_VISIBLE_DEVICES`, `ROCR_VISIBLE_DEVICES`, `GPU_DEVICE_ORDINAL`, `GGML_VK_VISIBLE_DEVICES` | unset                                                  | Restrict which GPUs are used. Prefer UUIDs for NVIDIA (`nvidia-smi -L`); an invalid ID such as `-1` forces CPU                                                             |
| `HSA_OVERRIDE_GFX_VERSION`                                                                                             | unset                                                  | AMD only: pretend a close LLVM target, for example `10.3.0`; per device with `HSA_OVERRIDE_GFX_VERSION_0`                                                                  |
| `LLAMA_ARG_FIT`, `LLAMA_ARG_FIT_TARGET`                                                                                | on / unset                                             | Listed in `serve --help`: llama.cpp automatic memory fit and the free-VRAM margin per device in MiB. Semantics are upstream-internal; leave alone unless debugging offload |

Model store defaults: macOS `~/.ollama/models`, Linux service `/usr/share/ollama/.ollama/models`, Windows `C:\Users\%username%\.ollama\models`.

## Binding and exposure

- Default is loopback only. To listen on the LAN: `OLLAMA_HOST=0.0.0.0:11434` (or one interface address, for example a Tailscale IP). This is unauthenticated. Pair it with a firewall rule, a VPN, or a reverse proxy that adds auth (`combos/lan-and-tunnels.md`).
- The API does not check keys locally (`OLLAMA_API_KEY` is only for ollama.com). OpenAI clients need some dummy `api_key` string.
- While bound to loopback, Ollama rejects requests whose `Host` header is not `localhost`, the machine hostname, `*.local`, `*.localhost`, `*.internal`, or a private/loopback IP, with HTTP 403. Proxies and tunnels must rewrite the header to `localhost:11434` (nginx `proxy_set_header Host localhost:11434;`, `ngrok http 11434 --host-header="localhost:11434"`, `cloudflared tunnel --url http://localhost:11434 --http-host-header="localhost:11434"`). When bound to a non-loopback address this check is skipped.
- CORS: `OLLAMA_ORIGINS` for web UIs and extensions in a browser.

## Preload and keep-alive

- Preload: `ollama run <model> ""` or `curl -s http://127.0.0.1:11434/api/generate -d '{"model":"<model>"}'`.
- Keep forever: `-d '{"model":"<model>","keep_alive":-1}'` or `OLLAMA_KEEP_ALIVE=-1`. Unload: `ollama stop <model>` or `"keep_alive":0`.
- A request `keep_alive` overrides the env var on `/api/generate` and `/api/chat`; `ollama run` has `--keepalive 5m`.

## Proxy and certificates

`HTTPS_PROXY=https://proxy.example.com` (container: `-e`). Install the proxy CA as a system certificate; for Docker build an image `FROM ollama/ollama` with `COPY my-ca.pem /usr/local/share/ca-certificates/my-ca.crt` and `RUN update-ca-certificates`.

## Auto-start

Windows and macOS register a login item (disable in Task Manager Startup apps, or macOS Login Items). Linux uses `systemctl enable|disable ollama`.
