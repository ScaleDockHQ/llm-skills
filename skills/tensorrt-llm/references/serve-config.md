# trtllm-serve configuration

> Verified against TensorRT-LLM v1.2.1 (`tensorrt_llm/commands/serve.py`, `llm_args.py`, serve docs at that tag) and `main` (1.4.0rc0) docs and `serve.py`, 2026-10-11

`trtllm-serve <model>` starts an OpenAI-compatible server on the **PyTorch backend**. `<model>` is a Hugging Face id or a local checkpoint directory. Both `trtllm-serve <model>` and `trtllm-serve serve <model>` appear in upstream docs and playbooks.

Flags are tagged beta or prototype upstream and change between rc builds. Run `trtllm-serve serve --help` inside your image.

## Minimal commands

```bash
# Stable quick start (container or pip)
trtllm-serve "nvidia/Qwen3-8B-FP8" --host 127.0.0.1 --port 8000

# With a YAML for engine options
trtllm-serve openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max_batch_size 16 \
  --config /cfg/gpt-oss.yml
```

Inside a container bind `0.0.0.0` and publish the port on loopback with `-p 127.0.0.1:8000:8000`. There is no authentication.

## Flags (v1.2.1 unless marked)

| Flag                                                                     | Default         | Meaning                                                                                                                                                    |
| ------------------------------------------------------------------------ | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--host`, `--port`                                                       | localhost, 8000 | Bind address and port.                                                                                                                                     |
| `--backend`                                                              | `pytorch`       | v1.2.1 accepts `pytorch`, `tensorrt` (alias `trt`, legacy engines) and `_autodeploy`. On `main` only `pytorch`, deprecated; do not pass it in new recipes. |
| `--tokenizer`, `--custom_tokenizer`                                      | model           | Tokenizer path or name; custom tokenizer alias or import path (prototype).                                                                                 |
| `--max_batch_size`, `--max_num_tokens`, `--max_seq_len`                  | from config     | Scheduler limits: requests per iteration, batched input tokens, total length per request (deduced from model).                                             |
| `--max_beam_width`                                                       | build default   | Beam search width (default not read; check `--help`).                                                                                                      |
| `--tp_size` / `--tensor_parallel_size`                                   | 1               | Tensor parallel size.                                                                                                                                      |
| `--pp_size` / `--pipeline_parallel_size`                                 | 1               | Pipeline parallel size.                                                                                                                                    |
| `--cp_size` / `--context_parallel_size`                                  | 1               | Context parallel size.                                                                                                                                     |
| `--ep_size` / `--moe_expert_parallel_size`                               | none            | Expert parallel size (MoE).                                                                                                                                |
| `--cluster_size` / `--moe_cluster_parallel_size`                         | none            | Expert cluster parallel size.                                                                                                                              |
| `--gpus_per_node`                                                        | autodetect      | GPUs per node.                                                                                                                                             |
| `--free_gpu_memory_fraction` / `--kv_cache_free_gpu_memory_fraction`     | 0.9             | Share of free memory (after weights and buffers) given to the KV cache.                                                                                    |
| `--trust_remote_code`                                                    | off             | Needed for models with custom code.                                                                                                                        |
| `--revision`                                                             | none            | HF branch, tag or commit (`--hf_revision` is the main-branch name).                                                                                        |
| `--config` / `--extra_llm_api_options`                                   | none            | YAML overriding LLM API args. Same file, either name; `--config` is the preferred spelling.                                                                |
| `--reasoning_parser`, `--tool_parser`                                    | none            | See `features.md`.                                                                                                                                         |
| `--enable_chunked_prefill`                                               | off             | Chunked prefill (prototype).                                                                                                                               |
| `--chat_template`                                                        | model           | Custom chat template: file path or one-liner (prototype).                                                                                                  |
| `--num_postprocess_workers`                                              | 0               | Workers that postprocess raw responses into OpenAI format (prototype).                                                                                     |
| `--otlp_traces_endpoint`                                                 | none            | OpenTelemetry traces target URL (prototype).                                                                                                               |
| `--log_level`                                                            | `info`          | Logging level.                                                                                                                                             |
| `--fail_fast_on_attention_window_too_large`                              | off             | Exit if one sequence cannot fit the KV cache.                                                                                                              |
| `--server_role`, `--disagg_cluster_uri`, `--metadata_server_config_file` | none            | Disaggregated mode plumbing (see `combos/dynamo.md`, `parallelism-multinode.md`).                                                                          |
| `--media_io_kwargs`                                                      | none            | Media I/O keyword arguments for multimodal.                                                                                                                |

Only on `main` (1.4.0rc0 docs and source, not in the v1.2.1 `serve` command): `--set PATH=YAML` (repeatable field overrides), `--served_model_name`, `--kv_cache_dtype`, `--enable_attention_dp`, `--generation-config {auto,trtllm}`, `--grpc`, `--middleware`, `--allow_request_chat_template`, `--num_serve_frontends`, `--video_pruning_rate`, `--telemetry/--no-telemetry`, `--post_processor_hook`.

Subcommands: `trtllm-serve embeddings` (encoder-only models, `/v1/embeddings`), `trtllm-serve disaggregated -c <yaml>` (orchestrator), `disaggregated_mpi_worker`, `mm_embedding_serve` (main), and diffusion models (FLUX, Wan; beta) via `--visual_gen_args` on main.

Model naming: in v1.2.1 the served model name is the path or id you passed; clients must send exactly that as `model`. Stacks that need a stable name use llama-swap `useModelName`. On `main`, `--served_model_name` exists.

## Precedence

Upstream (main docs): `LlmArgs defaults < --config YAML < dedicated CLI flags < --set`. Explicit CLI flags override conflicting YAML values. `--set` is not available in v1.2.1.

## The YAML (LLM API args)

The file sets fields of `TorchLlmArgs` (the same names as the Python `LLM(...)` kwargs). Nested objects are mappings. Common keys (names and defaults from `llm_args.py` at v1.2.1):

```yaml
# /cfg/config.yml
kv_cache_config:
  dtype: auto # or fp8 / nvfp4 (NVFP4 KV needs a ModelOpt checkpoint)
  free_gpu_memory_fraction: 0.85 # default 0.9
  enable_block_reuse: true # prefix reuse across requests; default on
  # host_cache_size: 0            # bytes of host memory for KV offload, default 0
