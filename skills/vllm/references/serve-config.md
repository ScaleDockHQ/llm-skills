# vllm serve flags, environment variables and config files

> Verified against vLLM v0.31.0 (docs `cli`, `configuration/*`, `serving/online_serving`, source `vllm/config`, `vllm/envs.py`), 2026-10-11

`vllm serve <model> [flags]` starts the OpenAI-compatible server (one model per process). Always read the
authoritative list for the installed version: `vllm serve --help=all`, `--help=ModelConfig`, `--help=<flag>`,
or `--help=<keyword>`. Only flags confirmed in the v0.31.0 source are listed here.

Other CLI commands: `vllm {chat,complete,serve,launch,bench,collect-env,run-batch,preload}`; `vllm snapshot`
(experimental CRIU engine snapshots) also exists in the source.

## Precedence and config file

`command line > config file > defaults`. A config file uses the long flag names without the leading `--`:

```yaml
# config.yaml (see templates/config.yaml)
model: Qwen/Qwen3-Coder-30B-A3B-Instruct
host: 127.0.0.1
port: 8000
served-model-name: qwen-coder
max-model-len: 65536
gpu-memory-utilization: 0.80
enable-auto-tool-choice: true
tool-call-parser: qwen3_xml
```

`vllm serve --config config.yaml`. A model given on the command line overrides `model:` in the file.
vLLM Recipes (<https://recipes.vllm.ai/>) can be converted to `config.yaml` + `env.sh` with
`tools/recipes` in the repo; source `env.sh` first.

Integer flags accept suffixes: `1k` = 1000, `1K` = 1024, `1M` = 1,048,576 (applies to `--max-model-len`,
`--max-num-batched-tokens`, `--kv-cache-memory-bytes` and a few more).

## Serving and API flags

| Flag                                                                                  | Notes                                                                                                                                                                        |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--host`, `--port`                                                                    | Defaults bind all interfaces on 8000. Bind `127.0.0.1` (or publish the container port on loopback). `VLLM_HOST_IP` and `VLLM_PORT` are for internal use, not the API server. |
| `--uds PATH`                                                                          | Serve over a Unix socket.                                                                                                                                                    |
| `--served-model-name A [B ...]`                                                       | Name(s) clients send in `model`. Set it to the router's model ID.                                                                                                            |
| `--api-key KEY ...` / `VLLM_API_KEY`                                                  | Only guards `/v1` routes; other endpoints (`/health`, `/metrics`, `/tokenize`, ...) stay open. Prefer loopback + a gateway.                                                  |
| `--api-server-count N`                                                                | Several API server processes behind one port.                                                                                                                                |
| `--enable-request-id-headers`                                                         | Honor `X-Request-Id`. `X-Vllm-Priority` needs priority scheduling.                                                                                                           |
| `--enable-log-requests`                                                               | Log request bodies (v0.31.0 flag). Off by default; contains prompts, so treat logs as sensitive.                                                                             |
| `--disable-log-stats`                                                                 | Stats logging is on by default.                                                                                                                                              |
| `--chat-template PATH\|tool_use`, `--chat-template-content-format`                    | Custom Jinja template; examples ship in the repo `examples/tool_chat_template_*.jinja`.                                                                                      |
| `--default-chat-template-kwargs '{"enable_thinking": false}'`                         | Server default for `chat_template_kwargs`; request values win.                                                                                                               |
| `--enable-auto-tool-choice --tool-call-parser NAME`                                   | Both required; auto tool choice without a parser is an error. See `references/features.md`.                                                                                  |
| `--tool-strict-level`                                                                 | Server-side floor for strict tool calling (new in v0.31.0).                                                                                                                  |
| `--reasoning-parser NAME`                                                             | Splits thinking into the `reasoning` field.                                                                                                                                  |
| `--structured-outputs-config.backend auto\|xgrammar\|guidance\|...`                   | Default `auto`.                                                                                                                                                              |
| `--allowed-media-domains D ...`, `--allowed-local-media-path DIR`                     | Restrict multimodal URL/file access (SSRF protection).                                                                                                                       |
| `--trust-request-mm-kwargs`                                                           | Needed to accept per-request `mm_processor_kwargs`/`media_io_kwargs` (rejected otherwise since v0.31.0).                                                                     |
| `--ssl-keyfile`, `--ssl-certfile`, `--root-path`, `--allowed-origins`, `--middleware` | TLS, reverse-proxy path prefix, CORS, custom ASGI middleware (confirmed in source; check `--help`).                                                                          |

## Model and loading

| Flag                                                 | Notes                                                                                                                                                                                                                                                                                     |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--dtype auto\|bfloat16\|float16\|...`               | `auto` follows the checkpoint.                                                                                                                                                                                                                                                            |
| `--quantization NAME`                                | Usually auto-detected from the checkpoint config (FP8, AWQ, GPTQ, compressed-tensors, ModelOpt). Online shorthands: `fp8_per_tensor`, `fp8_per_block`, `mxfp8`, `mxfp4` (v0.31.0 replaced `quantization="fp8"` online with `fp8_per_tensor`). ModelOpt: `modelopt_fp4`, `modelopt_mxfp8`. |
| `--linear-backend NAME`, `--moe-backend NAME`        | Kernel selection for quantized linear and MoE layers (for example `cutlass`, `marlin`, `flashinfer_cutlass`, `b12x`). Replaces the deprecated `VLLM_NVFP4_GEMM_BACKEND` env var. An unsupported explicit choice errors instead of falling back. `--help=KernelConfig` lists values.       |
| `--load-format auto\|dummy\|fastsafetensors\|...`    | `dummy` skips weights (isolates download/load problems). `fastsafetensors` is used in NVIDIA's Spark recipes.                                                                                                                                                                             |
| `--download-dir DIR`, `HF_HOME`, `HF_HUB_OFFLINE=1`  | Cache location and offline mode.                                                                                                                                                                                                                                                          |
| `--trust-remote-code`                                | Only for repos you reviewed.                                                                                                                                                                                                                                                              |
| `--hf-overrides '{...}'`                             | Override `config.json` fields (for example `matryoshka_dimensions`).                                                                                                                                                                                                                      |
| `--runner generate\|pooling`, `--convert embed\|...` | Force a model role; see `references/features.md`.                                                                                                                                                                                                                                         |
| `--generation-config auto\|vllm\|PATH`               | Default `auto` reads the model's `generation_config.json` for default sampling parameters. `vllm` restores neutral defaults.                                                                                                                                                              |
| `--override-generation-config '{...}'`               | Force sampling defaults.                                                                                                                                                                                                                                                                  |
| `--tokenizer-mode`, `--config-format`                | `tokenizer_mode="slow"` was removed in v0.31.0. Mistral models may need `--tokenizer_mode hf --config_format hf --load_format hf`.                                                                                                                                                        |

## Memory, scheduling, performance

| Flag                                                                                             | Notes                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--max-model-len N`                                                                              | Caps context and KV reservation. Biggest fit lever. `VLLM_ALLOW_LONG_MAX_MODEL_LEN=1` overrides a model-config limit (risky).                                                                              |
| `--gpu-memory-utilization F`                                                                     | Fraction of device memory for weights + activations + KV. **Default 0.92 in v0.31.0** (`vllm/config/cache.py`). Applies per GPU.                                                                           |
| `--kv-cache-memory-bytes N`                                                                      | Fixed KV size; skips memory profiling for faster boots. vLLM logs the value that reproduces its allocation. Docs call it `--kv-cache-memory`; the flag in the v0.31.0 source is `--kv-cache-memory-bytes`. |
| `--kv-cache-dtype auto\|fp8\|fp8_e4m3\|fp8_e5m2\|nvfp4\|...`                                     | Numerics change; gate with an eval. The literal also lists `*_per_token_head`, `turboquant_*` and MLA-specific values; backend and GPU support vary.                                                       |
| `--enable-prefix-caching` / `--no-enable-prefix-caching`                                         | **On by default** in v0.31.0 (`enable_prefix_caching: bool = True`).                                                                                                                                       |
| `--max-num-seqs N`                                                                               | Concurrent sequences per DP rank; default depends on hardware/usage context (read the startup log).                                                                                                        |
| `--max-num-batched-tokens N`                                                                     | Per-step token budget; chunked prefill is on by default whenever possible in V1.                                                                                                                           |
| `--max-num-active-seqs N`                                                                        | New in v0.31.0: caps RUNNING admission independently of `max_num_seqs`.                                                                                                                                    |
| `--enable-chunked-prefill`                                                                       | Default behaviour in V1; flag is mostly explicit documentation.                                                                                                                                            |
| `--enforce-eager`                                                                                | No CUDA graphs and (v0.31.0) no JIT kernel warmup: fastest start, slower decode.                                                                                                                           |
| `-O0..-O3`                                                                                       | Optimization level; `-O2` default.                                                                                                                                                                         |
| `--performance-mode balanced\|interactivity\|throughput`                                         | Default `balanced`.                                                                                                                                                                                        |
| `--compilation-config '{...}'`, `--max-cudagraph-capture-size`, `--cudagraph-capture-sizes`      | Graph capture memory and time.                                                                                                                                                                             |
| `--attention-backend NAME`                                                                       | CUDA: `FLASH_ATTN`, `FLASHINFER`, `b12x`, ... ROCm: `TRITON_ATTN`, `ROCM_ATTN`, `ROCM_AITER_FA`, `ROCM_AITER_UNIFIED_ATTN`, MLA variants. Replaces the removed `VLLM_ATTENTION_BACKEND` env var.           |
| `--async-scheduling`                                                                             | Overlaps scheduling with execution (used in NVIDIA's Qwen3.6 recipe).                                                                                                                                      |
| `--speculative-config '{...}'`                                                                   | See `references/features.md` and `references/combos/eagle3.md`.                                                                                                                                            |
| `--kv-offloading-size`, `--kv-offloading-backend native\|lmcache`, `--kv-transfer-config`        | KV offload and disaggregated prefill connectors.                                                                                                                                                           |
| `--enable-sleep-mode`                                                                            | Allows sleep/wake of the engine; the HTTP endpoints (`/sleep`, `/is_sleeping`) are in the dev router (needs `VLLM_SERVER_DEV_MODE=1`).                                                                     |
| `--enable-mfu-metrics`, `--show-hidden-metrics-for-version X.Y`                                  | Extra/hidden Prometheus metrics.                                                                                                                                                                           |
| `--limit-mm-per-prompt.image N`, `--mm-processor-cache-gb N`                                     | Multimodal memory (cache default 4 GiB).                                                                                                                                                                   |
| `--enable-lora`, `--lora-modules name=path`, `--max-loras`, `--max-lora-rank`, `--max-cpu-loras` | LoRA serving.                                                                                                                                                                                              |

Removed or renamed (do not use from old recipes): `--swap-space` (no longer in the source),
`VLLM_ATTENTION_BACKEND` (use `--attention-backend`), `guided_*` request fields (use `structured_outputs`),
`--enable-mamba-fine-grained-prefix-cache` (now `--enable-mamba-shared-prefix-checkpoint`).

## Parallelism flags

`--tensor-parallel-size` (`-tp`), `--pipeline-parallel-size` (`-pp`), `--data-parallel-size` (`-dp`),
`--enable-expert-parallel`, `--distributed-executor-backend mp|ray`, `--nnodes`, `--node-rank`,
`--master-addr`, `--master-port` (default 29501), `--headless`, `--data-parallel-*`, `--all2all-backend`.
Details and recipes: `references/parallelism-multinode.md`.

## Environment variables (all confirmed in `vllm/envs.py` unless noted)

| Variable                                                 | Meaning                                                                                                                                  |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `HF_TOKEN`                                               | Hugging Face token; pass by name (`-e HF_TOKEN`) or from a `0600` env file.                                                              |
| `VLLM_CACHE_ROOT`                                        | Compile cache root (default `~/.cache/vllm`). Mount it in containers.                                                                    |
| `VLLM_FORCE_AOT_LOAD=1`                                  | Fail instead of silently recompiling on a cache miss (from the optimization docs).                                                       |
| `VLLM_LOGGING_LEVEL=DEBUG`, `VLLM_LOG_STATS_INTERVAL=1.` | More logs; faster stats lines.                                                                                                           |
| `VLLM_ENGINE_READY_TIMEOUT_S`                            | Engine startup timeout, default 600 s. Raise for huge models or slow disks.                                                              |
| `VLLM_HOST_IP`, `VLLM_PORT`                              | Internal addresses (not the API server). Set `VLLM_HOST_IP` per node for multi-node.                                                     |
| `VLLM_WORKER_MULTIPROC_METHOD=spawn`                     | Fix the multiprocessing `RuntimeError` described in troubleshooting.                                                                     |
| `VLLM_ENABLE_V1_MULTIPROCESSING=0`                       | Single-process engine so `pdb` works.                                                                                                    |
| `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True`                  | Enables `/v1/load_lora_adapter` and `/v1/unload_lora_adapter`.                                                                           |
| `VLLM_SERVER_DEV_MODE=1`                                 | Enables the development router, which includes `/sleep` and `/is_sleeping` (source: `entrypoints/serve/dev/sleep`). Never in production. |
| `VLLM_ENFORCE_STRICT_TOOL_CALLING`                       | Default true; structural-tag constraints for strict tools.                                                                               |
| `VLLM_USE_DEEP_GEMM=0`                                   | Try when FP8 inference hangs with no error.                                                                                              |
| `VLLM_ENABLE_CUDA_COMPATIBILITY=1`                       | Older host driver in the container.                                                                                                      |
| `VLLM_NO_USAGE_STATS=1`, `DO_NOT_TRACK=1`                | Opt out of usage stats.                                                                                                                  |
| `VLLM_CPU_KVCACHE_SPACE`, `VLLM_CPU_OMP_THREADS_BIND`    | CPU backend.                                                                                                                             |
| `VLLM_ROCM_USE_AITER=1`                                  | ROCm AITER kernels (default False; sub-switches default True once enabled).                                                              |
| `VLLM_TRACE_FUNCTION=1`                                  | Function tracing; slows generation by over 100x.                                                                                         |

Kubernetes: never name a Service `vllm`; Kubernetes injects `VLLM_*` variables from the service name and they
collide with vLLM's own.

## Useful starting commands

```bash
# Chat model with tools and reasoning
vllm serve Qwen/Qwen3-8B --reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser hermes

# Faster boots on the same machine: reuse the exact KV size from the first boot log
vllm serve <model> --kv-cache-memory-bytes <value-from-log>

# Isolate download/load problems from engine problems
vllm serve <model> --load-format dummy
```
