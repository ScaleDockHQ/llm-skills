---
name: chatterbox
description: Install and run Chatterbox, Resemble AI's MIT-licensed open text-to-speech family (Turbo 350M, Nano 110M, Multilingual V3 with 23 languages, original English) with zero-shot voice cloning, [laugh] paralinguistic tags, exaggeration and cfg_weight, voice conversion and PerTh watermarking. Use for chatterbox-tts, ChatterboxTurboTTS, ChatterboxMultilingualTTS, language_id, t3_model v3, "voice agent TTS", or a Gradio demo. No HTTP server is bundled. For fixed voices use kokoro-fastapi; for F5 cloning use f5-tts.
license: MIT
compatibility: Linux, macOS (MPS) and Windows with Python 3.10+ (developed on 3.11) and PyTorch for CUDA, MPS or CPU (Nano targets CPU). Installs and Hugging Face downloads need the user's explicit approval. The package pins exact torch and transformers versions, so use a dedicated virtualenv.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Chatterbox

Synthesise speech, optionally in a cloned voice, with Chatterbox models on the user's hardware, pick the right model for the job, and keep voice cloning consensual and watermarked.

**Scope:** this one project: install, choose a model, generate, tune, update, troubleshoot. It ships Python classes and Gradio demos but no OpenAI-compatible server. Choosing a TTS stack belongs to `self-hosted-genmedia`; fixed-voice TTS with an API is `kokoro-fastapi`; another cloner is `f5-tts`. Facts below were verified against the Chatterbox repository `master` (last push 2026-07-21; README with Turbo, Nano and Multilingual V3) and PyPI `chatterbox-tts` 0.1.7 (2026-03-26) on 2026-10-11.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version; command -v ffmpeg
pip list 2>/dev/null | grep -iE '^(chatterbox-tts|torch|torchaudio|transformers|gradio|resemble-perth) '
python3 -c 'import torch; print(torch.__version__, torch.cuda.is_available(), torch.backends.mps.is_available())' 2>&1 | tail -1
nvidia-smi -L 2>/dev/null; uname -sm
ls ~/.cache/huggingface/hub 2>/dev/null | grep -i chatterbox
python3 -c 'import chatterbox, pkgutil; print([m.name for m in pkgutil.iter_modules(chatterbox.__path__)])' 2>&1 | tail -1
```

## Decision flow

1. Pick a model (`references/models.md`): English voice agents -> Turbo; CPU or on-device English -> Nano; many languages -> Multilingual V3; English with emotion dials -> original Chatterbox.
2. Install (`references/install.md`). PyPI has 0.1.7 from March 2026, which predates V3 and Nano (merged May to July 2026), so Nano and V3 need a source install.
3. Generate (`references/usage.md`): load the class, call `generate`, save with `torchaudio`. Reference clips drive cloning.
4. Tune expressiveness and pacing (`references/usage.md`): `exaggeration`, `cfg_weight`, `temperature`, tags.
5. Serving as a Gradio app or a service, and the risks of the shipped demos: `references/serving.md`.
6. Safety, watermark, licences: `references/safety-and-licences.md`.
7. Upgrade: `references/updating.md`. Errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs (pinned torch 2.6.0 and transformers 5.2.0 on Python below 3.14), Hugging Face downloads and listeners need approval. Use a dedicated virtualenv.
- **Consent for cloned voices.** Only use reference audio of people who agreed. Upstream's disclaimer: do not use the model to do bad things. Every output carries a PerTh watermark; do not strip it.
- **Match model and call.** `ChatterboxTurboTTS` for Turbo and Nano (`nano=True`), `ChatterboxMultilingualTTS` for multilingual (`t3_model="v3"`, `language_id`), `ChatterboxTTS` for the original. Turbo and Nano ignore `exaggeration`, `cfg_weight` and `min_p`.
- **Reference language must match the target.** A mismatched reference transfers its accent; set `cfg_weight=0` to mitigate (upstream tip).
- **Do not run the shipped Gradio demos as-is on a shared host.** Two of them call `launch(share=True)` (public link) and the multilingual app launches with `mcp_server=True`. See `references/serving.md`.
- **Secrets stay out of output.** `HF_TOKEN` comes from the environment.
- **Verify upstream.** The repo moves faster than its PyPI releases; read the class signatures in the installed version.

## Workflows

- [ ] Choose the model for the job -> `references/models.md`
- [ ] Create a virtualenv; install from PyPI (original, Turbo, Multilingual V2) or from source (Nano, V3) -> `references/install.md`
- [ ] Generate a test sentence on the intended device and listen -> `references/usage.md`, `scripts/say.sh`
- [ ] Add a clean reference clip for cloning (with permission) -> `references/usage.md`
- [ ] Tune `exaggeration`, `cfg_weight`, tags -> `references/usage.md`
- [ ] If serving, wrap one loaded model in a loopback service with auth -> `references/serving.md`
- [ ] Update or pin -> `references/updating.md`
- [ ] Verify: audio is non-silent and intelligible, the sample rate is read from `model.sr`, the watermark check returns 1.0, and no public listener is open.

## Reference index

- `references/models.md`: model zoo, sizes, languages, single-language pack, Hub repos, which class loads what.
- `references/install.md`: PyPI versus source, pins, platform notes (Apple MPS), first-run downloads, `HF_TOKEN`.
- `references/usage.md`: code for each model, `generate` signatures and defaults, tags, tuning tips, voice conversion.
- `references/serving.md`: demo apps and their risks, wrapping the model in a service, concurrency.
- `references/safety-and-licences.md`: PerTh watermark and detection, licences, consent.
- `references/updating.md`: release status, PyPI lag, pinning, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `templates/requirements-lock.txt.example`: how to freeze a known-good environment.
- `scripts/say.sh`: generate one WAV from the CLI through a tiny inline Python call (bash).

## Companion skills

- `f5-tts`: another zero-shot cloner (CC-BY-NC weights). Install: `npx skills add ScaleDockHQ/llms-skills --skill f5-tts`.
- `kokoro-fastapi`: fixed-voice TTS with an OpenAI-compatible API. Install: `npx skills add ScaleDockHQ/llms-skills --skill kokoro-fastapi`.
- `speaches`: OpenAI-compatible speech server (STT and Kokoro TTS). Install: `npx skills add ScaleDockHQ/llms-skills --skill speaches`.
- `self-hosted-genmedia`: choose a speech stack and place it next to LLMs. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.
- `hugging-face`: model cache and tokens. Install: `npx skills add ScaleDockHQ/llms-skills --skill hugging-face`.
