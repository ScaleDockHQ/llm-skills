# llama.cpp: serve configuration

> Verified against llama.cpp b11556 (master, tools/server/README.md) and v0.6.0, 2026-10-11

`llama-server --help` is the authority for the installed binary. Almost every flag has a `LLAMA_ARG_*` environment variable (shown in `--help`); a flag on the command line wins over the env var. Boolean env values: `true/1/on/enabled` and `false/0/off/disabled`.

## Bind, port, auth

| Flag / env                                                                 | Meaning                                                                                            |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `--host`, `LLAMA_ARG_HOST`                                                 | Comma-separated addresses or `.sock` paths. Default `127.0.0.1`.                                   |
| `--port`, `LLAMA_ARG_PORT`                                                 | Default **9931** on master (since b11521); **8080** in v0.6.0 and older. Always pass it.           |
| `--api-key KEY[,KEY2]`, `LLAMA_API_KEY`                                    | Bearer keys. Visible in `ps`; prefer the file form.                                                |
| `--api-key-file FNAME`, `LLAMA_ARG_API_KEY_FILE`                           | One key per line, `#` comments. Keep it `0600`.                                                    |
| `--ssl-key-file`, `--ssl-cert-file`                                        | PEM files; needs a build with `-DLLAMA_OPENSSL=ON`.                                                |
| `--api-prefix PREFIX`                                                      | Serve under a path prefix, no trailing slash (reverse proxies).                                    |
| `--cors-origins`, `--cors-methods`, `--cors-headers`, `--cors-credentials` | CORS; default origins `*`. `localhost` reflects only localhost origins.                            |
| `-to, --timeout N`                                                         | Read/write timeout seconds (default 3600). `--sse-ping-interval N` (default 30).                   |
| `--threads-http N`                                                         | HTTP worker threads.                                                                               |
| `--ui/--no-ui` (alias `--webui`)                                           | Built-in Web UI (default on). `--ui-config JSON`, `--ui-config-file PATH` set default UI settings. |
| `--path PATH`                                                              | Serve static files from a directory.                                                               |

`/health` (also `/v1/health`) is public: 503 while loading, 200 when ready. Clients send `Authorization: Bearer <key>`; Anthropic-style clients send `x-api-key`.

## Model selection

| Flag                                             | Meaning                                                                                                                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `-m, --model FNAME`                              | Local GGUF (first shard of a split model is enough).                                                                                       |
| `-hf, -hfr, --hf-repo <user>/<model>[:quant]`    | Download from Hugging Face. Quant defaults to Q4_K_M, or the first file in the repo if absent. Also fetches `mmproj` unless `--no-mmproj`. |
| `-hff, --hf-file FILE`                           | Exact file, overrides the quant tag.                                                                                                       |
| `-hft, --hf-token`                               | Token; defaults to the `HF_TOKEN` environment variable. Do not put tokens on the command line.                                             |
| `-mu, --model-url URL`, `-dr, --docker-repo`     | Download from a URL or Docker Hub model repository (default namespace `ai/`).                                                              |
| `-a, --alias A[,B]`                              | Names accepted in requests and listed by `/v1/models`.                                                                                     |
| `--offline`, `LLAMA_CACHE`                       | Use cache only; relocate the download cache. `-cl, --cache-list` lists it.                                                                 |
| `--mmproj FILE`, `--no-mmproj`                   | Multimodal projector, see `references/features.md`.                                                                                        |
| `--lora FNAME[,..]`, `--lora-scaled FNAME:SCALE` | Load LoRA adapters; `--lora-init-without-apply` loads without applying (apply via `POST /lora-adapters`).                                  |
| `--override-kv KEY=TYPE:VALUE`                   | Override GGUF metadata.                                                                                                                    |
| `--override-tensor`, `-ot PATTERN=BUFTYPE`       | Place tensors on devices (MoE offload).                                                                                                    |

Download pre-fetched models in the stack instead of `-hf` at start: a start-time download delays `/health` and fails offline.

## Context, slots, batching

| Flag                                | Default                | Notes                                                                                                                  |
| ----------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `-c, --ctx-size N`                  | 0 (model max)          | Total context. With several slots it is shared: see `-kvu`.                                                            |
| `-np, --parallel N`                 | -1 (auto)              | Server slots (concurrent sequences).                                                                                   |
| `-kvu, --kv-unified`                | on when slots are auto | One KV buffer shared by all sequences. `--kv-unified-per-slot N` sizes the pool as `np*N` when `-c` is unset.          |
| `-b, --batch-size`, `-ub`           | 2048 / 512             | Logical and physical batch. Larger `-ub` speeds prompt processing, uses more memory.                                   |
| `-cb/--no-cont-batching`            | on                     | Continuous batching.                                                                                                   |
| `-n, --predict N`                   | -1                     | Default max tokens.                                                                                                    |
| `--context-shift`                   | off                    | Shift context on infinite generation.                                                                                  |
| `--cache-prompt`, `--cache-reuse N` | on, 0                  | Prompt cache and KV shifting for chunk reuse.                                                                          |
| `-cram, --cache-ram N`              | 8192 MiB               | Host-RAM prompt cache (-1 unlimited, 0 off). `--cache-idle-slots` saves idle slots into it.                            |
| `-ctxcp, --ctx-checkpoints N`       | 32                     | Context checkpoints per slot (SWA/hybrid models); `-cms` sets min spacing (8192 tokens).                               |
| `-sps, --slot-prompt-similarity`    | 0.10                   | Min prompt match to reuse a slot.                                                                                      |
| `--slot-save-path PATH`             | off                    | Enables slot save/restore endpoints.                                                                                   |
| `--sleep-idle-seconds N`            | -1 (off)               | Unload model and KV when idle; the next request reloads it. `/health`, `/props`, `/models`, `/metrics` do not wake it. |

