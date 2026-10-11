# Pipeline B: realtime voice agents with Pipecat or LiveKit Agents

> Verified against Pipecat v1.12.0 (README, release 2026-09-26) and LiveKit Agents 1.8.6 (README, release 2026-10-09), LiveKit server v1.13.9, 2026-10-11

Choose these when you need phone or WebRTC calls, tuned turn-taking and interruption, your own client, or several participants. They are Python frameworks, not servers you configure: you write a small program that connects speech-to-text, an LLM and text-to-speech and runs it. Prove the models with pipeline A first; this file covers the shape only and was not run end to end for this skill.

## Pipecat

- Open-source Python framework (BSD-2-Clause) for real-time voice and multimodal agents. Minimum Python 3.11, 3.12 or newer recommended. Installs with `uv`: `uv tool install "pipecat-ai[cli]"` for the CLI (`pipecat init` scaffolds a project), or `uv add pipecat-ai` / `pip install "pipecat-ai[option,...]"` for the library with extras.
- Service list in the README includes STT (Whisper, Moonshine, and hosted services), LLMs (Ollama, OpenAI, and many others), TTS (Kokoro, Piper, XTTS, OpenAI, and hosted services) and transports (SmallWebRTC, Daily, LiveKit, WebSocket).
- Local pattern: Whisper or an OpenAI-compatible STT service, an Ollama or OpenAI-compatible LLM service pointed at your LiteLLM or Ollama URL, and a TTS service. Exact class names and install extras change between releases: read the service page for each (`https://docs.pipecat.ai/api-reference/server/services/...`) at the version you install, and run the bundled examples before writing your own.
- Pipecat also publishes Claude Code skills (`pipecat-ai/skills`) for scaffolding; those are upstream's, not this repo's.

## LiveKit Agents

- Apache-2.0 Python framework for voice agents on LiveKit. Install example from the README: `pip install "livekit-agents[openai,deepgram,cartesia]"` (pick the plugins you need).
- Run modes from the README: `python myagent.py console` (terminal test), `dev` (connect to a LiveKit server for development) and `start` (production). The agent connects to LiveKit Cloud or a self-hosted LiveKit server (Apache-2.0, v1.13.9); set the server URL and credentials in environment variables, never in code.
- Plugins and any local-model options differ by version; the README's default example uses LiveKit Inference through LiveKit Cloud, which is a hosted service. A fully local setup needs plugins that call your own OpenAI-compatible STT, LLM and TTS endpoints; confirm they exist for your version before committing to this path.

## Choosing

| Need                                             | Pick                                      |
| ------------------------------------------------ | ----------------------------------------- |
| Chat UI with a call button, least code           | Pipeline A (Open WebUI)                   |
| Python pipeline you fully control, any transport | Pipecat                                   |
| WebRTC rooms, telephony and a hosted option      | LiveKit Agents plus a LiveKit server      |
| Single speech-to-speech cloud model              | Hosted realtime APIs (outside this skill) |

## Wiring to the local models

Point the framework's STT, LLM and TTS services at the same loopback endpoints used in pipeline A: whisper-server on `:8081`, Ollama or LiteLLM on `:11434` or `:4000`, Kokoro-FastAPI on `:8880`. Keep every endpoint on loopback or a private network and keep keys in `0600` env files.

Skills to install later: none exist in this repo for Pipecat or LiveKit; treat the upstream docs above as the source and re-verify versions when you start.
