# Serve configuration

> Verified against LMDeploy v0.18.0 (source `lmdeploy/cli/serve.py` and `lmdeploy/cli/utils.py`), 2026-10-11

LMDeploy has no serve config file: everything is CLI flags and a few environment variables. Run
`lmdeploy serve api_server -h` for the installed version; flag names use hyphens (`--session-len`).

## Command shape

```bash
lmdeploy serve api_server <model_path_or_hf_id> [flags]
lmdeploy serve proxy [flags]          # request distributor, see parallelism-multinode.md
lmdeploy chat <model>                 # interactive CLI chat
lmdeploy lite auto_awq | smooth_quant ...   # quantization, see models-and-formats.md
lmdeploy check_env
```

`model_path` may be a local directory, a Hugging Face ID, or an LMDeploy-quantized repo ID.

## api_server flags by group (defaults from source)

| Group     | Flag                                                                                                                        | Default / note                                                                                   |
| --------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Network   | `--server-name`                                                                                                             | `0.0.0.0` (all interfaces). Set `127.0.0.1` unless behind a gateway                              |
| Network   | `--server-port`                                                                                                             | unset, effective 23333                                                                           |
| Network   | `--allow-origins/-methods/-headers`                                                                                         | `*` (CORS wide open); `--allow-credentials` off                                                  |
| Network   | `--ssl`                                                                                                                     | off; needs env `SSL_KEYFILE` and `SSL_CERTFILE`                                                  |
| Network   | `--max-concurrent-requests`                                                                                                 | None                                                                                             |
| Network   | `--allowed-media-domains`                                                                                                   | None; exact hostnames allowed for HTTP(S) image/video URLs                                       |
| Auth      | `--api-keys k1 k2`                                                                                                          | None; `/v1` only (see api.md)                                                                    |
| Identity  | `--model-name`                                                                                                              | None, falls back to `model_path`                                                                 |
| Engine    | `--backend {turbomind,pytorch}`                                                                                             | `turbomind`                                                                                      |
| Engine    | `--dtype {auto,float16,bfloat16}`                                                                                           | `auto`; ignored for quantized models                                                             |
| Engine    | `--tp`                                                                                                                      | 1 (power of two)                                                                                 |
| Engine    | `--session-len`                                                                                                             | None (from model config)                                                                         |
| Engine    | `--max-batch-size`                                                                                                          | None, engine picks per device                                                                    |
| KV cache  | `--cache-max-entry-count`                                                                                                   | 0.8 (share of free memory after weights; an integer > 0 means a block count in TurboMind config) |
| KV cache  | `--cache-block-seq-len`                                                                                                     | engine default (TurboMind config doc: 128)                                                       |
| KV cache  | `--num-gpu-blocks`                                                                                                          | PyTorch engine, explicit block count                                                             |
| KV cache  | `--quant-policy`                                                                                                            | 0; `none/int4/int8/fp8/fp8_e5m2/turbo_quant` or `0/4/8/16/17/42`                                 |
| Caching   | `--enable-prefix-caching`                                                                                                   | off                                                                                              |
| Prefill   | `--max-prefill-token-num`                                                                                                   | engine default                                                                                   |
| Format    | `--model-format`                                                                                                            | None (auto); `hf`, `awq`, `gptq`, `compressed-tensors`, `fp8`, `mxfp4`                           |
| Format    | `--hf-overrides`, `--revision`, `--download-dir`, `--trust-remote-code`                                                     | trust-remote-code off                                                                            |
| Format    | `--generation-config`                                                                                                       | `auto`: load the model's generation config; `lmdeploy` uses LMDeploy defaults; or a folder path  |
| Parsers   | `--tool-call-parser`, `--reasoning-parser`                                                                                  | None                                                                                             |
| Template  | `--chat-template`                                                                                                           | JSON file or string                                                                              |
| PyTorch   | `--adapters name=path`                                                                                                      | LoRA                                                                                             |
| PyTorch   | `--eager-mode`                                                                                                              | disable CUDA graphs when debugging                                                               |
| PyTorch   | `--device {cuda,ascend,maca,camb}`                                                                                          | `cuda`                                                                                           |
| PyTorch   | `--distributed-executor-backend {uni,mp,ray}`                                                                               | None (auto)                                                                                      |
| PyTorch   | `--logprobs-mode`                                                                                                           | needed for `/generate` input scoring (`raw_logprobs`)                                            |
| TurboMind | `--cp`, `--rope-scaling-factor`, `--communicator`, `--async`                                                                | cp 1; see parallelism-multinode.md and `-h`                                                      |
| Parallel  | `--dp`, `--ep`, `--nnodes`, `--node-rank`, `--dist-init-addr`                                                               | 1, 1, 1, 0, None                                                                                 |
| Spec      | `--speculative-algorithm`, `--speculative-draft-model`, `--speculative-num-draft-tokens`, `--speculative-dflash-block-size` | off; default draft tokens 1                                                                      |
| Ops       | `--log-level`                                                                                                               | `WARNING`                                                                                        |
| Ops       | `--disable-metrics`                                                                                                         | metrics on                                                                                       |
| Ops       | `--disable-fastapi-docs`                                                                                                    | docs on; set it on exposed servers                                                               |
| Ops       | `--max-log-len`                                                                                                             | unlimited prompt logging; set it to avoid logging full prompts                                   |
| Ops       | `--allow-terminate-by-client`, `--enable-abort-handling`                                                                    | off                                                                                              |
| Vision    | `--vision-max-batch-size`                                                                                                   | see `-h`                                                                                         |

