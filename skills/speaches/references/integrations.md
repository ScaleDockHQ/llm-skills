# Speaches: integrations

> Verified against Speaches master docs (open-webui-integration, voice-chat), LiteLLM v1.105.0 audio docs, llama-swap v263, 2026-10-11

## Any OpenAI client

Base URL `http://127.0.0.1:8000/v1`, API key = the `API_KEY` value (or any non-empty string when unset), model = a downloaded Hugging Face repo id or one of the aliases (`whisper-1`, `tts-1`, `tts-1-hd`). See `api.md`.

## LiteLLM

```yaml
model_list:
  - model_name: whisper
    litellm_params:
      model: openai/Systran/faster-whisper-small # openai/ + the Speaches model id
      api_base: http://127.0.0.1:8000/v1
      api_key: os.environ/SPEACHES_API_KEY
    model_info:
      mode: audio_transcription
  - model_name: tts
    litellm_params:
      model: openai/speaches-ai/Kokoro-82M-v1.0-ONNX
      api_base: http://127.0.0.1:8000/v1
      api_key: os.environ/SPEACHES_API_KEY
    model_info:
      mode: audio_speech
      health_check_voice: af_heart # LiteLLM health checks need a voice for audio_speech
```

`templates/litellm-speaches.yaml` is the same with comments. Clients then call LiteLLM's `/v1/audio/transcriptions` and `/v1/audio/speech` with `model=whisper` or `tts` and a LiteLLM key, so Speaches keeps one internal key while users get budgets and per-key limits (`litellm` skill).

## Open WebUI

Upstream's integration doc:

1. Admin Settings, Audio tab.
2. Speech-to-Text Engine: `OpenAI`; API Base URL `http://speaches:8000/v1` (use the host or container name Open WebUI can reach); API Key: the key (non-empty); Model: for example `Systran/faster-distil-whisper-large-v3`.

Environment variables for Compose: `AUDIO_STT_ENGINE=openai`, `AUDIO_STT_OPENAI_API_BASE_URL`, `AUDIO_STT_OPENAI_API_KEY`, `AUDIO_STT_MODEL`. Upstream warns these do not take effect if the STT engine was previously set in the UI. Pass the key from an env file, not inline. TTS settings follow Open WebUI's own docs.

## llama-swap

Speaches loads and unloads models itself, so a plain proxy entry is usually enough. If you want llama-swap to also start and stop the container and evict it when an LLM needs the GPU, see `combos/llama-swap-litellm.md` and `templates/llama-swap-speaches.yaml`.

## Voice chat

Speaches can chain STT, an LLM and TTS (audio in chat completions and the Realtime API). Point `CHAT_COMPLETION_BASE_URL` and `CHAT_COMPLETION_API_KEY` at any OpenAI-compatible LLM (default `http://localhost:11434/v1`, Ollama's port). See `realtime.md`.

## Reverse proxy and tunnels

Speaches does not set a request timeout shown in the docs; long synchronous transcriptions can hit a proxy's read timeout (Cloudflare's is 125 s per the `self-hosted-genmedia` skill). Use `stream=true` for SSE, split long audio, or stay on a private network. Pass WebSocket upgrades for `/v1/realtime`.
