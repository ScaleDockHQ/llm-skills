# whisper.cpp: integrations

> Verified against whisper.cpp v1.9.5, llama-swap v263 and LiteLLM v1.105.0 docs, 2026-10-11

## OpenAI SDKs and curl

Mount the server at the OpenAI path (`serve-configuration.md`) and point the SDK at it:

```bash
curl -fsS http://127.0.0.1:8080/v1/audio/transcriptions \
  -F file=@sample.wav -F model=whisper -F response_format=json | jq -r .text
```

The OpenAI SDK posts to `<baseURL>/audio/transcriptions`, so with the mapping above set `baseURL` to `http://127.0.0.1:8080/v1` and use any non-empty `apiKey` (the server has no auth). Mind the gaps in `api.md` (no `/v1/models`, no `timestamp_granularities`). Prefer the stack paths below for anything beyond a test.

## llama-swap

One entry per model; the proxy forwards multipart uploads and chooses the upstream by the `model` form field (the existing `self-hosted-genmedia` stack relies on this). Use `/v1/audio/health` as `checkEndpoint`. Template: `templates/llama-swap-whisper.yaml`. Install the proxy skill: `npx skills add ScaleDockHQ/llm-skills --skill llama-swap`. For a long-running or memory-hungry LLM, put whisper in a swap group so loading one evicts the other.

## LiteLLM

`model_info.mode: audio_transcription` with `openai/<llama-swap id>` and `api_base` at llama-swap. Template: `templates/litellm-whisper.yaml`. Set `timeout` high for long files. LiteLLM supplies the API-key and rate-limit layer that whisper-server lacks: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.

## Other speech servers

If you need an OpenAI-shaped multi-model STT server with TTS, or vLLM batching, compare Speaches and vLLM in the `self-hosted-genmedia` skill (`npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`).

## Apps that call it

Anything that can POST multipart works: shell scripts (`scripts/transcribe.sh`), n8n or Zapier HTTP nodes, a meeting-notes pipeline. Feed the transcript to an LLM through the gateway. Keep the server on loopback or a private network.