## Environment variables

Seen in the v0.18.0 source (names verified, effects as stated in the files read):

| Variable                                                                                 | Meaning                                                         |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `LMDEPLOY_EXECUTOR_BACKEND`                                                              | `ray` forces the Ray executor for the PyTorch engine            |
| `LMDEPLOY_DP_MASTER_ADDR`, `LMDEPLOY_DP_MASTER_PORT`                                     | rendezvous for `--dp` > 1 (metrics doc)                         |
| `LMDEPLOY_ENABLE_REQUEST_CACHE_USAGE_METRIC`                                             | `0` reports total block occupancy in `gpu_cache_usage_perc`     |
| `LMDEPLOY_FP32_MAMBA_SSM_DTYPE`                                                          | `1` stores GatedDeltaNet recurrent state in FP32 (TurboMind)    |
| `LMDEPLOY_HEALTH_POLL_INTERVAL`, `_PROBE_TIMEOUT`, `_UNHEALTHY_AFTER`                    | health monitor timing (defaults 12 s, 10 s, 90 s)               |
| `LMDEPLOY_SKIP_WARMUP`                                                                   | PyTorch engine; boolean, default false; `1` skips engine warmup |
| `LMDEPLOY_IMAGE_FETCH_TIMEOUT`, `LMDEPLOY_VIDEO_FETCH_TIMEOUT`, `LMDEPLOY_VIDEO_BACKEND` | multimodal fetch behaviour                                      |
| `LMDEPLOY_USE_MODELSCOPE`, `LMDEPLOY_USE_OPENMIND_HUB`                                   | model hub selection (README)                                    |
| `UVICORN_LOG_LEVEL`                                                                      | uvicorn log level (default `info`)                              |
| `SSL_KEYFILE`, `SSL_CERTFILE`                                                            | files for `--ssl`                                               |
| `HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN`                                                    | Hugging Face auth via huggingface_hub; never print              |

## A good first command

```bash
lmdeploy serve api_server Qwen/Qwen3-8B \
  --server-name 127.0.0.1 --server-port 23333 --model-name qwen \
  --session-len 32768 --cache-max-entry-count 0.8 --enable-prefix-caching \
  --max-log-len 200
```

Add `--tool-call-parser qwen` (Qwen2.5/Qwen3 family) or the parser matching your model for agents, and
`--reasoning-parser default` for `<think>` models (`features.md`).
