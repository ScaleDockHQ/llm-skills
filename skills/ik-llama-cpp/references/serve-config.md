# Serve ik_llama.cpp (llama-server flags)

> Verified against ik_llama.cpp main (89bba35c), docs/parameters.md and examples/server/README.md, 2026-10-11

`llama-server` is the OpenAI-compatible HTTP server (llama.cpp lineage). The flag lists below come from upstream `docs/parameters.md`, which says it is not exhaustive. Always check `llama-server --help` of your build.

## First command

```bash
./build/bin/llama-server -m /models/model.gguf -a my-model \
  --host 127.0.0.1 --port 8080 -c 32768 -ngl 999 \
  --jinja --api-key-file ~/.config/ik-llama/api-keys.txt --metrics
```

## Core flags

| Flag                             | Default              | Notes                                                                  |
| -------------------------------- | -------------------- | ---------------------------------------------------------------------- |
| `-m, --model`                    | `models/$filename`   | GGUF path; for sharded files pass the first part                       |
| `-a, --alias`                    | none                 | Model name reported by the API                                         |
| `-c, --ctx-size`                 | 0 (from model)       | Split across `-np` slots                                               |
| `-np, --parallel`                | 1                    | Parallel sequences                                                     |
| `-b / -ub`                       | 2048 / 512           | Logical / physical batch                                               |
| `-t, --threads`                  | 4                    | Match physical cores, avoid odd values                                 |
| `-tb, --threads-batch`           | same as `-t`         | Use a low value (for example 2) with full GPU offload                  |
| `-fa, --flash-attn`              | on                   | `auto`/`on`/`off`                                                      |
| `-ngl, --gpu-layers`             | 999                  | Layers in VRAM                                                         |
| `--host / --port`                | `127.0.0.1` / `8080` | Loopback by default                                                    |
| `--api-key / --api-key-file`     | none                 | Clients send `Authorization: Bearer ...`                               |
| `--webui`                        | auto                 | `none`, `auto`, `llamacpp`                                             |
| `--jinja`                        | model template       | Needed for tool calling                                                |
| `--mlock / -nmm`                 | off                  | Pin in RAM / disable mmap                                              |
| `--no-warmup`                    | warmup on            | Skip the empty warmup run                                              |
| `--timeout`                      | 600 s                | Read/write timeout (server README)                                     |
| `--ssl-key-file/--ssl-cert-file` | none                 | Needs a build with SSL (`docs` section "Build with SSL")               |
| `--slot-save-path`               | disabled             | Enables slot save/restore endpoints                                    |
| `--metrics`                      | disabled             | Prometheus `/metrics`                                                  |
| `--no-context-shift`             | shift on             | Disable context shifting                                               |
| `--minilog`                      | off                  | Log request and response bodies; contains prompts, handle as sensitive |

## Hybrid and fit flags

`--fit`, `--fit-margin N` (MiB, default 1024), `--gpu-fit-margin GPU,M,...`, `--cpu-moe`, `--n-cpu-moe N`, `-ot/--override-tensor`, `-ts`, `-sm`, `-dev`, `-mg`: see `references/parallelism-multinode.md`.

## Environment variables

Documented in the server README (they override CLI args): `LLAMA_ARG_MODEL`, `LLAMA_ARG_MODEL_ALIAS`, `LLAMA_ARG_THREADS`, `LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_N_PARALLEL`, `LLAMA_ARG_BATCH`, `LLAMA_ARG_UBATCH`, `LLAMA_ARG_N_GPU_LAYERS`, `LLAMA_ARG_CHAT_TEMPLATE`, `LLAMA_ARG_ENDPOINT_METRICS=1`, `LLAMA_ARG_FLASH_ATTN`, `LLAMA_ARG_HOST`, `LLAMA_ARG_PORT`, `LLAMA_CACHE`, `HF_TOKEN` (read from the environment, never pass on the command line).

CUDA and runtime variables from `docs/parameters.md`: `CUDA_VISIBLE_DEVICES`, `GGML_CUDA_NO_PINNED`, `GGML_CUDA_NO_PINNED_WEIGHTS` (keep CPU-resident weights mmapped to save RAM in hybrid runs), `GGML_CUDA_HOST_MALLOC_THP`. `docs/build.md` adds `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` (Linux, swap to RAM instead of crashing on VRAM exhaustion; slow).

## Load-time behaviour for big MoE models

- `-dexp, --defer-experts`: fault in expert pages on demand (Linux), cutting cold-start latency.
- `-prexp, --prefetch-experts` with `-prexp-t N`: stream mmapped experts into the page cache.
- `-dr, --dry-run`: skip tensor loading but print the memory plan and report OOM, for tuning without waiting for the load.
- `-vq, --validate-quants`: report tensors with NaNs when loading.

## Web UI

The server serves its own web UI at `/`. `--webui none` disables it. `--ui-mcp-proxy` (experimental CORS proxy for MCP servers) must not be enabled in untrusted environments.

## Verify

```bash
curl -s 'http://127.0.0.1:8080/health?include_slots=1' | jq .
curl -s http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
```
