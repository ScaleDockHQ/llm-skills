# exo: performance

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README "Benchmarking" and Environment Variables, `src/exo/main.py`.

## Benchmark

`bench/exo_bench.py` (run from a checkout, nodes already running) posts to `/bench/chat/completions` and reports prompt tokens per second, generation tokens per second and peak memory.

```bash
uv run bench/exo_bench.py --model Llama-3.2-1B-Instruct-4bit --pp 128,512 --tg 128 \
  --max-nodes 2 --sharding tensor --instance-meta both --repeat 3 --json-out results.json
```

Flags: `--pp`, `--tg`, `--max-nodes` (default 4), `--instance-meta ring|jaccl|both`, `--sharding pipeline|tensor|both`, `--repeat`, `--warmup`, `--json-out` (default `bench/results.json`).

## Levers

- Compare Ring and JACCL, pipeline and tensor, on your hardware before choosing; more nodes only help if links are fast (Thunderbolt 5 RDMA, not Wi-Fi).
- `--no-batch` disables continuous batching; leave batching on for several clients.
- `--fast-synch` / `EXO_FAST_SYNCH` control MLX_METAL_FAST_SYNCH for JACCL; the default is auto.
- `EXO_TRACING_ENABLED=true` for distributed traces while diagnosing.
- Quantize to fit in fewer nodes: fewer hops often beat more devices.
