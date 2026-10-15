# Qwen

Helps an agent serve Alibaba's Qwen3.x open models (Qwen3.8-27B, Qwen3.8-Flash-Next, Qwen3.8-2.4T-A95B, Qwen3.6, Qwen3.5, Qwen3-Coder-Next and the older Qwen3 line) with the right chat template handling, reasoning and tool parsers, thinking toggles, quants and context limits. It covers vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, MLX and TensorFold on a DGX Spark, consumer RTX, Apple Silicon and datacenter GPUs, plus licenses and known bugs. Everything was read from upstream pages on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill qwen
```

## Rules

- **Parsers are mandatory for agents.** `--reasoning-parser qwen3` and `--tool-call-parser qwen3_coder` on vLLM and SGLang; `qwen3_5` and `qwen3` on TensorRT-LLM.
- **Thinking is on by default** on Qwen3.5 to 3.8 and cannot be turned off on the 2.4T; use `enable_thinking` in `chat_template_kwargs`.
- **Set `reasoning_effort` on purpose.** The default `xhigh` is linked to empty answers and long reasoning; `medium` is the usual choice.
- **Stock Qwen3.8-27B template rejects mid-conversation system messages.** Plan for it with coding agents.
- **Use card sampling, never greedy.** 3.8 thinking is 1.0, 0.95, top-k 20.
- **Check the license.** Flash-Next and the 2.4T are not Apache-2.0.
- **Ask before changing the system**, and never print secrets.

## References

- [`references/models.md`](references/models.md): generations, sizes, active parameters, context, licenses, hosted-only names.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): template behaviour, toggles, per-engine flags, copy-ready commands, sampling, YaRN.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): quants, DGX Spark, RTX, Apple Silicon, datacenter, speculative decoding.
- [`references/known-issues.md`](references/known-issues.md): symptom to fix table and open gaps.

## Companion skills

- `self-hosted-llms`: the gateway, swapping and exposure stack on Linux GPU servers.
- `local-llms`: running models on a laptop.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`: engine install and operation.
- `tool-calling-parsers` and `reasoning-models`: parser and reasoning internals across engines.
- `model-quantization`, `fine-tuning-llms`, `cloud-llms`: making quants, finetuning, hosted APIs.

## License

MIT