cuda_graph_config: # enabled by default (a default CudaGraphConfig); each graph can use up to ~200 MB
  enable_padding: true
  max_batch_size: 64 # or batch_sizes: [1, 2, 4, 8]
disable_overlap_scheduler: false # set true with two-model speculative decoding
enable_chunked_prefill: false
moe_config:
  backend: CUTLASS # CUTLASS, CUTEDSL, WIDEEP, TRTLLM, DEEPGEMM, VANILLA, TRITON; default CUTLASS
attn_backend: TRTLLM # default
guided_decoding_backend: xgrammar # or llguidance; unset = no guided decoding
enable_attention_dp: false
print_iter_log: false # per-iteration log lines; default false
enable_iter_perf_stats: false # feeds /metrics (prototype)
stream_interval: 1 # raise when batch is large to cut streaming overhead
speculative_config: {} # see features.md
cache_transceiver_config: {} # disaggregated serving only
```

The gpt-oss deployment guide (main) notes that on Blackwell the default MoE backend is `TRTLLM` and on Hopper `TRITON`, so `moe_config.backend` usually needs no override there; this differs from the `CUTLASS` default shown in `llm_args.py` at v1.2.1, which means newer builds choose per architecture. Check your image.

Curated, per-model recommended YAMLs ship in newer images at `/app/tensorrt_llm/examples/configs/curated/` (for example `gpt-oss-120b-latency.yaml` and `-throughput.yaml`) and in the repo's `examples/configs`. They are not confirmed for v1.2.1 images. Upstream also publishes deployment guides per model (DeepSeek-R1, gpt-oss, Qwen3, Llama 3.3 70B, Llama 4 Scout, Kimi K2, Nemotron 3 and others) under `docs/source/deployment-guide/`.

## Environment variables seen in upstream docs and playbooks

| Variable                                                            | Where                      | Effect                                                                                      |
| ------------------------------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------- |
| `HF_TOKEN`                                                          | all                        | Hugging Face download token for gated models. Never echo it.                                |
| `TIKTOKEN_ENCODINGS_BASE`                                           | gpt-oss                    | Directory with `o200k_base.tiktoken` and `cl100k_base.tiktoken`.                            |
| `TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1`                        | DGX Spark playbook         | Avoid memory spikes while loading weights.                                                  |
| `TRITON_PTXAS_PATH`, `CPATH`                                        | DGX Spark playbook         | Triton compile on GB10; `/usr/local/cuda/bin/ptxas`, `/usr/local/cuda/include`.             |
| `PYTORCH_ALLOC_CONF=expandable_segments:True`                       | DGX Spark playbook         | Allocator setting used for Nemotron Omni.                                                   |
| `TRTLLM_SERVER_DISABLE_GC=1`                                        | `serve.py`                 | Disable Python cyclic GC in the server for benchmarks (stabilizes tail latency).            |
| `PMIX_HOSTNAME`                                                     | Open MPI 5, long hostnames | Short value avoids `MPI_ERR_UNKNOWN` at start.                                              |
| `PROMETHEUS_MULTIPROC_DIR`                                          | `/prometheus/metrics`      | Required by prometheus multiprocess mode when perf metrics are on (see `observability.md`). |
| `TRTLLM_NIXL_KVCACHE_BACKEND` and other `TRTLLM_*` KV transfer vars | disaggregated              | See `parallelism-multinode.md`.                                                             |

## Container wrapper pattern

```bash
docker run -d --name trtllm-gpt-oss --gpus all --ipc=host \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_HUB_OFFLINE=1 \
  -v /opt/trtllm:/cfg:ro -v /srv/tiktoken:/tiktoken:ro -e TIKTOKEN_ENCODINGS_BASE=/tiktoken \
  nvcr.io/nvidia/tensorrt-llm/release:1.2.1 \
  trtllm-serve openai/gpt-oss-120b --host 0.0.0.0 --port 8000 \
    --max_batch_size 16 --config /cfg/gpt-oss.yml
```

Pre-fetch weights (`hf download openai/gpt-oss-120b`) and tiktoken files before starting. `HF_HUB_OFFLINE=1` makes a missing file fail fast instead of turning a cold start into a download. `templates/` has compose, systemd and Kubernetes versions.

## Dual DGX Spark serve command

From NVIDIA's two-node playbook (run inside the primary's container after the hostfile and containers are up):

```bash
mpirun -x HF_TOKEN trtllm-llmapi-launch trtllm-serve nvidia/Qwen3-235B-A22B-FP4 \
  --tp_size 2 --max_num_tokens 32768 --max_batch_size 4 \
  --extra_llm_api_options /tmp/extra-llm-api-config.yml --port 8355
```

The playbook still passes `--backend pytorch`; it is harmless on 1.3 rc images and unnecessary. `-x TRITON_PTXAS_PATH` may be needed on `mpirun` if `ptxas fatal` appears.

## Official links

- trtllm-serve docs: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/trtllm-serve.html
- LLM API reference (all YAML fields): https://nvidia.github.io/TensorRT-LLM/llm-api/reference.html
- Deployment guides: https://nvidia.github.io/TensorRT-LLM/deployment-guide/index.html
- Source of the flags: https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/tensorrt_llm/commands/serve.py
