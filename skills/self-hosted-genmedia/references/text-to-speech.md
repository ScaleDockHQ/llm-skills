# Text-to-speech servers: Kokoro-FastAPI and Speaches

> Verified against Kokoro-FastAPI v0.9.0, Speaches v0.9.0-rc.3 (master) and LiteLLM v1.105.0, 2026-10-11

## How it plugs into the stack

- **Format in:** JSON. **Out:** raw audio bytes (not base64); always use `-o file` in curl.
- **Health:** Kokoro-FastAPI `GET /health` and Speaches `GET /health` both make good llama-swap `checkEndpoint`s.
- **Auth:** Kokoro-FastAPI has no API-key setting: bind to loopback (`-p 127.0.0.1:...`) and enforce keys at LiteLLM; narrow `CORS_ORIGINS` (default `["*"]`) if reachable beyond localhost. Speaches supports `API_KEY` (Bearer).
- **llama-swap:** routes `v1/audio/speech` and `v1/audio/voices`. Kokoro-FastAPI expects `model: "kokoro"`, so set `useModelName: kokoro` if your llama-swap id differs.
- **LiteLLM:**

  ```yaml
  - model_name: tts
    litellm_params:
      model: openai/tts # llama-swap model id after the prefix
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMA_SWAP_KEY
    model_info:
      mode: audio_speech
      health_check_voice: af_heart
  ```

  LiteLLM's health check needs `health_check_voice` for `audio_speech` models.

- **Operating:** stream (`"stream": true`) or split long text for interactive use.

Depth: install the kokoro-fastapi skill (npx skills add ScaleDockHQ/llm-skills --skill kokoro-fastapi), the speaches skill (npx skills add ScaleDockHQ/llm-skills --skill speaches), the f5-tts skill (npx skills add ScaleDockHQ/llm-skills --skill f5-tts) or the chatterbox skill (npx skills add ScaleDockHQ/llm-skills --skill chatterbox).
