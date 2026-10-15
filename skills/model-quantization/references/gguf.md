# GGUF with llama.cpp

> Verified against llama.cpp v0.6.0 and master b11556 for the server default port (convert_hf_to_gguf.py, tools/quantize, tools/imatrix, tools/perplexity, docs/build.md), 2026-10-11

## How it plugs into this stack

- Choose GGUF when the target is llama.cpp / `llama-server`, Ollama or LM Studio, CPU, Apple Metal or mixed CPU+GPU inference.
- In: HF safetensors directory (BF16/FP16; FP8 sources are dequantized). Out: `.gguf` file(s), plus `mmproj-*.gguf` for vision models.
- Three steps: `convert_hf_to_gguf.py --outtype bf16`, `llama-imatrix` for 4-bit and below, then `llama-quantize` per type. Quantize every type from the BF16 GGUF, never from another quant.
- Wrap conversion, imatrix and builds in a memory-capped scope (`memory-safety.md`); on unified-memory machines stop serving first.
- Serve with `llama-server -m <file>.gguf --jinja -ngl all --host 127.0.0.1 --port 9931` (9931 is the default since b11521; v0.6.0 and older default to 8080); health at `GET /health`. Ollama and LM Studio import the same file (`local-llms` skill); llama-swap fronts multiple GGUFs (`self-hosted-llms` skill).
- Quality check with `llama-perplexity` KL divergence (`quality-checks.md`). Record the llama.cpp tag and exact commands in the model card (`publishing.md`).

Depth: install the gguf-quantization skill (npx skills add ScaleDockHQ/llm-skills --skill gguf-quantization). For the engine itself, install the llama-cpp skill (npx skills add ScaleDockHQ/llm-skills --skill llama-cpp).
