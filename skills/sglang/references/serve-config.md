# SGLang: serve configuration

> Verified against SGLang v0.5.21 (docs: advanced_features/server_arguments, references/environment_variables; `srt/utils/auth.py`; `cli/main.py`), 2026-10-11

Authoritative flag list: `python3 -m sglang.launch_server --help` on the installed version, and `/server_info` for the effective values of a running server. Defaults below are from the v0.5.21 docs.

## Entry points

```bash
python3 -m sglang.launch_server --model-path <hf-id-or-dir> [flags]
sglang serve <hf-id-or-dir> [flags]          # positional model path; same flags; --model-type selects a backend (LLM vs diffusion)
sglang version                              # version + git revision
killall_sglang                              # kill leftover server processes (be careful on shared hosts)
python -m sglang_router.launch_server ...   # DP launcher with router (flags: --dp, --tp)
```

Config file: `--config config.yaml` (flag names without leading `--`, CLI wins on conflicts). Template: `templates/config.yaml`.

## Core flags

| Flag                                                             | Default               | Notes                                                                                                      |
| ---------------------------------------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------- |
| `--model-path` / `--model`                                       | none                  | HF repo ID or local dir.                                                                                   |
| `--served-model-name`                                            | model path            | Name returned by `/v1/models`; set it to the name your gateway uses.                                       |
| `--host` / `--port`                                              | `127.0.0.1` / `30000` | Upstream examples use `0.0.0.0` inside containers.                                                         |
| `--context-length`                                               | from model config     | Cap it to save KV memory. Longer than the model's own needs `SGLANG_ALLOW_OVERWRITE_LONGER_CONTEXT_LEN=1`. |
| `--dtype`                                                        | `auto`                | `bfloat16`, `float16` (AWQ prefers `half`).                                                                |
| `--trust-remote-code`                                            | off                   | Only for repos you trust.                                                                                  |
| `--revision`                                                     | latest                | Pin a branch, tag or commit for reproducibility.                                                           |
| `--tokenizer-path`, `--chat-template`, `--hf-chat-template-name` | auto                  | Use `--chat-template` for models without one; `--hf-chat-template-name tool_use` picks a named template.   |
| `--default-chat-template-kwargs`                                 | none                  | JSON defaults for `chat_template_kwargs` (for example disable thinking).                                   |
| `--is-embedding`                                                 | off                   | Serve a decoder LM as an embedding model (native encoders are auto-detected).                              |
| `--enable-multimodal`                                            | none                  | Force-enable multimodal handling.                                                                          |
| `--config`                                                       | none                  | YAML file with flags.                                                                                      |

## Memory and scheduling

| Flag                                                                                                  | Default        | Notes                                                                                                        |
| ----------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------ |
| `--mem-fraction-static`                                                                               | auto heuristic | Fraction of GPU memory for weights + KV pool. Lower on OOM; raise for capacity. See `performance-tuning.md`. |
| `--max-running-requests`                                                                              | auto           | Cap concurrent decodes.                                                                                      |
| `--max-queued-requests`                                                                               | none           | Reject beyond this queue length (ignored in PD disaggregation).                                              |
| `--max-total-tokens`                                                                                  | auto           | Size of the KV token pool.                                                                                   |
| `--chunked-prefill-size`                                                                              | auto           | Tokens per prefill chunk; `-1` disables; try `4096`/`2048` on prefill OOM.                                   |
| `--max-prefill-tokens`                                                                                | `16384`        | Per prefill batch.                                                                                           |
| `--schedule-policy`                                                                                   | `fcfs`         | `lpm` (longest prefix match), `random`, `dfs-weight`, `lof`, `priority`, `routing-key`.                      |
| `--schedule-conservativeness`                                                                         | `1.0`          | Lower (0.3) if `token usage` is low with a queue; higher (1.3) if you see repeated retraction.               |
| `--page-size`                                                                                         | `1`            | KV page size; some attention backends need larger.                                                           |
| `--kv-cache-dtype`                                                                                    | `auto`         | `fp8_e4m3`, `fp8_e5m2`, `bf16`; also `nvfp4`, `fp4_mx_block16` (need CUDA 12.8+ and PyTorch 2.8+).           |
| `--disable-radix-cache`                                                                               | off            | Disables RadixAttention prefix caching. A/B only.                                                            |
| `--radix-eviction-policy`                                                                             | `lru`          | Or `lfu`.                                                                                                    |
| `--enable-priority-scheduling`                                                                        | off            | Request `priority` field.                                                                                    |
| `--watchdog-timeout`                                                                                  | `300`          | Seconds a forward may take before the server crashes itself.                                                 |
| `--enable-hierarchical-cache`, `--hicache-ratio` (2.0), `--hicache-size`, `--hicache-storage-backend` | off            | HiCache host/storage KV tiers; see `features.md`.                                                            |

