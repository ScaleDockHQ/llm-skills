# Nemotron

Helps an agent serve NVIDIA Nemotron open models (Nemotron 3.5 Lightning, 3 Nano, Super, Ultra, Nano 4B, Nano Omni and
legacy Llama-Nemotron) on a laptop, a DGX Spark, an RTX card or a datacenter GPU. It covers vLLM, SGLang, TensorRT-LLM,
llama.cpp, Ollama and TensorFold: reasoning and tool parsers, `enable_thinking` toggles, official NVFP4, FP8 and GGUF
quants, context limits, licenses and known bugs. Facts were read from upstream on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill nemotron
```

## Rules

- **Parsers are mandatory.** vLLM needs `--reasoning-parser nemotron_v3 --tool-call-parser qwen3_coder` (Nano uses the `nano_v3` plugin).
- **Reasoning is on by default.** Switch it off per request with `chat_template_kwargs {"enable_thinking": false}`.
- **Use card sampling.** Temperature 1.0 and top_p 0.95 for Lightning, Super and Ultra; 0.6 and 0.95 for Nano tool calls.
- **Pin the engine version the card names.** Hybrid Mamba MoE models hit regressions first; check `known-issues.md`.
- **Ask before installing, downloading or exposing anything.** Secrets stay in `0600` files or environment variables.

## References

- [`references/models.md`](references/models.md): generations, sizes, active parameters, context, official checkpoints, licenses.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): toggles, per-engine parser flags, copy-ready launch commands, sampling.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): DGX Spark, RTX, Apple Silicon, H100 and B200 picks, official and community quants, TensorFold qualified list.
- [`references/known-issues.md`](references/known-issues.md): symptom to fix table, open engine bugs and gaps.

## Companion skills

- `self-hosted-llms`: gateway, swapping and exposure on Linux GPU servers.
- `nvidia-dgx-spark`: DGX Spark setup.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`: engine operation.
- `local-llms`: laptops. `model-quantization`: GGUF, FP8 and NVFP4. `fine-tuning-llms`: finetuning. `cloud-llms`: hosted APIs.

## License

MIT
