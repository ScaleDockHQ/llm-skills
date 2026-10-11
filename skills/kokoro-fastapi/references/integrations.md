# Kokoro-FastAPI: integrations

> Verified against Kokoro-FastAPI v0.9.0 README and docs/integrations, LiteLLM v1.105.0 speech docs, 2026-10-11

## OpenAI clients

Base URL `http://127.0.0.1:8880/v1`, any non-empty API key (the server ignores it), model `kokoro` (or `tts-1`, `tts-1-hd`), voice such as `af_heart`. Use `with_streaming_response` to write audio to a file. Extra fields (`allow_voice_tags`, `voice_aliases`, `lang_code`) go in `extra_body`.

## LiteLLM

Kokoro-FastAPI has no auth, so LiteLLM is the place to enforce keys, budgets and rate limits:

```yaml
model_list:
  - model_name: tts
    litellm_params:
      model: openai/kokoro
      api_base: http://127.0.0.1:8880/v1
      api_key: placeholder-not-checked # the server ignores it; do not reuse a real key
    model_info:
      mode: audio_speech
      health_check_voice: af_heart # needed for LiteLLM health checks of audio_speech models
```

Clients call LiteLLM `/v1/audio/speech` with `model=tts`. See `templates/litellm-kokoro.yaml` and the `litellm` skill.

## Open WebUI

Upstream ships `docs/integrations/openwebui.md`. In short: Admin Settings, Audio, Text-to-Speech engine OpenAI, API base `http://<host>:8880/v1`, any key, model `kokoro`, voice such as `af_heart`. Open WebUI reads `voice['id']` from `/v1/audio/voices`, which is why the default response is `[{"id","name"}]`.

## Other known users (from the README)

Home Assistant bridges (`wyoming_openai`, `openai_tts`, `Kokoro-TTS`), app templates (Umbrel, Unraid, GPUStack, jetson-containers), reader and audiobook tools, voice agents, browser extensions. They are community projects; this skill did not verify their versions.

## Kubernetes

The README links a Helm chart guide at `docs/deployment/kubernetes.md` and other deployment guides under `docs/deployment`. Read them from the repo before use; they were not exercised here.

## With Speaches

Speaches can serve the Kokoro ONNX model next to STT in a single OpenAI-compatible server (`speaches` skill), with API-key auth built in. Choose Kokoro-FastAPI for its SSML, voice tags, captions, phoneme routes and PyTorch quality path; choose Speaches when you want one server for both directions.

## Exposure

With no auth and permissive default CORS, never publish the port beyond a trusted network. Put a reverse proxy with TLS and a key check in front (LiteLLM, Caddy, a tunnel with access control), or keep it on loopback and reach it through the gateway.
