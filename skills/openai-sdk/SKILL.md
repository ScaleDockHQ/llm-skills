---
name: openai-sdk
description: OpenAI Python and Node SDKs pointed at self-hosted endpoints. Use to set base_url/baseURL and OPENAI_API_KEY for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, map model names, pick Chat Completions or Responses, stream, call tools, set timeouts, or fix 404, 401, tool_calls missing, Missing credentials, connection errors. Not for Anthropic SDK (anthropic-sdk) or AI SDK.
license: MIT
compatibility: Commands assume bash, curl, jq, and Python 3.9+ or Node.js 20+ with the openai package. Installing packages and changing app config need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenAI SDK against self-hosted endpoints

Application code that talks to your own model server through the official `openai` package (Python `openai`, Node `openai`), with the right base URL, key handling, model names and API choice, and a probe that proves the endpoint before the app is blamed.

**Scope:** the OpenAI SDKs as clients of OpenAI-compatible servers. Anthropic Messages clients belong to `anthropic-sdk`; the gateway belongs to `litellm` or `llama-swap`; engines to `vllm`, `llama-cpp`, `ollama`; parser flags to `tool-calling-parsers`; choosing among clients to `llm-clients`.

## Discover first

Read-only, never prints secret values.

```bash
python3 -c 'import openai; print(openai.__version__)' 2>/dev/null; npm ls openai 2>/dev/null | grep openai@
env | grep -E '^OPENAI_(BASE_URL|API_KEY|CUSTOM_HEADERS)=' | sed -E 's/=.*/=<set>/'     # which vars exist, no values
env | grep -E '^OPENAI_BASE_URL=' ; env | grep -E '^(HTTPS?_PROXY|NO_PROXY)=' | sed -E 's#//[^@/]*@#//<redacted>@#'
BASE=http://localhost:4000 MODEL=<id> LLM_API_KEY_FILE=~/.config/llm/key scripts/check-endpoint.sh   # models, chat, tools, stream
```

Ask only what discovery cannot show: server and URL, whether it needs a key, whether it serves Chat Completions only or also Responses, whether the app needs tools or streaming.

## Decision flow

1. **Endpoint not proven yet:** run `scripts/check-endpoint.sh`. Fix the server before touching app code. -> `references/troubleshooting.md`
2. **Base URL and key:** `base_url` ends in `/v1`; the key is any non-empty string if the server has no auth. -> `references/client-config.md`
3. **Which API:** `chat.completions` works on every engine; `responses` only where the server implements `/v1/responses`. -> `references/apis-tools-streaming.md`
4. **Model name:** use the id returned by `GET /v1/models` (`--served-model-name`, gateway alias, Ollama tag). -> `references/server-recipes.md`
5. **Tools or structured output fail:** server flags, `tool_calls` parsing, `strict` and `stream` caveats. -> `references/apis-tools-streaming.md`
6. **Error:** match the status or message. -> `references/troubleshooting.md`

## Rules

- **Never hardcode or print keys.** Read from `OPENAI_API_KEY` or a `0600` file; do not log request headers, `client.api_key` or the full environment.
- **`base_url` includes `/v1`** and never `/chat/completions`. A missing `/v1` gives 404 on every call.
- **`OPENAI_BASE_URL` is picked up by every OpenAI-SDK program** in the shell, including tools you did not mean to redirect. Prefer constructor arguments in application code and an env var only for a deliberate switch.
- **The SDK raises if no key is available** (Python: `Missing credentials`; Node: `OPENAI_API_KEY` error). For keyless servers pass a dummy string such as `"none"`.
- **Probe before blaming code.** One `curl` through the same URL, key and model id isolates server from client.
- **Defaults are generous.** Python and Node default to 600 s timeout (Python connect 5 s) and 2 retries; set them explicitly for long generations and for fail-fast health checks.
- **Check versions upstream.** Flags and defaults come from the SDK release notes and the server's docs, not memory.
- **Other skills:** install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

## Workflows

### Point an app at a self-hosted server

- [ ] Probe: `BASE=... MODEL=... scripts/check-endpoint.sh` passes models, chat, and (if needed) tool and stream lines.
- [ ] Set `base_url` (with `/v1`) and key via env or constructor -> `references/client-config.md`.
- [ ] Use the model id from `/v1/models`.
- [ ] Choose `chat.completions` unless the probe shows `/v1/responses` works.
- [ ] Pass vendor options through `extra_body` and non-standard auth through `default_headers`.
- [ ] Run one real request and one streamed request from the app.

### Add tool calling

- [ ] Server started with tool parsing on (vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama.cpp `--jinja`) -> `references/server-recipes.md`.
- [ ] Probe prints a `tool_call:` line.
- [ ] Execute the returned call, send a `tool` role message with the matching `tool_call_id`, and request again.

### Debug a failing call

- [ ] Re-run the same call with `curl -v` or `check-endpoint.sh`; read the server log line.
- [ ] If curl works, diff URL, key header, model id and body against the SDK request (`OPENAI_LOG=debug` in both SDKs; redact the Authorization line before sharing).

## Reference index

| File                                 | Read when                                                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `references/client-config.md`        | Constructors, env vars, keys, headers, timeouts, retries, proxies, TLS                                    |
| `references/apis-tools-streaming.md` | Chat Completions vs Responses, streaming, usage, tools, structured output, reasoning fields, `extra_body` |
| `references/server-recipes.md`       | vLLM, llama.cpp, Ollama, LiteLLM, llama-swap: URLs, auth, model names, flags                              |
| `references/troubleshooting.md`      | Symptom to cause to fix                                                                                   |

Assets: `assets/client.mjs` (Node smoke test). Script: `scripts/check-endpoint.sh` (read-only probe).

## Companion skills

- `anthropic-sdk`: the same job for Anthropic Messages clients.
- `litellm`, `llama-swap`: gateways that give stable model names and keys.
- `vllm`, `llama-cpp`, `ollama`: engines behind the endpoint.
- `tool-calling-parsers`: when `tool_calls` come back empty.
- `llm-clients`: choosing and troubleshooting clients of every kind.
