# whisper.cpp behind llama-swap, with LiteLLM in front

> Verified against whisper.cpp v1.9.5, llama-swap v263 and LiteLLM v1.105.0 docs (audio_transcription), 2026-10-11

Stack: `client -> LiteLLM :4000 -> llama-swap :8080 -> whisper-server :${PORT}`. whisper-server is mounted at the OpenAI path so every hop sees `POST /v1/audio/transcriptions`. The same entries appear in the `self-hosted-genmedia` skill's combined config, which also covers image and TTS servers.

## 1. whisper-server in llama-swap

```yaml
models:
  "whisper":
    cmd: |
      ${env.HOME}/src/whisper.cpp/build/bin/whisper-server
      --host 127.0.0.1 --port ${PORT}
      -m ${env.HOME}/models/whisper/ggml-large-v3-turbo.bin -l auto --convert
      --request-path /v1/audio --inference-path /transcriptions
    checkEndpoint: /v1/audio/health
    ttl: 300
```

- `checkEndpoint` must be `/v1/audio/health`: the health route is under `--request-path` (`api.md`). The default `/health` check would 404 with this mapping.
- llama-swap picks the upstream from the multipart `model` field, so clients send `-F model=whisper`. whisper-server ignores that field itself.
- `--convert` needs ffmpeg for the service user. Drop it and require 16 kHz WAV if you cannot install ffmpeg.
- Keep `--host 127.0.0.1`; llama-swap `apiKeys` is the only auth in the path.

`templates/llama-swap-whisper.yaml` is the entry with comments.

## 2. Sharing the GPU with an LLM

A quantized turbo model is small (547 MiB file, `models.md`), so it normally stays resident next to an LLM; set a longer `ttl` or `ttl: 0`. If the LLM takes the whole GPU, put both in an exclusive swap group so loading one evicts the other:

```yaml
routing:
  router:
    use: group
    settings:
      groups:
        voice:
          swap: true
          exclusive: true
          members: ["whisper", "<your-llm>"]
```

Budget memory with `self-hosted-genmedia`; install it with `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-genmedia`.

## 3. LiteLLM

```yaml
model_list:
  - model_name: whisper
    litellm_params:
      model: openai/whisper # openai/ prefix + llama-swap model id
      api_base: http://127.0.0.1:8080/v1 # llama-swap, keep /v1
      api_key: os.environ/LLAMA_SWAP_API_KEY
      timeout: 600
    model_info:
      mode: audio_transcription
```

`templates/litellm-whisper.yaml` is the same entry. Clients call LiteLLM's `/v1/audio/transcriptions` with `model=whisper` and a LiteLLM key.

## 4. Test each hop

```bash
# 1. server alone, mounted at the OpenAI path
WHISPER_URL=http://127.0.0.1:8081/v1/audio/transcriptions scripts/transcribe.sh sample.wav
# 2. through llama-swap (the request starts the model)
curl -fsS http://127.0.0.1:8080/v1/audio/transcriptions -H "Authorization: Bearer $LLAMA_SWAP_API_KEY" \
  -F file=@sample.wav -F model=whisper | jq -r .text
# 3. through LiteLLM
curl -fsS http://127.0.0.1:4000/v1/audio/transcriptions -H "Authorization: Bearer $LITELLM_KEY" \
  -F file=@sample.wav -F model=whisper | jq -r .text
```

Run hop 1 against a copy started by hand on a spare port (here 8081). The hop-2 and hop-3 commands were not run against live services when this file was written.

## Pitfalls

- Default `checkEndpoint` (`/health`) never succeeds with the path mapping.
- Without `-l auto`, non-English audio is decoded as English (`troubleshooting.md`).
- One request at a time per whisper-server process: concurrent clients queue, and LiteLLM timeouts count the queue.
- Through Cloudflare, long synchronous transcriptions can hit the proxy's read timeout; split audio or use a private path.
