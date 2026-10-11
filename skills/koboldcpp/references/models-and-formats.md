# KoboldCpp models and formats

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

## What it loads

GGUF text models only (llama.cpp based), plus separate files for each extra capability:

| Capability       | Flag                                                                       | File                                               |
| ---------------- | -------------------------------------------------------------------------- | -------------------------------------------------- |
| Text             | `--model`                                                                  | GGUF                                               |
| Vision           | `--mmproj`                                                                 | mmproj GGUF matching the text model                |
| Draft model      | `--draftmodel`                                                             | small GGUF with a matching vocabulary              |
| LoRA             | `--lora`, `--loramult`                                                     | GGUF LoRA (convert with `convert_lora_to_gguf.py`) |
| Images and video | `--sdmodel` (+ `--sdvae`, `--sdclip1`, `--sdclip2`, `--sdllm`, `--sdlora`) | safetensors or GGUF                                |
| Speech to text   | `--whispermodel`                                                           | Whisper `.bin`                                     |
| Text to speech   | `--ttsmodel` (+ `--ttswavtokenizer`, `--ttsdir`)                           | TTS GGUF                                           |
| Music            | `--musicllm`, `--musicembeddings`, `--musicdiffusion`, `--musicvae`        | ACE-Step style set                                 |
| Embeddings       | `--embeddingsmodel`                                                        | embedding GGUF                                     |

The README lists starter models and premade templates (Hugging Face `koboldcpp` org). Pick current models
from there or from your own research; the list changes.

## Fit rule of thumb

Weights file size + KV cache + a few GB must fit. KV grows linearly with `--contextsize`; `--quantkv q8_0`
about halves it relative to f16 (verify quality). If VRAM is short: smaller quant, shorter context, fewer
GPU layers, or `--moecpu` for MoE models (expert weights stay in RAM). Autofit (`--gpulayers -1`) estimates
the layer split and is "an estimate and may need manual adjustment" (README). `--autofitpadding MB`
reserves spare VRAM.

## Inspect and convert

```bash
<binary> --analyze model.gguf        # architecture, context, tensor types
```

Convert your own Hugging Face model with the repo's `convert_hf_to_gguf.py`, then quantize (the README links
a hosted tools page and `quantize_gguf`). For quant choice see the `gguf-quantization` skill.
`convert_llama_ggml_to_gguf.py` upgrades old GGML files.

## Context length

Defaults to 16384. Larger than the model's trained context needs RoPE scaling: NTK-aware is automatic;
override with `--ropeconfig` and `--overridenativecontext`. Check the trained value in `--analyze`.

## Vision

Load the matching `--mmproj` file with the text model; `--visionmaxres` clamps image size (512..2048,
default 1024). Send images as OpenAI `image_url` content parts.

## Downloads

`--model` accepts URLs and saves to `--downloaddir`. Prefer downloading with a tool you trust and pointing at
a local path; never put tokens in URLs you show.
