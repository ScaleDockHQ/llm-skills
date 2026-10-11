# TensorFold: serve flags and configuration

> Verified against TensorFold v1.0.7, 2026-10-11

README serve-flags table, docs/api.md, RUNBOOK.md

`tensorfold serve MODEL [flags]` (Homebrew) or `tensorfold-native serve MODEL [flags]` (archive). `MODEL` is a complete local directory (config, tokenizer, chat template, weights), a cached Hugging Face repo name, or an existing HF cache. `serve MODEL --help` prints usage without loading a model; `capabilities --json` lists the installed binary's flags, platform values and environment variables, including API keys, request logging and HF cache paths. The binary wins over this page.

## Flags (1.0.7)

| Flag                                                                                                                | Meaning                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `--host`, `--port`                                                                                                  | Listen address, default `127.0.0.1:8080`.                                                                                             |
| `--name`, `--alias`                                                                                                 | Advertised model ID; extra accepted IDs (repeatable).                                                                                 |
| `--api-key`, `--api-key-file`                                                                                       | Bearer keys (see Auth).                                                                                                               |
| `--metrics-open`                                                                                                    | `/metrics` without a key when auth is on.                                                                                             |
| `--dashboard`                                                                                                       | `/dashboard` page and `/stats` JSON.                                                                                                  |
| `--context N`                                                                                                       | Prompt + reply bound. Qwen3.8-27B defaults to 32,768, up to 262,144. `--context 0` is family-specific (use a positive value for GLM). |
| `--max-tokens N`                                                                                                    | Default reply limit, 4096.                                                                                                            |
| `--temperature`, `--top-p`, `--top-k`, `--min-p`                                                                    | Sampling defaults; zero temperature is greedy. Defaults come from the checkpoint's `generation_config.json`.                          |
| `--thinking`, `--no-thinking`, `--reasoning-effort low\|medium\|high\|xhigh`, `--thinking-budget N`, `--loop-guard` | Reasoning control.                                                                                                                    |
| `--no-drafts`                                                                                                       | Plain reference decoding through the same engine.                                                                                     |
| `--drafter`, `--drafter-bits 0\|4`                                                                                  | Qwen3.8-27B DFlash2 drafter (dir or HF repo id); without it the 27B decodes plain.                                                    |
| `--keep-warm SECONDS`                                                                                               | Metal idle keepalive, default 900; 0 off.                                                                                             |
| `--parallel N\|auto`                                                                                                | Requests sharing lanes (auto default).                                                                                                |
| `--prompt-cache-gib GIB`                                                                                            | Retained-prefix budget; 0 off. `--prompt-cache-over-cap` allows more than the default allowance (Nemotron, Flash Next).               |
| `--learn`, `--learn-dir`, `--learn-gib`, `--learn-min-free-gib`                                                     | On-disk shared-prefix states (GLM, Nemotron, Flash Next on one Mac). Defaults: `~/.cache/tensorfold/learned`, 32 GiB, 4 GiB free.     |
| `--snapshot-dir none`, `--max-snapshots 0`                                                                          | Only supported values.                                                                                                                |
| `--compact-at auto\|FRACTION`, `--compact-keep TOKENS`, `--compact-memory DIR`                                      | Context compaction.                                                                                                                   |
| `--speed-up FILE`                                                                                                   | Rank/link settings for two-Mac Flash Next or GLM.                                                                                     |
| `--chat-template FILE`                                                                                              | Override the Jinja template (16 MiB limit, read once; bad file fails startup).                                                        |
| `--slide`                                                                                                           | Living Weights (experimental).                                                                                                        |
| `--vision`                                                                                                          | Image input on supported Qwen3.5/3.8 dense checkpoints.                                                                               |
| `--backend auto`                                                                                                    | Compiled backend; `mlx` = native Metal on macOS, `cuda` on Linux.                                                                     |
| `--no-update-check`                                                                                                 | Accepted compatibility switch; update via package manager.                                                                            |

Recipes add flags their engine builds accept (`--kv-dtype`, `--tp`, `--rank`, `--master`, `--master-port`, `--vision-max-images`, `--prefill-fp8`). Those are not in the 1.0.7 README table; check `serve --help` on that build.

## Environment variables (named in upstream docs)

`TENSORFOLD_API_KEY` (comma-separated keys), `TENSORFOLD_SEED_SALT` (integer mixed into prompt-derived seeds), `TENSORFOLD_CUDA_KERNELS`, `TF_CUDA_DEVICE`, `TF_CUDA_SEGMENTS`, `GLM_LOAD_LIMIT_GB`, `TF_HEAT_HIGH` / `TF_HEAT_LOW` (set together, degrees C), `TF_HEAT_ROOT`, `TF_FLASHNEXT_DUMP` (leave unset). Full list: `capabilities --json`.

## Auth

Keys come from repeated `--api-key`, `TENSORFOLD_API_KEY`, and `--api-key-file`; they add together. A file has one key per line, optional `label: key`, `#` comments; mode must be `0600` (startup refuses a file readable by others). Send `Authorization: Bearer KEY` or `x-api-key: KEY`. `/health` stays open and returns `{"status":"ok"}` when keys are set. Rotate by replacing the file atomically (checked about once a second; SIGHUP reloads at once). A bad replacement closes authenticated routes until a valid file returns. Loopback with no keys accepts local clients; a non-loopback bind with no keys prints a warning. Use `--host 0.0.0.0` only with a key file and approval.

## Minimal and gateway-friendly launches

```bash
tensorfold-native serve ~/models/nemotron-lightning \
  --name nemotron-tf --host 127.0.0.1 --port 8090 --context 32768 --parallel 4
```

Under a supervisor, never leave the default port: 8080 collides with llama-swap. For a service unit see `templates/tensorfold.service`.
