# Models and formats in llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

llamafile loads GGUF weights, the same format as llama.cpp, plus an `--mmproj` GGUF for vision and audio input. The model set follows the llama.cpp version bundled in the release (0.10.6 updated llama.cpp to b10441); the pre-built file's model card names the server it bundles.

## Pre-built 0.10 llamafiles

Hosted in the Hugging Face repo `mozilla-ai/llamafile_0.10`. Upstream lists Qwen3.5 (0.8B, 2B, 4B, 9B, 27B), Ministral 3 3B, llava v1.6 mistral 7b, Apertus 8B Instruct, gpt-oss 20b (mxfp4 and Q5_K_S) and LFM2 24B A2B, from 1.6 GB to 19 GB. Check each model's license (most Apache 2.0; LFM2 uses its own license). Smaller is easier: Qwen3.5 0.8B Q8 runs at about 8 tokens per second on a Raspberry Pi 5, per upstream.

Older 0.9 llamafiles (Llama 3.x, Gemma 3, Mixtral, Phi-3, DeepSeek-R1 distills and others) use the legacy server and do not get new-model support.

## Bring your own GGUF

```bash
llamafile -m /models/model-Q4_K_M.gguf --server -ngl 999
llamafile -hf <org>/<repo> -hff <file>.gguf --server        # download first, then serve
```

Pick a quantization that fits memory with room for the KV cache (see `gguf-quantization`, `npx skills add ScaleDockHQ/llm-skills --skill gguf-quantization`). On NVIDIA, the bundled CUDA library omits IQ-quant kernels (`IQ1_*` to `IQ4_*`): layers of IQ-quantized models stay on the CPU automatically, so output is correct but slower. Q*\_*, MXFP4, NVFP4, F16 and BF16 run fully on the GPU. Metal and ROCm builds include IQ kernels. For full IQ acceleration on NVIDIA, build or supply a full CUDA library (`references/performance-tuning.md`).

## Models from other tools

- LM Studio: weights are under `~/.cache/lm-studio/models/lmstudio-community/<model>-GGUF/`; pass the `.gguf` to `-m`.
- Ollama: blobs are sha256-named files in `~/.ollama/models/blobs`. The manifest in `~/.ollama/models/manifests/registry.ollama.ai/library/` maps the GGUF layer (`mediaType` `application/vnd.ollama.image.model`) to its digest; pass that blob to `-m`. Ollama GGUFs do not always load in llama.cpp.

## Multimodal

Vision models need weights and a projector:

```bash
llamafile -ngl 9999 --temp 0 --cli --image photo.jpg \
  -m llava-v1.6-mistral-7b.Q4_K_M.gguf --mmproj mmproj-model-f16.gguf -p 'Describe this picture'
```

Pre-bundled vision llamafiles (Ministral 3, llava 1.6) need only `--image`. Qwen3.5, Ministral 3 and llava 1.6 are documented as good candidates; in chat mode use `/upload`.

## Embeddings and rerankers

Run a pooling-enabled model with `--embedding` (and `--pooling` when needed) or `--rerank` to enable `/v1/embeddings` and `/v1/rerank`. The old `llamafiler` embeddings server is not in 0.10.*; the llama.cpp endpoints replace it.

## Speech and images

Separate programs, not modes of `llamafile`: `whisperfile` and `transcribefile` for speech to text, `diffusionfile` for Stable Diffusion. See `references/features.md`.
