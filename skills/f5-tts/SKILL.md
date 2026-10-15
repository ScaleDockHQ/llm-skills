---
name: f5-tts
description: Install and run F5-TTS, the flow-matching zero-shot voice-cloning text-to-speech model (F5TTS_v1_Base, E2-TTS) with f5-tts_infer-cli, the Gradio app, the Python F5TTS API and the socket server, with reference audio and ref_text rules. Use for f5-tts, SWivid/F5-TTS, "clone a voice from a short clip", nfe_step, sway sampling, SHARED.md language checkpoints, or the CC-BY-NC weights licence. No OpenAI-style server is bundled. For fixed-voice TTS use kokoro-fastapi; for an alternative cloner use chatterbox.
license: MIT
compatibility: Linux, Windows and macOS with Python 3.10+, PyTorch for CUDA, ROCm, Intel XPU, Apple MPS or CPU, and ffmpeg; Docker image for NVIDIA GPUs. Installs, model downloads and any listener beyond loopback need the user's explicit approval. The pretrained weights are CC-BY-NC.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# F5-TTS

Clone a voice from a few seconds of reference audio and synthesise speech with F5-TTS on the user's hardware, from the CLI, a Python call, the bundled Gradio app or the streaming socket server.

**Scope:** this one project: install, run, tune, update, troubleshoot, point to fine-tuning. It ships no OpenAI-compatible HTTP server. Choosing a TTS stack belongs to `self-hosted-genmedia`; fixed-voice TTS with an OpenAI API is `kokoro-fastapi`; another zero-shot cloner is `chatterbox`. Facts below were verified on f5-tts 1.1.22 (2026-07-23 release, repo active 2026-10-11).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version; command -v ffmpeg f5-tts_infer-cli f5-tts_infer-gradio
python3 -c 'import f5_tts, torch; print(torch.__version__, torch.cuda.is_available(), getattr(torch.backends,"mps",None) and torch.backends.mps.is_available())' 2>&1 | tail -2
pip list 2>/dev/null | grep -iE '^(f5-tts|torch|torchaudio|gradio|transformers) '
nvidia-smi -L 2>/dev/null; uname -sm
ls ~/.cache/huggingface/hub 2>/dev/null | grep -iE 'F5|vocos|whisper'
```

## Decision flow

1. Check the licence first (`references/models-and-licences.md`): the code is MIT but the pretrained models are CC-BY-NC. For commercial use you need other weights or your own training data.
2. Not installed: `references/install.md` (virtualenv or conda, PyTorch matched to the device, then `pip install f5-tts`).
3. One-off audio: `references/inference.md` (CLI with a `.toml`, reference audio rules, tuning knobs).
4. From Python or a service: the `F5TTS` class in `references/inference.md`; the Gradio app, socket server and TensorRT-LLM runtime are in `references/serving.md`.
5. Another language or a fine-tune: `references/models-and-licences.md` (community checkpoints in `SHARED.md`), training pointers in `references/training.md`.
6. Upgrade: `references/updating.md`. Bad audio, silence or errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, large PyTorch wheels and Hugging Face downloads need approval; use a virtualenv.
- **Licence check before commercial use.** Code MIT; pretrained checkpoints CC-BY-NC (Emilia training data). Say so to the user before recommending it for a product.
- **Consent for cloned voices.** Only clone voices you have permission to use; do not impersonate. Mark generated audio as synthetic where required.
- **Reference audio under 12 s with trailing silence.** Longer or hard-clipped clips truncate words. Give a correct `ref_text`, or leave it empty so the ASR model (`openai/whisper-large-v3-turbo`) transcribes it (extra GPU memory).
- **One generation covers 30 s total** including the reference. The CLI and Gradio app chunk longer text; the raw API does not.
- **Never expose Gradio or the socket server publicly.** No authentication. `--share` creates a public link; the socket server binds `0.0.0.0` by default. Use loopback and a gateway.
- **Verify upstream.** Defaults and checkpoints move; read `f5-tts_infer-cli --help` on the installed version.

## Workflows

- [ ] Create the environment, install the right PyTorch, `pip install f5-tts` -> `references/install.md`
- [ ] Prepare a clean reference clip (under 12 s, mono speech, 1 s trailing silence) and its transcript -> `references/inference.md`
- [ ] Run `f5-tts_infer-cli` with `--ref_audio`, `--ref_text`, `--gen_text` and listen -> `references/inference.md`, `scripts/clone.sh`
- [ ] Tune `nfe_step`, `speed`, `cfg_strength`, `remove_silence` for the use case -> `references/inference.md`
- [ ] Optional: Gradio app on loopback, or the socket server for streaming -> `references/serving.md`
- [ ] Optional: language checkpoint or fine-tune -> `references/models-and-licences.md`, `references/training.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: the output WAV plays, is not silent, matches the text, uses the intended voice, and any listener is on loopback.

## Reference index

- `references/install.md`: PyTorch per device, pip and editable installs, Docker, ffmpeg.
- `references/inference.md`: CLI flags, `.toml` config, multi-voice, Python API, tuning, text rules.
- `references/serving.md`: Gradio app, socket server protocol, TensorRT-LLM runtime, wrapping in an HTTP service.
- `references/models-and-licences.md`: model names, checkpoints on Hugging Face, community language models, licences.
- `references/training.md`: dataset prep and fine-tuning entry points from the repo.
- `references/updating.md`: releases, pinning, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/f5-basic.toml`: CLI config.
- `scripts/clone.sh`: wrapper around `f5-tts_infer-cli` with guard rails (bash).

## Companion skills

- `kokoro-fastapi`: fixed-voice TTS with an OpenAI-compatible API. Install: `npx skills add ScaleDockHQ/llm-skills --skill kokoro-fastapi`.
- `chatterbox`: another zero-shot voice-cloning TTS with a different licence. Install: `npx skills add ScaleDockHQ/llm-skills --skill chatterbox`.
- `self-hosted-genmedia`: choose speech and image stacks and place them next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `faster-whisper`: transcribe reference clips accurately. Install: `npx skills add ScaleDockHQ/llm-skills --skill faster-whisper`.
- `hugging-face`: model cache and tokens. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
