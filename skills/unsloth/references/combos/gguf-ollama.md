# Unsloth fine-tune to Ollama via GGUF

> Verified against unslothai/unsloth library 2026.10.3 and Ollama v0.40.3, 2026-10-11

Goal: take a model fine-tuned with Unsloth, export a GGUF, and run it as an Ollama model with the template you trained on. Depth for the pieces: `npx skills add ScaleDockHQ/llm-skills --skill ollama`, `--skill llama-cpp`, `--skill model-quantization`.

## Why GGUF and a merge

Current Ollama releases reject LoRA adapters (`ollama create` fails with "LoRA adapters are no longer supported", checked in the sibling `fine-tuning-llms` and `ollama` skills against v0.40.3). So the model must be merged and converted: Unsloth's `save_pretrained_gguf` does the merge and the conversion in one call.

## 1. Export from Unsloth

```python
model.save_pretrained_gguf("gguf_out", tokenizer, quantization_method="q4_k_m")
# or a list: quantization_method=["q8_0", "q4_k_m"]
```

Run it memory-capped; it builds llama.cpp and uses a lot of RAM on large models. If it OOMs, lower `maximum_memory_usage` (for example 0.5) or export `f16`/`bf16`/`q8_0` and quantize with llama.cpp afterwards (`model-quantization`). The exact output filenames and whether a `Modelfile` is written next to the GGUF vary by version: list the output directory and use what is there (**unverified** which files appear on 2026.10.3).

```bash
ls -lh gguf_out
```

## 2. Create the Ollama model

Unsloth builds a `Modelfile` automatically in its notebook flow (`create_ollama_modelfile` in `unsloth/save.py`), carrying the chat template used for the fine-tune. If you have to write one by hand, point `FROM` at the GGUF and set the template and stop tokens to match training:

```
FROM ./gguf_out/<model>-Q4_K_M.gguf
PARAMETER num_ctx 8192
# TEMPLATE and PARAMETER stop lines must match the chat template used in training.
```

```bash
ollama create my-finetune -f ./Modelfile
ollama run my-finetune "Say hi"
```

Ollama's REST server listens on `127.0.0.1:11434`; keep it there unless the user approves exposure.

## 3. Verify

- Compare outputs with the in-Unsloth model on 5-10 held-out prompts, not only one.
- Template or EOS mismatch shows as gibberish, endless or repeated output; fix the template first (`references/troubleshooting.md`).
- Record the Unsloth version, base model revision, quant type and Ollama version next to the model.

## Alternatives

- llama.cpp `llama-server` can load a merged GGUF, or a base GGUF plus an adapter GGUF via `--lora` (skills `llama-cpp`, `fine-tuning-llms`).
- vLLM: skip GGUF, serve merged 16-bit or the adapter (skill `vllm`).
