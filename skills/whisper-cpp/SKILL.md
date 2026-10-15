---
name: whisper-cpp
description: Build, run and tune whisper.cpp, the C/C++ Whisper speech-to-text engine (whisper-cli, whisper-server) with ggml models, quantization, VAD and Core ML, CUDA, Vulkan or Metal builds. Use for ggml-large-v3-turbo, download-ggml-model.sh, whisper-server /inference or OpenAI /v1/audio/transcriptions paths, --convert ffmpeg, -l auto, q5_0, "failed to read audio", or adding whisper-server to llama-swap and LiteLLM. Not for Speaches, faster-whisper or vLLM STT.
license: MIT
compatibility: macOS, Linux, Windows; CPU, Apple Metal/Core ML, NVIDIA CUDA, Vulkan, ROCm and others; needs git, cmake, a C++ compiler, curl and jq (ffmpeg for non-WAV input). Builds, services, model downloads and any bind beyond loopback need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# whisper.cpp

Get a working, tuned whisper.cpp transcription CLI or HTTP server on the user's hardware, optionally behind an OpenAI-shaped `/v1/audio/transcriptions` path, and keep it updatable.

**Scope:** this one product: build, models, CLI, `whisper-server`, performance, update, troubleshoot. Choosing between STT servers (Speaches, vLLM, whisper.cpp) and the full media stack belongs to `self-hosted-genmedia`. Facts below were verified on whisper.cpp v1.9.5 (2026-10-11); `whisper-server -h` on the installed binary is the final word.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v whisper-cli whisper-server whisper-quantize ffmpeg cmake 2>/dev/null
whisper-cli --version 2>&1 | head -2
ls ~/whisper.cpp/build/bin/whisper-server ~/whisper.cpp/models/ggml-*.bin 2>/dev/null
uname -sm; nvidia-smi -L 2>/dev/null; vulkaninfo --summary 2>/dev/null | grep -m2 deviceName
free -h 2>/dev/null || sysctl hw.memsize
# Running server (adjust host/port/path); 200 and {"status":"ok"} when ready, 503 while loading
curl -fsS 127.0.0.1:8080/health 2>/dev/null; curl -fsS 127.0.0.1:8080/v1/audio/health 2>/dev/null
ps -eo args | grep -E '[w]hisper-server'
```

## Decision flow

1. Nothing installed: build (`references/install.md`). Pick the backend from the hardware: Metal is on by default on Apple builds, add Core ML for the encoder on Apple silicon, CUDA `-DGGML_CUDA=1`, Vulkan `-DGGML_VULKAN=1`, else CPU.
2. One-off files: `whisper-cli` with a 16 kHz WAV (`references/cli.md`).
3. A service other programs call: `whisper-server` (`references/serve-configuration.md`, `references/api.md`).
4. Clients speak OpenAI `/v1/audio/transcriptions`: mount the server there with `--request-path /v1/audio --inference-path /transcriptions` (`references/api.md`). Server default is `/inference`.
5. Pick a model or shrink one: `references/models.md`. Speed or memory: `references/performance-memory.md`.
6. Behind llama-swap, LiteLLM or an app: `references/integrations.md`, `references/combos/llama-swap-litellm.md`.
7. Upgrade: `references/updating.md`. Wrong text or errors: `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Builds, services, model downloads (hundreds of MB to GB) and binding beyond `127.0.0.1` need approval.
- **Bind loopback and sandbox it.** `whisper-server` has no auth. Upstream warns: do not run it with administrative privileges and run it sandboxed, since it accepts uploads and shells out to ffmpeg with `--convert`.
- **Set the language.** Server and CLI default to `-l en`; other languages come back as garbage until you pass `-l auto` or the code.
- **16 kHz WAV or `--convert`.** Without ffmpeg conversion, feed 16-bit WAV (README); `--convert` needs ffmpeg on the server host.
- **Secrets stay out of output.** If a model host needs a token (`HF_TOKEN` for the download script), read it from the environment or a `0600` file.
- **Verify upstream.** Defaults moved between releases (flash attention is on by default in the v1.9.5 source while the README table still shows false); check `-h` on the installed binary.

## Workflows

- [ ] Build with the right backend -> `references/install.md`
- [ ] Download a model (`sh ./models/download-ggml-model.sh large-v3-turbo`) and check disk and memory first -> `references/models.md`
- [ ] Smoke-test with the CLI on `samples/jfk.wav` -> `references/cli.md`
- [ ] Start the server on loopback, test `GET /health` then `POST /inference` -> `references/serve-configuration.md`, `scripts/transcribe.sh`
- [ ] Mount at the OpenAI path and test with curl and an OpenAI SDK -> `references/api.md`
- [ ] Add to llama-swap and LiteLLM -> `references/combos/llama-swap-litellm.md`, `templates/`
- [ ] Tune (quantization, VAD, threads, Core ML) -> `references/performance-memory.md`
- [ ] Update -> `references/updating.md`
- [ ] Verify: `/health` is ok, a known WAV returns the expected text, `-l auto` is set for non-English use, and the process listens on `127.0.0.1` only.

## Reference index

- `references/install.md`: CMake builds per backend, Docker images (platform caveat), binaries produced, download script.
- `references/cli.md`: `whisper-cli` flags, output formats, input audio, VAD, grammar, benchmarking.
- `references/serve-configuration.md`: `whisper-server` flags and defaults, request path mapping, ffmpeg conversion, service unit.
- `references/api.md`: endpoints, multipart fields, response formats, `/load`, `/health`, error bodies, OpenAI compatibility gaps.
- `references/models.md`: model names and sizes, quantized variants, VAD models, tinydiarize, converting, Parakeet note.
- `references/performance-memory.md`: backends, Core ML, OpenVINO, quantization, threads, flash attention, VAD, memory table.
- `references/integrations.md`: llama-swap, LiteLLM, OpenAI SDKs, other clients, security.
- `references/updating.md`: releases and nightlies, rebuild, model compatibility, rollback.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/llama-swap-litellm.md`: whisper-server in llama-swap with LiteLLM `audio_transcription` in front.
- `templates/`: `whisper-server.service`, `llama-swap-whisper.yaml`, `litellm-whisper.yaml`.
- `scripts/transcribe.sh`: transcribe a file through a running server (bash, curl, jq).

## Companion skills

- `self-hosted-genmedia`: choose among whisper.cpp, Speaches and vLLM; co-resident placement next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `llama-swap`: run whisper-server next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `litellm`: keys, budgets and routing in front. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-cpp`: sibling ggml engine for LLMs; same build tooling. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `hugging-face`: model downloads and cache. Install: `npx skills add ScaleDockHQ/llm-skills --skill hugging-face`.
