# Voice Stack

A stack skill for a self-hosted voice assistant: whisper.cpp for speech-to-text, Ollama or LiteLLM for the answer, Kokoro-FastAPI for speech, all behind Open WebUI Voice Mode. It also covers when to move to Pipecat or LiveKit Agents and records which components are still maintained (the original Piper repository is archived).

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill voice-stack
```

## Rules

- **Ask before changing the system.** Containers, ports and audio settings need approval.
- **Loopback for every audio server.** They have no documented authentication.
- **Test each hop alone first,** then the UI.
- **Check maintenance and licences** before adopting a component.

## References

- [`references/openwebui-voice-pipeline.md`](references/openwebui-voice-pipeline.md): STT and TTS servers, Open WebUI settings, smoke tests.
- [`references/realtime-agents.md`](references/realtime-agents.md): Pipecat and LiveKit Agents.
- [`references/components-and-maintenance.md`](references/components-and-maintenance.md): status, versions, licences.
- [`references/latency-and-troubleshooting.md`](references/latency-and-troubleshooting.md): latency, GPU sharing, symptoms.

## Companion skills

- `whisper-cpp`, `self-hosted-genmedia`, `ollama`, `litellm`, `llama-swap`, `ollama-open-webui-tailscale`.
- `open-webui`: not published yet. Install later when available.

## License

MIT
