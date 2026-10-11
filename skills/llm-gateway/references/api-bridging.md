# API bridging: /v1/messages and /v1/responses

> Verified against LiteLLM v1.105.0 (docs: anthropic_unified, response_api, proxy/config_settings, tutorials/claude_responses_api) and Claude Code gateway docs (llm-gateway-connect, llm-gateway-protocol), Codex config reference, 2026-10-11

## What it is and when you need it

Clients speak one of three wire formats; most self-hosted engines speak only the first:

| Format | Endpoint | Typical clients |
|---|---|---|
| OpenAI Chat Completions | `/v1/chat/completions` | Most IDE extensions, chat UIs, OpenAI-compatible SDK providers, Aider |
| OpenAI Responses | `/v1/responses` | Codex CLI (Responses is its only wire API), OpenAI Agents SDK, Vercel AI SDK `openai(...)` default, Kilo "OpenAI Responses" providers |
| Anthropic Messages | `/v1/messages` (+ optional `/v1/messages/count_tokens`) | Claude Code, Claude Agent SDK, Anthropic SDKs, Kilo "Anthropic Messages" providers |

LiteLLM exposes all three on port 4000 and translates to whatever the deployment behind the alias speaks. Bridging is the main reason to put a gateway in front of a single local engine.

## Anthropic Messages clients

- Unified endpoint: `POST /v1/messages` accepts Anthropic-format requests for any provider in `model_list` (OpenAI, local, Bedrock, Agent Platform (Vertex AI), Gemini). Streaming, fallbacks, load balancing, cost tracking work.
- Passthrough endpoint: `/anthropic/...` forwards to Anthropic unchanged. Use only when every model is a real Anthropic model and you need byte-exact behavior.
- Clients set the base URL to the gateway root, not `/v1`: Claude Code `ANTHROPIC_BASE_URL=http://127.0.0.1:4000` with `ANTHROPIC_AUTH_TOKEN=<virtual key>` (Bearer) or `ANTHROPIC_API_KEY` (`x-api-key`). LiteLLM accepts both headers.
- OpenAI-family models behind `/v1/messages` are called through the OpenAI Responses API by default. Set `litellm_settings.use_chat_completions_url_for_anthropic_messages: true` (env `LITELLM_USE_CHAT_COMPLETIONS_URL_FOR_ANTHROPIC_MESSAGES`) to use chat completions instead, needed when the OpenAI-compatible backend has no `/v1/responses`.
- Claude Code model discovery (`CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`) calls `GET /v1/models?limit=1000` and keeps only IDs containing `claude` or `anthropic`. Name Claude-facing aliases accordingly (for example `claude-coder`) or let users pick via `ANTHROPIC_MODEL` / `ANTHROPIC_CUSTOM_MODEL_OPTION`.
- Claude Code sends Anthropic beta headers and fields. Upstreams that are not Anthropic (Bedrock, local engines) can reject them; clients fix that with `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`, the gateway with `additional_drop_params` for specific fields.
- Do not buffer SSE between Claude Code and the gateway (reverse proxies included). Claude Code expects the full event sequence through `message_stop` and aborts on long silent gaps.

Smoke test (key read from env, response trimmed):

```bash
curl -fsS http://127.0.0.1:4000/v1/messages \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H 'anthropic-version: 2023-06-01' -H 'content-type: application/json' \
  -d '{"model":"claude-coder","max_tokens":64,"messages":[{"role":"user","content":"Say ok"}]}' | jq '{type, stop_reason, content: [.content[].type]}'
```

## OpenAI Responses clients

- `POST /v1/responses` is native for providers that implement Responses (OpenAI, Azure OpenAI, and some others).
- For providers without Responses (Anthropic, Gemini, many others), LiteLLM bridges `/v1/responses` to its chat-completions path automatically.
- Exception that bites self-hosters: an `openai/` deployment with a custom `api_base` is assumed to implement Responses, so LiteLLM forwards `/v1/responses` straight to it. A llama.cpp, llama-swap, vLLM or LM Studio backend without `/v1/responses` then fails. Force the bridge per deployment:

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openai/qwen-coder
      api_base: http://127.0.0.1:8080/v1
      api_key: "none"
      use_chat_completions_api: true      # /v1/responses -> backend /v1/chat/completions
```

  Equivalent: `model: openai/chat_completions/qwen-coder`.
- Stateful Responses features (`previous_response_id`, background mode, compaction) need care across replicas; see `model_group_affinity_config` (`deployment_affinity`, `session_affinity`, `responses_api_deployment_check`) in the Responses docs.

Smoke test:

```bash
curl -fsS http://127.0.0.1:4000/v1/responses \
  -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"coder","input":"Say ok"}' | jq '{status, output: [.output[].type]}'
```

## Field lesson: an unsupported route that poisoned the connection pool

Symptom: a Responses client (Codex-style) worked for the first call, then intermittently failed with truncated responses, parse errors or resets on later calls, even for plain chat. Cause: the alias pointed at an `openai/` backend without `/v1/responses`. LiteLLM forwarded the Responses call to a route the backend did not implement, and the keep-alive connections it reused afterwards were left in a bad state (the exact mechanism depends on the backend's HTTP server; the observed effect was corrupted follow-up requests on pooled connections). Fix: `use_chat_completions_api: true` on the deployment, so Responses calls become chat-completions calls the backend actually serves. The general rule: never let a client hit a route the backend does not implement; bridge at the gateway.

## Testing checklist per alias

- [ ] Chat completions: plain and streaming.
- [ ] Responses: plain and streaming, if any client uses it.
- [ ] Messages: plain and streaming, if any Anthropic client uses it.
- [ ] One tool call per path: model returns a tool call, client sends the tool result, model answers.
- [ ] Image input on vision aliases.

## Known pitfalls

- Base URL mistakes: OpenAI clients want `http://host:4000/v1` (or the root, depending on the client); Anthropic clients want the root without `/v1`.
- Reasoning fields differ per format (`reasoning_content`, thinking blocks, Responses reasoning items). Some are lost in translation; test what your clients display.
- Clients that send params a backend rejects (`reasoningSummary`, `tools[*].input_examples`) need `additional_drop_params`.
- Token counting (`/v1/messages/count_tokens`) is optional for Claude Code; without it the client estimates locally.

## Official links

- LiteLLM /v1/messages: https://docs.litellm.ai/docs/anthropic_unified
- LiteLLM /responses and the chat bridge: https://docs.litellm.ai/docs/response_api
- LiteLLM with Claude Code: https://docs.litellm.ai/docs/tutorials/claude_responses_api
- Claude Code gateway protocol: https://code.claude.com/docs/en/llm-gateway-protocol
- Codex custom providers: https://developers.openai.com/codex/config-reference
