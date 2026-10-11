# EXL3 with ExLlamaV3

> Verified against exllamav3 v1.6.1 (README.md, doc/convert.md) and TabbyAPI main @ 3932fd9, 2026-10-11

## How it plugs into this stack

- Choose EXL3 for single- or multi-NVIDIA-GPU serving through TabbyAPI at low bits per weight.
- In: HF safetensors (BF16/FP16). Out: HF-style directory with EXL3 safetensors and the original config/tokenizer files, made with `convert.py -b <bpw>` and a work dir that allows resuming.
- Serve with TabbyAPI (default port 5000, keys in `api_tokens.yml`, `GET /health` unauthenticated). It is an OpenAI-compatible backend: put it behind llama-swap or LiteLLM (`self-hosted-llms`, `llm-gateway` skills).
- Run conversions in a memory-capped scope (`memory-safety.md`) and quality-check against the BF16 base (`quality-checks.md`).

Depth: install the exl3-quantization skill (npx skills add ScaleDockHQ/llms-skills --skill exl3-quantization). For serving, install the exllamav3 skill (npx skills add ScaleDockHQ/llms-skills --skill exllamav3).
