# Kimi

Helps an agent choose, serve and troubleshoot Moonshot AI's open-weight Kimi models: Kimi K3 (2.8T MoE, 1M context), the Kimi K2.x family (K2.7-Code, K2.6, K2.5, K2-Thinking, K2-Instruct-0905), Kimi-Linear-48B-A3B and Kimi-VL-A3B. It covers vLLM, SGLang, TensorRT-LLM, llama.cpp, MLX and Ollama (cloud-only for Kimi), says TensorFold has no Kimi support, and gives parser names, thinking toggles, sampling, quants per platform (DGX Spark, RTX, Apple Silicon, H100/H200, Blackwell, AMD), context limits, licenses and known bugs. Verified against upstream on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill kimi
```

## Rules

- **Ask before changing the system.** Kimi checkpoints are 595 GB to 1.56 TB; state the download size first.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Parser names, flags and versions are from pages read on 2026-10-11; K3 support moves fast.
- **Keep reasoning in the conversation.** K3 needs the full assistant message returned; K2.7-Code forces preserved thinking.
- **Validate tool calls.** Check `tool_calls` against your schema and retry on empty results.
- **Read the license.** K3 has a Model-as-a-Service clause; K2.x is Modified MIT; Linear and VL are MIT.

## References

- [`references/models.md`](references/models.md): generations, sizes, active parameters, modes, context, licenses.
- [`references/parsers-and-templates.md`](references/parsers-and-templates.md): parsers per engine, template quirks, reasoning toggles, sampling, version requirements.
- [`references/platforms-and-quants.md`](references/platforms-and-quants.md): what fits where, official and community quants with sizes, memory levers.
- [`references/known-issues.md`](references/known-issues.md): tool-parser bugs, `!!!!` output, hangs, install and license gotchas.

## Companion skills

- `self-hosted-llms`: gateway, model swapping and exposure for a GPU server.
- `local-llms`: laptop and desktop serving.
- `cloud-llms`: hosted Kimi APIs.
- `model-quantization`: GGUF, FP8, NVFP4 and MLX quants.
- `fine-tuning-llms`: tuning Kimi-Linear or Kimi-VL.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `mlx`, `ollama`, `tensorfold`, `tool-calling-parsers`: engine detail.

## License

MIT