## Devices and memory

`-ngl/--n-gpu-layers N|auto|all` (default auto), `--fit on|off` with `--fit-target MiB` and `--fit-ctx N` (auto-fit unset arguments to device memory, default on, margin 1024 MiB, min ctx 4096), `-fa on|off|auto`, `-ctk/-ctv` KV types, `-dev/--device`, `--list-devices`, `-sm none|layer|row|tensor`, `-ts`, `-mg`, `-cmoe/-ncmoe`, `-t/-tb` threads, `--numa distribute|isolate|numactl`, `-lm/--load-mode auto|none|mmap|mlock|mmap+mlock|dio`, `--no-host`, `--no-repack`, `--no-kv-offload`. Detail in `references/performance-tuning.md` and `references/parallelism-multinode.md`.

## Chat, tools, reasoning

`--jinja/--no-jinja` (default on), `--chat-template NAME`, `--chat-template-file FILE`, `--chat-template-kwargs JSON`, `--reasoning-format none|deepseek|deepseek-legacy` (default auto), `-rea/--reasoning on|off|auto`, `--reasoning-effort LEVEL`, `--reasoning-budget N`, `--reasoning-budget-message`, `--reasoning-preserve`, `--skip-chat-parsing`, `--prefill-assistant`. See `references/features.md`.

## Sampling defaults (server-side)

`--temp` 0.80, `--top-k` 40, `--top-p` 0.95, `--min-p` 0.05, `--repeat-penalty` 1.0, plus DRY, XTC, mirostat, `--samplers`, `--seed`. Requests override them per call. Use the model card's recommended values and set them once with flags or in a router preset rather than in every client.

## Endpoints toggles

`--metrics` (off), `--props` (allow `POST /props`, off), `--slots/--no-slots` (on), `--embedding` (embedding-only server), `--rerank`, `--pooling none|mean|cls|last|rank`, `--embd-normalize N`, `--media-path PATH` (allow `file://` media under a directory), `--log-prompts-dir PATH` (debug only: writes prompts to disk).

## Experimental and unsafe by default

`--tools TOOL1,..|all` (read_file, file_glob_search, grep_search, exec_shell_command, write_file, edit_file, get_info), `--tools-runtime docker:<image>|podman:<image>|ssh:<target>`, `--mcp-servers-config PATH`, `--mcp-servers-json JSON`, `--ui-mcp-proxy`, `-ag/--agent`. These give the model file and shell access or a CORS proxy. Upstream says not to enable them in untrusted environments; they restrict CORS to localhost by default. Never combine with `--host 0.0.0.0`.

## Logging

`--log-file FNAME`, `--log-jsonl`, `--log-colors on|off|auto`, `-lv/--verbosity 0..5` (default 3), `-v/--verbose`, `--log-timestamps`, `--log-prefix`, `--perf`.

## Router mode (multiple models in one server)

Start `llama-server` **without** a model. The router process forwards each request to a child `llama-server` per model, loading and unloading on demand.

Sources of models:

1. The cache (`LLAMA_CACHE`; add with `llama-server -hf <user>/<model>:<tag>`; restart after adding).
2. `--models-dir ./models` containing GGUFs. Multimodal or sharded models go in a subdirectory; the projector file name must start with `mmproj`.
3. `--models-preset ./models.ini`.

Router flags: `--models-max N` (default 4, 0 = unlimited loaded at once), `--models-autoload/--no-models-autoload`. Flags given on the router command line are inherited by every model (`llama-server -c 8192 -np 2`). The router controls host, port, API key, HF repo and alias for children.

Preset INI (`templates/models.ini`): each section is a preset; keys are flags without dashes, short forms (`c`, `ngl`) or env names. `[*]` holds global defaults. Precedence: command line, then model section, then `[*]`. Preset-only keys: `load-on-startup` (bool), `stop-timeout` (seconds, default 10), `dedup-cache-models` (bool). A section whose name is not an existing model needs `model` or `hf-repo`. Paths are relative to the server's CWD; use absolute paths.

API: `GET /models` (status `loaded`/`unloaded`/loading), `POST /models/load` and `/models/unload` with `{"model": "<id>"}`, `GET /models/sse`, `POST /models` (download) and `DELETE /models`. Requests route by the `model` field (POST) or `?model=` query (GET like `/props`, `/metrics`). `?autoload=true|false` per request.

Router mode does its own loading. Do not put it behind llama-swap for the same models (double swapping). Choosing between the two is covered in `references/combos/llama-swap-router.md`.

## Running as a service

- Linux: `templates/llama-server.service` (systemd user unit; `loginctl enable-linger $USER` to survive logout).
- macOS: `templates/llama-server.launchd.plist` (LaunchAgent; replace `__HOME__`).
- Containers: `templates/docker-compose.yml`, `templates/k8s.yaml`.
- Environment-driven config (compose example from upstream): `LLAMA_ARG_MODEL`, `LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_N_PARALLEL`, `LLAMA_ARG_ENDPOINT_METRICS`, `LLAMA_ARG_PORT`.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
