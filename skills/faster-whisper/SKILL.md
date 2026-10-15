---
name: faster-whisper
description: Install, run and tune faster-whisper, the CTranslate2 Python reimplementation of OpenAI Whisper for speech-to-text (WhisperModel, BatchedInferencePipeline), with CUDA, int8, VAD, word timestamps and converted models. Use for pip install faster-whisper, compute_type, large-v3-turbo, distil-large-v3, "Could not load library libcudnn", segments generator, hotwords, ct2-transformers-converter. Not for an OpenAI-style HTTP STT server (use speaches) or the C++ engine (use whisper-cpp).
license: MIT
compatibility: Linux, macOS and Windows with Python 3.9+; CPU (int8) or NVIDIA CUDA 12 with cuBLAS and cuDNN 9. No system ffmpeg needed (PyAV bundles it). Installs, model downloads from Hugging Face and GPU libraries need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# faster-whisper

Get a working, tuned faster-whisper transcription setup in Python on the user's hardware: right device and `compute_type`, a verified smoke test, and a path to serve it over HTTP through Speaches.

**Scope:** this one library: install, load models, transcribe, tune, convert, update, troubleshoot. It has no server of its own. The OpenAI-compatible HTTP server built on it is the `speaches` skill; the C/C++ engine is `whisper-cpp`; choosing between them belongs to `self-hosted-genmedia`. Facts below were verified on faster-whisper v1.2.1 and PyPI `ctranslate2` 4.8.2 (2026-10-11); read the installed package source when in doubt.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets. `scripts/doctor.sh` runs the same checks.

```bash
python3 --version
python3 -c 'import faster_whisper, ctranslate2; print(faster_whisper.__version__, ctranslate2.__version__); print(ctranslate2.get_supported_compute_types("cuda"))' 2>&1 | tail -3
python3 -c 'import ctranslate2; print(ctranslate2.get_cuda_device_count())' 2>&1 | tail -1
nvidia-smi -L 2>/dev/null; ldconfig -p 2>/dev/null | grep -E 'libcudnn|libcublas' | head -4
uname -sm; free -h 2>/dev/null || sysctl hw.memsize
ls ~/.cache/huggingface/hub 2>/dev/null | grep -iE 'whisper' | head
```

## Decision flow

1. Not installed: `references/install.md`. NVIDIA GPU needs cuBLAS for CUDA 12 and cuDNN 9; otherwise run on CPU with `compute_type="int8"`.
2. Transcribe files from Python: `references/python-api.md`. Remember `segments` is a lazy generator.
3. Many files or long audio on a GPU: wrap the model in `BatchedInferencePipeline` (`references/performance-memory.md`).
4. Pick a model, a distilled model or a converted fine-tune: `references/models.md`.
5. Other programs need an HTTP API: run Speaches (it uses faster-whisper) rather than writing a server; `references/integrations.md`.
6. Upgrade or pin: `references/updating.md`. Errors, missing text or hallucinations: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** `pip install`, GPU libraries and model downloads (hundreds of MB to several GB) need approval. Use a virtualenv, not the system Python.
- **Iterate the generator.** `model.transcribe()` returns before any decoding; work happens when you loop over `segments` or call `list(segments)`. Timing or "empty result" bugs usually come from not consuming it.
- **Set `language` for known audio.** Auto-detection costs time and can misfire on short clips; pass `language="nl"` and, for English-only distil models, use `.en` or `distil-*` ids.
- **Match `compute_type` to the device.** CPU: `int8` or `float32`. GPU: `float16` or `int8_float16`. Check `ctranslate2.get_supported_compute_types(device)` rather than guessing.
- **Beam size differs from openai-whisper.** faster-whisper defaults to `beam_size=5`; openai-whisper's `transcribe` uses 1. Compare speed and accuracy with the same setting.
- **Model weights have their own licences.** Check the Hugging Face model card (`models.md`); the library is MIT.
- **Secrets stay out of output.** Private or gated models use `use_auth_token` from the `HF_TOKEN` environment variable or the Hugging Face CLI login, never inline.
- **Verify upstream.** Defaults moved between releases; read `faster_whisper/transcribe.py` of the installed version.

## Workflows

- [ ] Create a virtualenv and install `faster-whisper` -> `references/install.md`
- [ ] Add GPU libraries if using CUDA and confirm `get_cuda_device_count() > 0` -> `references/install.md`
- [ ] Smoke test with a short clip and `tiny` or `small` -> `references/python-api.md`
- [ ] Choose the model and `compute_type` -> `references/models.md`, `references/performance-memory.md`
- [ ] Enable VAD, word timestamps or batching as needed -> `references/python-api.md`
- [ ] Optional: serve over HTTP with Speaches -> `references/integrations.md` and the `speaches` skill
- [ ] Update or pin -> `references/updating.md`
- [ ] Verify: the known clip transcribes to the expected text, the detected language is right, the device used is the intended one, and memory stays under budget.

## Reference index

- `references/install.md`: pip, CUDA 12 libraries, Docker base image, source installs, version pins.
- `references/python-api.md`: `WhisperModel`, `transcribe()` options and defaults, batched pipeline, VAD, word timestamps, outputs.
- `references/models.md`: built-in model names, distil and turbo models, conversion with `ct2-transformers-converter`, licences.
- `references/performance-memory.md`: compute types, batching, threads, workers, benchmark figures from upstream.
- `references/integrations.md`: Speaches, WhisperX, whisper-ctranslate2, streaming projects, and what each adds.
- `references/updating.md`: releases, CTranslate2 pairing, pinning and rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `scripts/doctor.sh`: read-only environment check (bash).

## Companion skills

- `speaches`: OpenAI-compatible STT and TTS server on top of faster-whisper. Install: `npx skills add ScaleDockHQ/llm-skills --skill speaches`.
- `whisper-cpp`: C/C++ Whisper engine with ggml models and Core ML or Metal. Install: `npx skills add ScaleDockHQ/llm-skills --skill whisper-cpp`.
- `self-hosted-genmedia`: choose a speech stack and place it next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `hugging-face`: model downloads, cache and tokens. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
