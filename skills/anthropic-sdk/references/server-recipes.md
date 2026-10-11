# Anthropic SDK recipes per self-hosted server

> Verified against anthropic-sdk-python v1.13.0, anthropic-sdk-typescript sdk-v0.133.0, vLLM (Anthropic router and bearer-only auth middleware), llama.cpp server README, Ollama Anthropic-compatibility docs, llama-swap README, 2026-10-11

`base_url` is always the server root **without** `/v1`. Hosts and ports are defaults; use yours. Keys come from a `0600` file, never inline. A gateway in front gives stable names and per-app keys.

| Server                   | `base_url`               | Credential option                                        | Model string                                |
| ------------------------ | ------------------------ | -------------------------------------------------------- | ------------------------------------------- |
| vLLM                     | `http://host:8000`       | `auth_token` (Bearer only)                               | `--served-model-name`, else repo id or path |
| llama.cpp `llama-server` | `http://host:8080`       | either, per the probe; none if no key                    | `--alias`; by default the model path        |
| Ollama (local)           | `http://localhost:11434` | placeholder, ignored (`ollama` in docs)                  | the tag, for example `qwen3:8b`             |
| Ollama cloud             | `https://ollama.com`     | `auth_token` (Bearer; `x-api-key` alone is not accepted) | a cloud model name                          |
| LiteLLM proxy            | `http://host:4000`       | virtual or master key (Bearer or `x-api-key`)            | the `model_name` alias                      |
| llama-swap               | `http://host:8080`       | per its config                                           | the model id from its config                |

Probe: `BASE=http://host:PORT MODEL=<id> LLM_API_KEY_FILE=<file> scripts/check-endpoint.sh` prints the `/v1/messages` status with a Bearer header and with `x-api-key`, so you can see which one the server accepts. List ids with `curl -fsS -H "Authorization: Bearer $LLM_API_KEY" http://host:PORT/v1/models | jq -r '.data[].id'`.

## vLLM

vLLM serves `/v1/messages` and checks `Authorization: Bearer` for `--api-key` (from `--api-key` or `VLLM_API_KEY`). The SDK's `api_key` sends `x-api-key`, which vLLM rejects with 401: use `auth_token`. Tools need `--enable-auto-tool-choice --tool-call-parser <name>`.

## llama.cpp

`/v1/messages` and `/v1/messages/count_tokens` exist; tool use requires `--jinja`. The server accepts the key given with `--api-key` or `--api-key-file`; verify with the probe which of the two headers your build accepts.

## Ollama

Local Ollama ignores the key. Supported on the Messages route: messages, streaming, system prompts, multi-turn, vision (base64 images), tools and tool results, thinking. It is a subset of Anthropic's API: check the docs' unsupported list before relying on a field. Keep port 11434 on loopback or behind a gateway.

## LiteLLM proxy

Exposes `/v1/messages` and translates to whatever backend the alias points to (including OpenAI-compatible engines), so one gateway can serve both SDKs with the same alias. Use virtual keys with model allow-lists. Beta headers may be forwarded to the backend: drop `betas` if you get 400s.

## llama-swap

Lists `v1/messages` and `v1/messages/count_tokens`. The model in the body selects and swaps the engine process, so the first call after a swap is slow: raise `timeout` or pre-warm.

## Behind a reverse proxy

- Keep any path prefix in `base_url`: `https://llm.example.com/anthropic` becomes `/anthropic/v1/messages`.
- Disable SSE buffering and raise idle timeouts above model load time.
- If SSO or basic auth sits in front, pass its credential via `default_headers` and keep the model-server key in `auth_token`/`api_key`, or terminate the front door in the gateway.

## Official links

- vLLM: https://docs.vllm.ai/
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama Anthropic compatibility: https://docs.ollama.com/api/anthropic-compatibility
- LiteLLM proxy: https://docs.litellm.ai/docs/simple_proxy
- llama-swap: https://github.com/mostlygeek/llama-swap
