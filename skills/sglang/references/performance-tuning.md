# SGLang: performance tuning

> Verified against SGLang v0.5.21 (docs: advanced_features/hyperparameter_tuning, server_arguments, developer_guide/bench_serving, references/faq), 2026-10-11

Method: measure, change one thing, measure again with the same dataset, concurrency and server state. Record before/after numbers.

## Read the server first

Startup log line (check `available_gpu_mem`):

```text
max_total_num_tokens=665690, chunked_prefill_size=8192, max_prefill_tokens=16384, max_running_requests=4096, context_len=65536, available_gpu_mem=13.50 GB
```

Steady-state decode log (every `--decode-log-interval`, default 40 batches):

```text
Decode batch. #running-req: 233, #token: 370959, token usage: 0.82, cuda graph: True, gen throughput (token/s): 4594.01, #queue-req: 317
```

```bash
docker logs --tail 200 sglang | grep -E 'Decode batch|max_total_num_tokens|KV cache pool is full'
```

## Throughput (offline batch, many requests)

- Batch size is everything. Keep `#queue-req` roughly 100 to 2000: a constant 0 means the client is too slow; huge queues add scheduling overhead.
- Aim for `token usage > 0.9`. If `token usage < 0.9` and `#queue-req > 0`, lower `--schedule-conservativeness` (to about 0.3). If you often see `KV cache pool is full. Retract requests.` (more than about once a minute), raise it (about 1.3).
- Raise `--mem-fraction-static` until `available_gpu_mem` after startup is about 5 to 8 GB (activations and CUDA graph buffers need it). If it is 10 to 20 GB, raise it; if low, lower it. Alternatively step by 0.01 until OOM and back off.
- Raise `--cuda-graph-max-bs-decode` (to 512/768 for high concurrency and large TP); lower `--mem-fraction-static` to pay for the graph memory.
- Shared prefixes: `--schedule-policy lpm`.
- Replicas beat bigger TP when memory allows: DP via the model gateway (`parallelism-multinode.md`).
- Try FP8 (`--quantization fp8` or a pre-quantized FP8 checkpoint) and `--kv-cache-dtype fp8_e4m3` (check accuracy).
- MoE: `--ep`, DP attention, `--enable-two-batch-overlap`, `--enable-eplb`.

## Latency (interactive, low concurrency)

- Speculative decoding (EAGLE-3 first): `features.md`.
- Keep CUDA graphs on (the default); `--disable-cuda-graph` hurts decode latency a lot.
- Reduce `--chunked-prefill-size` to protect inter-token latency during long prefills; raise it for TTFT on long prompts when memory allows.
- Keep prefix caching on and prompts prefix-stable (system prompt and tools first, variable text last).
- `--enable-torch-compile` is experimental and listed as out of maintenance: benchmark before trusting it.
- `--num-continuous-decode-steps N` and `--stream-interval N` trade smoothness for scheduling overhead.
- Pin the attention backend only with evidence: `--attention-backend flashinfer|fa3|triton|trtllm_mha|...`. Blackwell and Hopper defaults differ.

## OOM and stability knobs

| Symptom                              | First changes                                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| OOM during prefill (long prompts)    | `--chunked-prefill-size 4096` or `2048`; lower `--mem-fraction-static`                                        |
| OOM during decode                    | `--max-running-requests` down; `--mem-fraction-static` 0.8 or 0.7                                             |
| OOM on huge `logprobs` requests      | set `logprob_start_len` to only what you need                                                                 |
| OOM with speculative decoding        | lower `--mem-fraction-static`, smaller `--speculative-num-draft-tokens`, smaller `--cuda-graph-max-bs-decode` |
| Hang or "avail mem" very low at init | lower `--mem-fraction-static`, `--cuda-graph-max-bs-decode`, `--chunked-prefill-size`                         |

Unified-memory machines (GB10, Apple): the GPU shares RAM with the OS and page cache, so leave generous headroom (start around 0.7 to 0.8 and go down). See `combos/dgx-spark.md`.

## bench_serving

`python3 -m sglang.bench_serving` (the module name is stable across upstream docs). Needs `aiohttp numpy requests tqdm transformers`, plus `datasets pillow pybase64` for some datasets. Backends: `sglang` (native `/generate`), `sglang-oai` (`/v1/completions`), `sglang-oai-chat` (`/v1/chat/completions`), `sglang-embedding`, `vllm`, `vllm-chat`, `lmdeploy`, `trt`, `truss`. `OPENAI_API_KEY` supplies the bearer token if the server needs one.

```bash
# Random lengths, throughput and latency
python3 -m sglang.bench_serving --backend sglang-oai-chat --host 127.0.0.1 --port 30000 \
  --model MODEL --dataset-name random --num-prompts 500 --random-input-len 1024 --random-output-len 512 \
  --random-range-ratio 0.5 --max-concurrency 64 --warmup-requests 3 --flush-cache --output-file /tmp/bench.jsonl

# Prefix-heavy agent workload (shows RadixAttention hits)
python3 -m sglang.bench_serving --backend sglang --dataset-name generated-shared-prefix \
  --gsp-num-groups 16 --gsp-prompts-per-group 32 --gsp-system-prompt-len 2048 --gsp-question-len 128 --gsp-output-len 256

# Vision
python3 -m sglang.bench_serving --backend sglang-oai-chat --dataset-name image --image-count 3 --image-resolution 720p \
  --random-input-len 512 --random-output-len 512 --num-prompts 500
```

Datasets: `sharegpt` (default), `random`, `random-ids`, `image`, `generated-shared-prefix`, `mmmu`, `speed-bench`, `agentic-trace`. The shared repo script (`bench.sh` in the `self-hosted-llms` skill) gives an engine-neutral curl-based comparison. Report: output tokens/s, TTFT p50/p99, inter-token latency, request success rate, concurrency, dataset and flags. Compare servers with the same tokenizer and the same cache state (`--flush-cache`).

Profiling: set `SGLANG_TORCH_PROFILER_DIR`, then call `/start_profile` and `/stop_profile`; prefill and decode workers must be profiled separately in PD mode.
