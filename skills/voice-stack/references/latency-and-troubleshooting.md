# Latency, GPU sharing and troubleshooting

> Verified against Open WebUI v0.12.0 (voice-mode and audio troubleshooting docs), whisper.cpp v1.9.5 (`whisper-cpp` skill), Kokoro-FastAPI v0.9.0 (docs/configuration.md) and Ollama v0.40.3, 2026-10-11

## Where time goes (Standard Voice Mode)

1. **End-of-speech wait.** Voice Mode sends after about two seconds of silence; this is fixed by the app, so it dominates a short answer.
2. **STT.** whisper-server decodes one request at a time. A quantized turbo model is small (see `whisper-cpp` `models.md`) and normally stays resident next to an LLM.
3. **LLM first token.** A cold model reloads after Ollama's keep-alive expires; set keep-alive or preload (`ollama` skill). A big reasoning model is a poor voice model: pick a fast instruct model.
4. **TTS.** Kokoro inference is synchronous per process. Open WebUI speaks sentence by sentence (Response Splitting = Punctuation), so first audio needs only the first sentence from the LLM.

Measure each hop with `curl -w '%{time_total}\n' -o /dev/null -s ...` against the smoke tests, then change one thing at a time. Targets are yours: no figure here is a benchmark.

## Memory and GPU

- STT, LLM and TTS all want accelerator memory. Put whisper and Kokoro on CPU if the LLM needs the whole GPU, or give them small fixed slices; Kokoro has a CPU image and an ONNX path (README).
- To swap instead of co-residing, use llama-swap groups (`whisper-cpp` `combos/llama-swap-litellm.md` shows an exclusive `voice` group) and the budgets in `self-hosted-genmedia`.
- `WEB_CONCURRENCY` raises Kokoro workers; each loads its own model copy.

## Prompt for speech

Voice Mode's built-in prompt asks for short, conversational answers. If you replace it (`VOICE_MODE_PROMPT_TEMPLATE`), keep lists, markdown and URLs out of the reply: they are read aloud.

## Symptom table

| Symptom                                                   | Check                                                                                                                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| "Permission denied when accessing media devices"          | Not HTTPS or localhost (docs). Use the Tailscale Serve URL, not the LAN IP                                                                                               |
| "Call feature is not supported when using Web STT engine" | Admin STT engine is "Web API"; set `AUDIO_STT_ENGINE=openai` or local Whisper                                                                                            |
| Keeps listening, never sends                              | Background noise defeats the two-second silence rule; mute or move                                                                                                       |
| STT 404                                                   | whisper-server not started with `--request-path /v1/audio --inference-path /transcriptions`, or base URL missing `/v1`                                                   |
| STT returns wrong language or English-only text           | whisper-server default is `-l en` and an English model; start with `-l auto` and a multilingual model (`whisper-cpp` skill)                                              |
| Non-wav audio rejected                                    | Start whisper-server with `--convert` and install ffmpeg                                                                                                                 |
| No sound from the model                                   | `curl` the Kokoro endpoint directly; check `AUDIO_TTS_ENGINE=openai`, base URL ending in `/v1`, voice name from `/v1/audio/voices`; Open WebUI logs show the failing URL |
| Container cannot reach 127.0.0.1:8081 or :8880            | Bridge network: `127.0.0.1` is the container. Use host networking or `host.docker.internal` with ports published where reachable                                         |
| Reply starts late                                         | LLM cold load or a slow model; test the LLM alone and keep the model resident                                                                                            |
| Env changes ignored                                       | Audio settings are persistent config; change them in Admin > Settings > Audio or set `ENABLE_PERSISTENT_CONFIG=false`                                                    |
| Choppy or slow speech on CPU                              | Kokoro CPU image on an underpowered host; try the GPU image or a smaller concurrent workload                                                                             |

## Undo

Remove the audio env vars or reset Admin > Settings > Audio to the built-in engines, then `docker rm -f kokoro` and stop whisper-server. Models and the Open WebUI volume are untouched.
