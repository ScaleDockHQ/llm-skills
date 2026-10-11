# Aphrodite Engine performance tuning

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

Benchmark first with `aphrodite bench` (`latency`, `throughput`, `serve`, `startup`, `perf`, `mm-processor`,
`sweep`). Record the command, model revision, commit, hardware and config. Warm up; compare percentiles of
TTFT, inter-token latency, end-to-end latency and completed throughput; discard runs with failures.

```bash
aphrodite bench serve --backend openai --base-url http://127.0.0.1:2242 --model qwen3 \
  --dataset-name random --input-len 512 --output-len 128 --request-rate 8 --num-prompts 1000 --save-result
```

Set `--api-key` consistently when benchmarking an authenticated or proxied path; test the real path.

## Tuning order

1. Fix the context: `--max-model-len N` (or `auto`, which shrinks to fit the KV cache; check the final value in the log).
2. Memory budget: `--gpu-memory-utilization` (default 0.92) is a fraction of **total** GPU memory, not free memory.
   Another process using 20 GiB on an 80 GiB card makes 0.92 fail instead of rescaling. Lower it on shared GPUs.
   `--kv-cache-memory-bytes` overrides it for KV sizing.
3. Scheduler: `--max-num-seqs` to expected peak concurrency (also drives activation and CUDA graph memory);
   `--max-num-batched-tokens` bigger for long-prompt throughput, smaller for decode latency; test short-prompt,
   long-prompt and mixed workloads one change at a time. Chunked prefill splits long prompts across steps.
4. KV pressure and preemptions: lower `--max-num-seqs`, then `--max-model-len`, raise utilization if safe,
   `--kv-cache-dtype fp8`, then add parallelism or CPU offload.
5. Prefix caching stays on; disable only for a clean baseline.
6. Quantization to free memory (speed varies by format and GPU), then parallelism, then speculative decoding.
7. Compilation: persist `APHRODITE_CACHE_ROOT`; same commit, config, PyTorch and GPU type keep cache hits.
   `--enforce-eager` only for short development runs; lower `--max-num-seqs` if graph capture runs out of memory.

## Startup time

Separate download, weight load, quantization setup, compile and graph capture. Persistent HF and compile
caches; local fast storage; warm a replacement replica before stopping the old one. Use separate cache keys per
PyTorch or CUDA stack.

## Rust frontend (experimental)

`APHRODITE_USE_RUST_FRONTEND=1` runs an `aphrodite-rs` HTTP process (ZMQ and MessagePack to the Python engine).
Routes: `/health`, `/metrics`, `/load`, `/version`, `/v1/models`, `/v1/completions`,
`/v1/chat/completions`, `/tokenize`, `/detokenize`, `/inference/v1/generate`. Not every option exists: unsupported
ones fail at startup. One Rust API process only (`--api-server-count>1` is rejected). Binary from the same commit
(`APHRODITE_RUST_FRONTEND_PATH`). Benchmark it with your parsers and auth before use.

## Recipes (upstream baselines)

- 1 consumer GPU: quantized checkpoint, `--max-model-len auto --gpu-memory-utilization 0.90 --max-num-seqs 16`.
- 1 datacenter GPU: `--max-num-seqs 64`. 8-GPU NVLink: `--tensor-parallel-size 8`.
- MoE: TP plus `--enable-expert-parallel --enable-eplb`, compare to EPLB off.
- Jetson Thor: unified memory, `--gpu-memory-utilization 0.80 --max-num-seqs 8`. CPU: `APHRODITE_TARGET_DEVICE=cpu`,
  `APHRODITE_CPU_KVCACHE_SPACE`, small context; for functional tests.
  For sizing math use the `choosing-hardware` skill.
