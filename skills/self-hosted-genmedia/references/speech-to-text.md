# Speech-to-text servers: whisper.cpp, Speaches, vLLM

> Verified against whisper.cpp v1.9.5, Speaches v0.9.0-rc.3 (master), vLLM docs (speech_to_text) and LiteLLM v1.105.0, 2026-10-11

## How it plugs into the stack

- **Format in:** `multipart/form-data` with `file` and `model` (the OpenAI shape). llama-swap reads `model` from the form to pick the upstream and applies `useModelName` rewrites to multipart bodies too.
- **Health:** whisper-server `GET <request-path>/health` (200 ready, 503 loading) and Speaches `GET /health` (public even with `API_KEY`) both make good `checkEndpoint`s.
- **Auth:** whisper-server has none: bind to `127.0.0.1`. Speaches enforces `API_KEY` on API routes; publish its container port with `127.0.0.1:` on the host and set `ENABLE_UI=false` on shared hosts.
- **LiteLLM:**

  ```yaml
  - model_name: whisper
    litellm_params:
      model: openai/whisper # llama-swap model id after the prefix
      api_base: http://127.0.0.1:8080/v1 # llama-swap
      api_key: os.environ/LLAMA_SWAP_KEY
    model_info:
      mode: audio_transcription
  ```

- **Operating:** whisper-server serves one request at a time, so use one llama-swap entry per model. Over Cloudflare a long synchronous transcription can exceed the 125 s read timeout; split audio or use a tailnet path.

Depth: install the whisper-cpp skill (npx skills add ScaleDockHQ/llms-skills --skill whisper-cpp), the faster-whisper skill (npx skills add ScaleDockHQ/llms-skills --skill faster-whisper) or the speaches skill (npx skills add ScaleDockHQ/llms-skills --skill speaches).