## CUDA graphs and kernels

CUDA graph flags changed in the 0.5.2x line. In v0.5.21 docs:

- `--cuda-graph-max-bs-decode N`, `--cuda-graph-bs-decode a b c`, `--cuda-graph-backend-decode`, and prefill equivalents (`--cuda-graph-max-bs-prefill`, `--cuda-graph-backend-prefill`, `--cuda-graph-max-seq-len-prefill`), plus `--cuda-graph-config '<json>'`.
- `--disable-cuda-graph` is deprecated; use `--disable-decode-cuda-graph` / `--disable-prefill-cuda-graph` (or `--cuda-graph-backend-decode=disabled`). Old guides and blog posts that say `--cuda-graph-max-bs` are outdated for this version.
- `--attention-backend`: `flashinfer`, `fa3`, `fa4`, `triton`, `torch_native`, `flex_attention`, `flashmla`, `trtllm_mla`, `trtllm_mha`, `cutedsl_mla`, `aiter`, `wave`, `intel_amx`, `ascend`, `intel_xpu`, `dsa`/`nsa`, `dsv4`, `compressed`, `tokenspeed_mla`. Separate `--prefill-attention-backend` / `--decode-attention-backend` override it. Leave on auto unless a model card or a bug says otherwise.
- `--sampling-backend`, `--grammar-backend` (`xgrammar` default, `outlines`, `llguidance`, `none`), `--fp8-gemm-backend`, `--fp4-gemm-backend`, `--bf16-gemm-backend`, `--moe-runner-backend`, `--moe-a2a-backend`.
- `--disable-overlap-schedule` turns off CPU/GPU overlap scheduling (some speculative modes already disable it).
- `--enable-torch-compile`: marked experimental and "out of maintenance" in the docs.

## API behavior

