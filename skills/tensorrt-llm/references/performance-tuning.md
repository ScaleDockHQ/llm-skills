# Performance tuning and benchmarking

> Verified against TensorRT-LLM v1.2.1 (`trtllm-bench` source and docs, `llm_args.py`), `main` run-benchmark-with-trtllm-serve doc, gpt-oss deployment guide, DGX Spark playbook, 2026-10-11

## Measure first

Two upstream tools:

1. **`trtllm-bench`**: offline, in-process, the quickest apples-to-apples numbers. Subcommands at v1.2.1: `throughput`, `latency`, `build` (legacy engines).
2. **`benchmark_serving`** against a running `trtllm-serve`: closer to what clients see.

### trtllm-bench

Dataset: `benchmarks/cpp/prepare_dataset.py` from the repo (needs `--stdout`):

```bash
python benchmarks/cpp/prepare_dataset.py --tokenizer meta-llama/Llama-3.1-8B-Instruct --stdout \
  token_norm_dist --num-requests 512 --input-mean 1024 --input-stdev 0 --output-mean 1024 --output-stdev 0 > /tmp/ds.jsonl

trtllm-bench --model meta-llama/Llama-3.1-8B-Instruct throughput --dataset /tmp/ds.jsonl \
  --tp 1 --concurrency 64 --kv_cache_free_gpu_mem_fraction 0.85 --config /cfg/config.yml \
  --report_json /tmp/report.json
```

Options seen in `throughput` (v1.2.1): `--backend`, `--engine_dir`, `--config` / `--extra_llm_api_options`, `--max_batch_size`, `--max_num_tokens`, `--max_seq_len`, `--beam_width`, `--kv_cache_free_gpu_mem_fraction`, `--dataset`, `--num_requests`, `--warmup`, `--concurrency`, `--streaming`, `--tp`, `--pp`, `--ep`, `--cluster_size`, `--target_input_len`, `--target_output_len`, `--report_json`, `--iteration_log`, `--output_json`, `--request_json`, `--scheduler_policy`. Top-level: `--model`, `--model_path`, `--workspace`. Check `trtllm-bench throughput --help` in your image; names differ slightly from `trtllm-serve` (`--tp` vs `--tp_size`).

### Against a server

```bash
python -m tensorrt_llm.serve.scripts.benchmark_serving --model "$MODEL" --backend openai \
  --dataset-name random --random-input-len 1024 --random-output-len 1024 --random-prefix-len 0 \
  --num-prompts 320 --max-concurrency 64 --ignore-eos --save-result --result-dir /tmp/out \
  --percentile-metrics ttft,tpot,itl,e2el
```

Sweep concurrency 1, 2, 4 ... 256 with `num_prompts = concurrency * 5`. Report TTFT, TPOT, ITL, E2EL and output tokens per second. Warm up first (CUDA graph capture, lazy connection setup). Upstream warns example configs are illustrative.

For a stack-level benchmark script that works against any OpenAI-compatible endpoint, see `self-hosted-llms` (`npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`).

## Knobs, in the order to try them

| Goal                          | Knob                                                                                                                                                                                  |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Use the right weights         | NVFP4 on Blackwell, FP8 on Hopper/Ada (`models-and-formats.md`).                                                                                                                      |
| KV memory                     | `kv_cache_config.free_gpu_memory_fraction` (default 0.9; upstream suggests 0.7 or lower after OOM; Spark playbook 0.8 to 0.9). `kv_cache_config.dtype: fp8` halves KV size vs 16-bit. |
| Concurrency                   | `--max_batch_size`; keep `cuda_graph_config.max_batch_size` aligned (`enable_padding: true` avoids missing graph sizes).                                                              |
| Prefill throughput            | `--max_num_tokens` (batched tokens per step), `enable_chunked_prefill`.                                                                                                               |
| Context length                | `--max_seq_len`; smaller values save KV memory and warm-up time.                                                                                                                      |
| Low latency, small batch      | TP across GPUs; speculative decoding (`features.md`); keep overlap scheduler on unless required otherwise.                                                                            |
| Throughput, large batch / MoE | `enable_attention_dp: true`, `moe_expert_parallel_size`; Wide-EP for DeepSeek-class models.                                                                                           |
| MoE kernels                   | `moe_config.backend` (`CUTLASS` default at v1.2.1; Blackwell newer builds default `TRTLLM`, Hopper `TRITON`). Try `TRTLLM` on Blackwell, as upstream's deployment guides do.          |
| Prefix-heavy traffic          | Keep `enable_block_reuse: true`; consider `host_cache_size` for offload.                                                                                                              |
| Streaming overhead            | `stream_interval` > 1 at high batch sizes; `--num_postprocess_workers` (prototype).                                                                                                   |
| GC jitter in benchmarks       | `TRTLLM_SERVER_DISABLE_GC=1`.                                                                                                                                                         |
| Allreduce                     | `allreduce_strategy` (default `AUTO`).                                                                                                                                                |

Spark-specific: single Spark decode speed is memory-bandwidth bound; NVFP4 or FP8 weights and a smaller KV fraction usually matter more than batch tricks. Keep other engines stopped while measuring (shared memory). Playbook configs disable the overlap scheduler for Llama 3.1 8B and gpt-oss-20b (`disable_overlap_scheduler: true`) with `--max_batch_size 64`.

## Profiling

- `POST /start_profile` with `{"output_dir": "/tmp/traces", "num_steps": 30}` then drive load; chrome traces per rank (`trtllm-trace-<id>-rank-<N>.json`), open in ui.perfetto.dev. Prototype, PyTorch backend only, documented on `main`.
- `activities: ["CUDA_PROFILER"]` composes with `nsys profile -c cudaProfilerApi`.
- Env alternatives named in the docs: `TLLM_PROFILE_START_STOP`, `TLLM_TORCH_PROFILE_TRACE`, `TLLM_TORCH_PROFILER_DIR`.
- `print_iter_log: true` prints per-iteration batch and KV stats to the log.

## Official links

- trtllm-bench: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-bench.html
- Benchmark with trtllm-serve: https://nvidia.github.io/TensorRT-LLM/commands/trtllm-serve/run-benchmark-with-trtllm-serve.html
- Deployment guides (recommended YAMLs): https://nvidia.github.io/TensorRT-LLM/deployment-guide/index.html
