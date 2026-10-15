---
name: anthropic-sdk
description: Anthropic Python and TypeScript SDKs pointed at self-hosted endpoints. Use to set base_url/baseURL, ANTHROPIC_AUTH_TOKEN vs ANTHROPIC_API_KEY for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap Messages routes, map model names, stream, call tools, or fix 404 /v1/v1/messages, 401, anthropic-beta rejected, max_tokens errors. Not for OpenAI SDK (openai-sdk) or Claude Code.
license: MIT
compatibility: Commands assume bash, curl, jq, and Python 3.9+ or Node.js 20+ with the anthropic package. Installing packages and changing app config need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Anthropic SDK against self-hosted endpoints

Application code that talks to your own server's Anthropic Messages route (`/v1/messages`) through the official `anthropic` (Python) or `@anthropic-ai/sdk` (Node) package, with the right base URL, the right auth header, model names that exist on the server, and a probe that proves the route before the app is blamed.

**Scope:** the Anthropic SDKs as clients of Anthropic-compatible servers (engines and gateways). OpenAI-style clients belong to `openai-sdk`; gateways to `litellm` or `llama-swap`; engines to `vllm`, `llama-cpp`, `ollama`; parser flags to `tool-calling-parsers`; choosing clients to `llm-clients`.

## Discover first

Read-only, never prints secret values.

```bash
python3 -c 'import anthropic; print(anthropic.__version__)' 2>/dev/null; npm ls @anthropic-ai/sdk 2>/dev/null | grep sdk@
env | grep -E '^ANTHROPIC_(BASE_URL|API_KEY|AUTH_TOKEN|CUSTOM_HEADERS)=' | sed -E 's/=.*/=<set>/'   # which exist, no values
env | grep -E '^ANTHROPIC_BASE_URL='
BASE=http://localhost:4000 MODEL=<id> LLM_API_KEY_FILE=~/.config/llm/key scripts/check-endpoint.sh   # see the /v1/messages lines
```

Ask only what discovery cannot show: server and URL, which header the server checks (Bearer or `x-api-key`), whether it serves `/v1/messages` at all, and whether the app needs tools, streaming or beta features.

## Decision flow

1. **Does the server serve `/v1/messages`?** The probe's Messages lines say. If not, use `openai-sdk` instead or a gateway that translates. -> `references/server-recipes.md`
2. **Base URL and auth:** `base_url` is the server root without `/v1`; pick `auth_token` (Bearer) or `api_key` (`x-api-key`) to match the server. -> `references/client-config.md`
3. **Model name:** the id the server or gateway exposes, not an Anthropic model id. -> `references/server-recipes.md`
4. **Streaming, tools, thinking, betas, `max_tokens`:** -> `references/messages-tools-streaming.md`
5. **Error:** -> `references/troubleshooting.md`

## Rules

- **Never hardcode or print keys.** Read from `ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_API_KEY` or a `0600` file; do not log headers or `client.api_key`/`client.auth_token`.
- **`base_url` has no `/v1`.** The SDK appends `/v1/messages`; a base ending `/v1` makes `/v1/v1/messages` and a 404. (The Vercel AI SDK Anthropic provider differs: it wants the `/v1`.)
- **Choose one credential.** `auth_token` sends `Authorization: Bearer`, `api_key` sends `x-api-key`; set both and both headers go out. vLLM checks Bearer only, so use `auth_token` there. Some gateways check only one: probe both with `scripts/check-endpoint.sh`.
- **An explicit constructor credential disables env credential lookup** (Python); with no explicit credential the SDK reads `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN`.
- **`max_tokens` is required** on every request.
- **Defaults are generous:** 10-minute timeout, 2 retries. Large non-streaming `max_tokens` can raise a client error before sending; stream long generations.
- **Beta features are opt-in** (`betas` / `anthropic-beta`); non-Anthropic servers often reject them. Leave them off for self-hosted servers unless the server documents support.
- **Other skills:** install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

## Workflows

### Point an app at a self-hosted Messages route

- [ ] Probe with `scripts/check-endpoint.sh`: the `/v1/messages` line is 200 with your key header.
- [ ] Set `base_url` (no `/v1`) and the matching credential option -> `references/client-config.md`.
- [ ] Use a model id from `/v1/models` or the gateway config.
- [ ] Send one message and one streamed message from the app.
- [ ] Add tools only after the probe's tool line passes.

### Add tool calling

- [ ] Server flags set (vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama.cpp `--jinja`) -> `references/server-recipes.md`.
- [ ] Loop: read `tool_use` blocks, run them, reply with `tool_result` blocks in a `user` message, call again -> `references/messages-tools-streaming.md`.

### Debug a failing call

- [ ] Reproduce with curl or the probe using the same header; read the server log.
- [ ] `ANTHROPIC_LOG=debug` (both SDKs) shows the request; redact credentials before sharing.

## Reference index

| File                                     | Read when                                                                       |
| ---------------------------------------- | ------------------------------------------------------------------------------- |
| `references/client-config.md`            | Constructors, env vars, auth header choice, headers, timeouts, retries, proxies |
| `references/messages-tools-streaming.md` | Messages shape, streaming, tools, thinking, betas, `max_tokens`, token counting |
| `references/server-recipes.md`           | vLLM, llama.cpp, Ollama, LiteLLM, llama-swap: URL, auth, model names, flags     |
| `references/troubleshooting.md`          | Symptom to cause to fix                                                         |

Asset: `assets/client.mjs` (Node smoke test). Script: `scripts/check-endpoint.sh` (read-only probe).

## Companion skills

- `openai-sdk`: the same job for OpenAI-compatible clients.
- `litellm`, `llama-swap`: gateways that translate and give stable names and keys.
- `vllm`, `llama-cpp`, `ollama`: engines behind the endpoint.
- `tool-calling-parsers`: when `tool_use` never appears.
- `llm-clients`: choosing and troubleshooting clients of every kind.
