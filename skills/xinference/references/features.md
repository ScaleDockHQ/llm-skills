# Xinference features and client APIs

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

Base URL `http://127.0.0.1:9997`. Any OpenAI client works with `base_url=http://HOST:9997/v1`; the `model` is the
model UID. With auth on, the API key is an Xinference key (`api-and-auth.md`); with auth off any non-empty string.

## Chat, completions, tools

`/v1/chat/completions` and `/v1/completions` accept the OpenAI fields, including `tools` (function calling),
`stream`, `stream_options.include_usage`. Tool calling depends on the model family's ability: check
`model_ability` in `xinference registrations` and test with a real tool call. Thinking models: launch with
`--enable-thinking` (hybrid models such as Qwen3). `ignore_eos=true` is accepted for fixed-length benchmarks.

Cache-hit accounting: with vLLM, SGLang and MLX, `usage.prompt_tokens_details.cached_tokens` reports reused prompt
tokens (Responses: `usage.input_tokens_details.cached_tokens`). With P/D it includes KV transferred from prefill.

## Responses API (v4.0) and Anthropic API

- `POST /v1/responses`: stateless. `previous_response_id` and `conversation` are rejected; send the whole
  conversation in `input`. Supports text and image input, function and custom tools, reasoning, structured
  output, streaming. Hosted tools such as `web_search` are ignored.
- Codex CLI custom provider in `~/.codex/config.toml`: `model_provider = "xinference"`,
  `[model_providers.xinference] base_url = "http://HOST:9997/v1"`, `wire_api = "responses"`.
- Anthropic: base URL `http://HOST:9997/anthropic`, endpoint `/anthropic/v1/messages` (Claude Code and the
  Anthropic SDK can point at it).

## Multimodal input

`image_url`, `video_url`, `audio_url` parts in chat messages. Since v3.5 the server refuses URLs resolving to
loopback, private or link-local addresses (`XINFERENCE_MEDIA_BLOCK_PRIVATE_ADDRESS=true`) and `file://` or
bare paths (`XINFERENCE_MEDIA_ALLOW_LOCAL_PATH=false`). Send `data:` URIs or public HTTP(S) URLs, or relax the
flags only on a trusted, unexposed server. Limits: `XINFERENCE_MEDIA_MAX_BYTES` (64 MiB), fetch timeout 20 s.

## Embeddings and rerank

```bash
xinference launch --model-type embedding -n bge-small-en-v1.5 --model-uid emb
curl -s http://127.0.0.1:9997/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"model":"emb","input":["What is the capital of China?"]}' | jq '.data[0].embedding|length'
xinference launch --model-type rerank -n bge-reranker-base --model-uid rr
```

Rerank endpoint: `POST /v1/rerank` with `model`, `query`, `documents`. Python: `model.rerank(corpus, query)`.
v3.4+ adds multimodal embedding and rerank abilities on supported models.

## Images, video, audio

- Image: `--model-type image`; OpenAI-style `/v1/images/generations`, `/edits`, `/variations`, `/inpainting`, `/ocr`; an SD WebUI compatible API (`/sdapi/v1/*`, see the `sd_webui` guide, expanded in v3.4) with LoRA via `--lora-modules` and image LoRA kwargs.
- Video: `--model-type video`; `/v1/video/generations` (also `/flf` and `/image`), for example Wan models.
- Audio: `--model-type audio` for speech to text (`/v1/audio/transcriptions`), text to speech
  (`/v1/audio/speech`) and music; speaker embeddings for some TTS models. Web UI has streaming TTS playback.
- Image and diffusion engines use their own native batching; check per-model docs.

## Web UI

`/` (and `/ui` on a supervisor): launch with **Recommend configuration**, per-replica placement, launch
history, runtime log center, monitoring, user and key management, audit center, system settings.
