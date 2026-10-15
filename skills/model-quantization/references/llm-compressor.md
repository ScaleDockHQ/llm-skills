# AWQ, GPTQ, FP8 and NVFP4 with LLM Compressor

> Verified against vllm-project/llm-compressor 0.14.0 (README.md, docs/faq/faq.md) and vLLM v0.31.0, 2026-10-11

## How it plugs into this stack

- Use LLM Compressor when the serving engine is vLLM (or SGLang, with partial support) and you want W4A16 (GPTQ or AWQ), FP8 or NVFP4 as a compressed-tensors checkpoint. Pick the scheme from the GPU (`formats.md`): Ampere W4A16, Ada and Hopper FP8, Blackwell NVFP4.
- In: HF model directory or Hub id. Out: an HF directory with compressed safetensors and a `quantization_config` in `config.json`. No CLI: you run a short script around `oneshot()`.
- Install it in its own venv, separate from the vLLM you serve with (upstream FAQ: they can have dependency mismatches).
- Run the script in a memory-capped scope and stop serving first on unified-memory nodes (`memory-safety.md`).
- Serve with `vllm serve <dir>`; vLLM detects compressed-tensors from the config, so no `--quantization` flag is needed. Smoke-test and compare with the base model (`quality-checks.md`), then publish with the script and package versions in the card (`publishing.md`).

Depth: install the llm-compressor skill (npx skills add ScaleDockHQ/llm-skills --skill llm-compressor)
