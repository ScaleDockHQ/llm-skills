---
name: voice-stack
description: Self-hosted voice assistant pipeline, speech-to-text (whisper.cpp), an LLM (Ollama or LiteLLM) and text-to-speech (Kokoro-FastAPI) behind Open WebUI Voice Mode, with a path to Pipecat or LiveKit Agents for realtime phone and web agents. Use to wire STT, LLM and TTS together, set Open WebUI audio engines, smoke-test each hop, cut latency and fix mic, no-audio and slow-reply problems. Not for engine depth (whisper-cpp, ollama, self-hosted-genmedia).
license: MIT
compatibility: Linux or macOS with Docker, bash, curl and jq; GPU optional. Browser microphone needs HTTPS or localhost. Installing services, opening ports and changing Open WebUI audio settings need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Voice stack: STT + LLM + TTS

Talk to your own models: whisper.cpp transcribes, an LLM answers, Kokoro speaks, all on hardware you control.

**Scope:** the glue between these parts. Depth lives in `whisper-cpp`, `ollama`, `litellm` and `self-hosted-genmedia` (which covers Kokoro-FastAPI). Open WebUI has no skill yet (install later: `open-webui` skill) and neither do Pipecat, LiveKit or Piper (install later: none planned in this repo; use upstream docs linked in the references).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. No secrets printed.

```bash
curl -fsS http://127.0.0.1:11434/api/version | jq .                      # Ollama
curl -fsS http://127.0.0.1:8081/v1/audio/health                          # whisper-server on the OpenAI path mapping
curl -fsS http://127.0.0.1:8880/health                                   # Kokoro-FastAPI
curl -fsS http://127.0.0.1:8880/v1/audio/voices | jq -r '.voices | length' 2>/dev/null
curl -fsS http://127.0.0.1:8080/health                                   # Open WebUI
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i -E 'open-webui|kokoro|whisper|ollama'
command -v ffmpeg whisper-server nvidia-smi 2>/dev/null
```

## Decision flow

1. Want a browser chat with a call button and your own voices: pipeline A, Open WebUI Voice Mode (`references/openwebui-voice-pipeline.md`).
2. Need phone calls, barge-in tuned for a product, multi-party rooms or your own UI: pipeline B, a realtime framework (`references/realtime-agents.md`). Start with A to prove the models first.
3. GPU or memory is tight: size STT, LLM and TTS together before starting all three (`references/latency-and-troubleshooting.md`, and `self-hosted-genmedia` for budgets).
4. Remote access from a phone: HTTPS is required for the microphone; use the `ollama-open-webui-tailscale` stack, then add this skill's audio endpoints on loopback.
5. Check each component is still maintained before adopting it (`references/components-and-maintenance.md`): Piper's original repo is archived.

## Rules

- **Ask before changing the system.** Containers, services, ports and admin audio settings need approval and an undo path.
- **Loopback for every audio server.** whisper-server and Kokoro-FastAPI have no documented authentication; reach them only from Open WebUI or your agent on the same host.
- **Recordings are personal data.** Do not log, keep or upload audio you did not mean to; say where transcripts are stored (Open WebUI keeps chats in its data volume).
- **Pin tags.** Kokoro-FastAPI says to pin a release tag instead of `:latest`; do the same for Open WebUI.
- **Test each hop alone first.** STT, then LLM, then TTS, then the UI.
- **Verify upstream.** Versions, flags and env names come from upstream docs read on the writing date.

## Build the stack

- [ ] STT: whisper-server mapped to `/v1/audio/transcriptions` -> `whisper-cpp` skill, `references/openwebui-voice-pipeline.md`
- [ ] LLM: Ollama (or LiteLLM) answering short replies -> `ollama` skill, `references/latency-and-troubleshooting.md`
- [ ] TTS: Kokoro-FastAPI on loopback -> `references/openwebui-voice-pipeline.md`
- [ ] Open WebUI audio settings for STT and TTS, then a Voice Mode call -> `references/openwebui-voice-pipeline.md`
- [ ] Optional: realtime agent with Pipecat or LiveKit Agents -> `references/realtime-agents.md`
- [ ] Verify: each smoke test passes alone, a spoken question gets a spoken answer, and first audio arrives within your latency target.

## Reference index

- `references/openwebui-voice-pipeline.md`: STT and TTS servers, Open WebUI env and admin settings, per-hop smoke tests.
- `references/realtime-agents.md`: Pipecat and LiveKit Agents with local STT, LLM and TTS; when to choose them.
- `references/components-and-maintenance.md`: maintenance status, versions and licences of each component, skills to install later.
- `references/latency-and-troubleshooting.md`: latency budget, GPU sharing, symptom table.

## Companion skills

- `whisper-cpp`: whisper-server build, models, OpenAI path mapping. Install: `npx skills add ScaleDockHQ/llm-skills --skill whisper-cpp`.
- `self-hosted-genmedia`: Kokoro-FastAPI, Speaches, GPU budgets next to LLMs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `ollama`: the LLM server. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama`.
- `litellm`: gateway with `audio_transcription` and speech models. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llama-swap`: swap STT, TTS and LLM on one GPU. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`.
- `ollama-open-webui-tailscale`: private HTTPS access to Open WebUI. Install: `npx skills add ScaleDockHQ/llm-skills --skill ollama-open-webui-tailscale`.
- `open-webui`: not published yet. Install later: `npx skills add ScaleDockHQ/llm-skills --skill open-webui`.