| Flag                                                | Notes                                                                                                                                                                                                                                                                          |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--api-key`                                         | Bearer key for the OpenAI-compatible API. `/health*`, `/ready*`, `/metrics` stay open by design.                                                                                                                                                                               |
| `--admin-api-key`                                   | Protects admin-class endpoints (weight updates, cache flush, profiling, HiCache storage control). When set, only it unlocks them and `--api-key` is refused there; on its own it does NOT protect the normal API. Set both keys on any reachable server (details in `api.md`). |
| `--tool-call-parser`, `--reasoning-parser`          | A name or `auto`; see `features.md`.                                                                                                                                                                                                                                           |
| `--sampling-defaults`                               | `model` (default; use the model's generation config) or `openai`.                                                                                                                                                                                                              |
| `--enable-cache-report`                             | Cached token counts in `usage.prompt_tokens_details`.                                                                                                                                                                                                                          |
| `--stream-interval`                                 | Tokens per stream chunk.                                                                                                                                                                                                                                                       |
| `--stream-response-default-include-usage`           | Usage in every stream chunk set.                                                                                                                                                                                                                                               |
| `--allowed-media-domains`                           | Hostname allowlist for remote image/video/audio URLs (exact match, redirects checked). Unset means any domain: set it for untrusted clients. `--media-url-max-file-size-mb` defaults to 64.                                                                                    |
| `--enable-custom-logit-processor`                   | Off by default for security.                                                                                                                                                                                                                                                   |
| `--allow-auto-truncate`                             | Truncate over-long inputs instead of erroring.                                                                                                                                                                                                                                 |
| `--ssl-keyfile`, `--ssl-certfile`, `--ssl-ca-certs` | Native TLS; `--enable-ssl-refresh` hot-reloads.                                                                                                                                                                                                                                |
| `--enable-http2`                                    | Granian instead of Uvicorn (needs `pip install 'sglang[http2]'`).                                                                                                                                                                                                              |
| `--grpc-mode`                                       | gRPC server instead of HTTP (used by the gateway).                                                                                                                                                                                                                             |

## Parallelism flags (summary)

`--tp-size`/`--tp`, `--pp-size`, `--dp-size`/`--dp`, `--ep-size`/`--ep`, `--enable-dp-attention`, `--moe-dp-size`, `--dcp-size`, `--attn-cp-size`, `--nnodes`, `--node-rank`, `--dist-init-addr`, `--base-gpu-id`, `--gpu-id-step`, `--enable-p2p-check`. Details in `parallelism-multinode.md`.

## Logging and metrics flags

`--log-level`, `--log-requests` (+ `--log-requests-level`, default 2 = full text), `--enable-metrics`, `--enable-mfu-metrics`, `--enable-trace` (`--otlp-traces-endpoint localhost:4317`), `--crash-dump-folder`, `--decode-log-interval` (40), `--extra-metric-labels`, `--bucket-time-to-first-token` and friends. See `observability.md`. `--log-requests` writes prompts and outputs to logs: treat logs as sensitive.

## Environment variables worth knowing

| Variable                                               | Effect                                                                                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `HF_TOKEN`, `HF_HOME`, `HF_HUB_OFFLINE`                | Hugging Face auth, cache location, offline mode.                                                                                    |
| `SGLANG_USE_MODELSCOPE=true`                           | Fetch from ModelScope.                                                                                                              |
| `SGLANG_HOST_IP`                                       | Host IP for the server (default `0.0.0.0` per env docs; the CLI `--host` default is `127.0.0.1`). Check which wins on your version. |
| `SGLANG_ALLOW_OVERWRITE_LONGER_CONTEXT_LEN=1`          | Permit `--context-length` above the model's config value.                                                                           |
| `SGLANG_SET_CPU_AFFINITY=1`                            | CPU affinity pinning (set in the Docker builds).                                                                                    |
| `SGLANG_CACHE_DIR`                                     | Cache root for compiled kernels, FlashInfer autotune and DeepGEMM; persist it on a volume to speed restarts.                        |
| `SGLANG_TORCH_PROFILER_DIR`                            | Output dir for the torch profiler (default `/tmp`).                                                                                 |
| `SGLANG_USE_AITER=1`                                   | AMD Aiter kernels.                                                                                                                  |
| `SGLANG_USE_MLX=1`                                     | Apple MLX backend.                                                                                                                  |
| `NCCL_SOCKET_IFNAME`, `NCCL_IB_HCA`, `NCCL_DEBUG=INFO` | Multi-node networking and diagnostics.                                                                                              |

The full list is in `references/environment_variables` upstream (hundreds of entries, many internal).

## Security checklist

- Default bind is loopback. Publish with `-p 127.0.0.1:PORT:30000` behind a gateway.
- Do not use `--network host` with `--host 0.0.0.0` on an exposed machine without `--api-key` and a firewall.
- Never put keys on the command line of a shared host (visible in `ps` and `/server_info`): use a config file with mode `0600` or the gateway for auth. `/server_info` returns the resolved server args and `launch_command` (anything on the command line, including `--api-key`), so treat it as sensitive.
- Keep `--enable-custom-logit-processor` off, set `--allowed-media-domains` for multimodal servers facing untrusted users, and `--trust-remote-code` only for audited repos.
