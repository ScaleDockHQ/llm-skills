# Choosing Hardware

Helps an agent choose and size hardware for running an LLM. It turns a model, a quantization, a context length and a number of concurrent users into a memory budget and a memory-bandwidth ceiling, then maps that to NVIDIA RTX, datacenter, Blackwell and DGX Spark, AMD Instinct, Radeon and Strix Halo, Apple Silicon, Intel and CPU-only options.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware
```

## Rules

- **Size before you buy.** Weights, KV cache and headroom first, then the bandwidth ceiling.
- **Verify upstream.** Specs come from vendor pages read on the writing date. Re-check the exact SKU.
- **Estimates are ceilings.** Benchmark the real model, quant and engine.
- **Gate numerics changes.** Lower weight quants, KV-cache quantization and speculative decoding go through the `llm-evals` skill.
- **Never print secrets.** Keys live in `0600` files or environment variables.

## References

- [`references/hardware-matrix.md`](references/hardware-matrix.md): verified specs and engine support by vendor, with sources and gaps marked.
- [`references/sizing-math.md`](references/sizing-math.md): weight and KV-cache formulas, worked bandwidth ceilings and a sizing checklist.

## Companion skills

- `choosing-inference-engine`: pick the engine for the hardware.
- `choosing-llm-hosting`: decide local, owned server, cloud or hybrid.
- `local-llms`: run models on a laptop or desktop.
- `self-hosted-llms`: serve on your own NVIDIA servers and DGX Spark.
- `cloud-llms`: rent GPUs, serverless or managed endpoints.
- `model-quantization`: produce the smaller quant that makes a model fit.
- `llm-evals`: quality gate for numerics changes.

## License

MIT
