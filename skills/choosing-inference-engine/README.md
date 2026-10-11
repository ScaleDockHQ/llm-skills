# Choosing an Inference Engine

Helps an agent pick an LLM inference engine for a given machine. It starts from the hardware, the model format, the features you need and the number of concurrent users, then recommends one engine and a fallback with the reason. It covers vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama, TensorFold and ExLlamaV3, and notes the status of MLX, LM Studio, NVIDIA Dynamo and Text Generation Inference.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine
```

## Rules

- **Decide from facts.** Discover the hardware first, then ask only what discovery cannot show.
- **Verify upstream.** The matrix is dated. Re-check the engine's support page for your exact GPU and model.
- **Gate numerics changes.** Quantization, KV-cache quantization and speculative decoding go through the `llm-evals` skill before serving traffic.
- **Measure, do not trust headlines.** Compare engines on the same model, quant, context and batch.
- **Never print secrets.** Keys live in `0600` files or environment variables.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): engine by hardware, by model format and quantization, and by feature, plus operational notes.
- [`references/adjacent-engines.md`](references/adjacent-engines.md): MLX, LM Studio, NVIDIA Dynamo and TGI status.

## Companion skills

- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: install and tune the chosen engine. Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
- `choosing-hardware`: size the machine for the model and concurrency.
- `choosing-llm-hosting`: decide local, owned server, cloud or hybrid.
- `self-hosted-llms`: serve the engine behind one authenticated endpoint.
- `local-llms`: run it on a laptop or desktop.
- `model-quantization`: produce the quant the engine wants.
- `llm-evals`: quality gate for numerics changes.

## License

MIT
