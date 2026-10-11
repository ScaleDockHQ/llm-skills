# Ollama with Hugging Face GGUF (and Unsloth exports)

> Verified against Ollama v0.40.3 and the Hugging Face Hub Ollama integration page, 2026-10-11

Unsloth docs checked only for the existence of `save_pretrained_gguf` and its Ollama tutorial

Three ways to get a Hub GGUF into Ollama, from easiest to most controlled.

## 1. Run directly from the Hub

```bash
ollama run hf.co/<user>/<repo>                  # Q4_K_M if present, else a reasonable quant from the repo
ollama run hf.co/<user>/<repo>:Q8_0             # choose a quant (case-insensitive tag)
ollama run hf.co/<user>/<repo>:<exact-file>.gguf
ollama pull hf.co/<user>/<repo>:Q4_K_M          # download without running
```

`huggingface.co/<user>/<repo>` works as the prefix too. The chat template comes from the GGUF's `tokenizer.chat_template` metadata. To override without a Modelfile, add files to the repository: `template` (a Go template, not Jinja), `system` (system prompt) and `params` (JSON sampling parameters). Private repos: add the contents of `~/.ollama/id_ed25519.pub` as an SSH key in your Hugging Face account settings (never paste the private key).

The local name is long (`hf.co/user/repo:quant`). Alias it for clients: `ollama cp hf.co/<user>/<repo>:Q4_K_M my-model`.

## 2. Download then import with a Modelfile

Use this when you need a fixed context, a different template or offline reproducibility. Download with the Hugging Face CLI (see the `hugging-face` skill; keep tokens in env vars), then:

```dockerfile
FROM ./Model-Q4_K_M.gguf      # split GGUF: FROM ./Model-*.gguf with the original shard names
PARAMETER num_ctx 32768
# Only if the GGUF has no usable template or the template is wrong:
# TEMPLATE """..."""
# PARAMETER stop "<|im_end|>"
```

```bash
ollama create my-model -f Modelfile && ollama show my-model && ollama run my-model "Say hi"
```

Ollama does not quantize on import; pick the quant on the Hub, or quantize yourself with llama.cpp's `llama-quantize` first (`model-quantization` skill).

## 3. Your own fine-tune (Unsloth and similar)

1. Train with LoRA or full fine-tuning (`fine-tuning-llms` skill).
2. Export a merged GGUF. Unsloth documents `model.save_pretrained_gguf(...)`; its Ollama tutorial also creates a `Modelfile` automatically and ends with `ollama run unsloth_model`. Check the current Unsloth docs for the exact arguments before using them.
3. Import with a Modelfile (method 2).

**Do not use `ADAPTER`.** Ollama v0.40.3 rejects LoRA adapters ("LoRA adapters are no longer supported"). Always import merged weights.

## Pitfalls

- Gibberish or endless generations from a fine-tune usually mean a template or stop-token mismatch with how it was trained (Unsloth's inference docs list this symptom for Ollama and vLLM); compare `ollama show --template` and `--parameters` with the training format.
- Model architecture too new for the bundled engine: the pull works but loading fails; update Ollama (`updating.md`) or use `llama-cpp` built from a recent tag.
- Big GGUFs are slow to download and need disk twice if you convert; set `OLLAMA_MODELS` to a large volume.
- Imported models are stored as ordinary Ollama blobs; delete the downloaded `.gguf` afterwards if space matters (`ollama rm` removes only the Ollama copy).
