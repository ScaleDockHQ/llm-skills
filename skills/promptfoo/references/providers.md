# promptfoo: OpenAI-compatible targets

> Verified against promptfoo 0.124.1 (docs: openai provider, vllm provider, llama.cpp provider), 2026-10-11

Any server that speaks the OpenAI API is reached with the built-in OpenAI provider by changing `apiBaseUrl`. The model ID after `openai:chat:` is whatever `GET /v1/models` returns (an alias if the server or gateway maps one).

## Target matrix

| Target                       | `apiBaseUrl` example        | Notes                                                                                                 |
| ---------------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------- |
| vLLM (`vllm serve`)          | `http://localhost:8000/v1`  | Use the served name (`--served-model-name`) as the model ID. Reasoning parser changes output (below). |
| SGLang                       | `http://localhost:30000/v1` | Same provider form. Default port is upstream's; check your launch command.                            |
| llama.cpp `llama-server`     | `http://localhost:8080/v1`  | Chat via `openai:chat:`. The `llama` provider talks to the native `/completion` endpoint instead.     |
| Ollama                       | `http://localhost:11434/v1` | OpenAI-compatible route; promptfoo also has a native `ollama:` provider.                              |
| LiteLLM proxy / llama-swap   | `http://localhost:4000/v1`  | Pass the gateway's model alias unchanged. Key is the gateway key.                                     |
| Cloud OpenAI-compatible APIs | provider's `/v1` root       | Key via `apiKeyEnvar`.                                                                                |

Ports above are common defaults, not promptfoo facts; use the ones your server actually listens on. The `llama` provider reads its address only from env `LLAMA_BASE_URL` (a `config.baseUrl` key is ignored) and sends `n_predict`, `stop` and other native options.

## Auth

- `apiKeyEnvar: NAME`: read the key from that variable. A missing variable fails; it does not fall back to `OPENAI_API_KEY`.
- `apiKeyRequired: false`: for servers without auth.
- `useDefaultApiKey: false`: never fall back to an ambient `OPENAI_API_KEY`. Pair with `apiKeyRequired: false` for open servers.
- `headers:` for extra request headers (for example a gateway tenant header).
- Inline `apiKey:` wins over env vars but stores the secret in the config; the vLLM doc examples use throwaway tokens only.

## Reasoning models

By default promptfoo's OpenAI-compatible chat provider returns reasoning text in the output as `Thinking: <reasoning>` followed by the content, when the server returns `reasoning_content` or `reasoning`. That helps when you want to inspect the model, and breaks `equals`, `starts-with`, JSON checks and every judge.

```yaml
providers:
  - id: openai:chat:qwen3-32b
    label: candidate
    config:
      apiBaseUrl: "{{ env.LLM_BASE_URL }}"
      apiKeyEnvar: LLM_API_KEY
      temperature: 0
      max_tokens: 4096 # reasoning needs headroom; truncation leaves raw <think> in content
      showThinking: false # promptfoo side: drop reasoning fields
      passthrough: # server side: ask the template not to think (Qwen3/GLM-style templates)
        chat_template_kwargs:
          enable_thinking: false
```

- `showThinking: false` only changes what promptfoo reads. The model may still spend tokens thinking; `passthrough` fields reduce that when the server honors them.
- If generation stops before the thinking block closes, vLLM can return raw `<think>...` in `content`; `showThinking: false` cannot strip it. Raise `max_tokens` and the server `--max-model-len`, or disable thinking.
- GPT-OSS-style endpoints use other fields: the vLLM doc shows `passthrough: { include_reasoning: false, reasoning_effort: low }`.
- For baseline versus candidate comparisons, apply the identical thinking settings to both. A model that thinks and one that does not are not a like-for-like comparison.
- Server-side parser setup (`--reasoning-parser`, `--tool-call-parser`) belongs to the `vllm` and `reasoning-models` skills.

## Tool calls and structured output

Tool-call assertions need the server to return OpenAI-style `tool_calls`; confirm with a direct `curl` to the server before blaming the eval. Send extra request fields with `passthrough` (named options do not exist for every server-specific field), for example `response_format` where the server supports it (the OpenAI provider doc says an API field without a named option may need `passthrough`).

## Limits and concurrency

Default concurrency can overload a single local GPU and show up as timeouts that look like model failures. Lower it with `-j 2` (CLI) and bound each call with `PROMPTFOO_EVAL_TIMEOUT_MS` (per call) and `PROMPTFOO_MAX_EVAL_TIME_MS` (whole run); timed-out tests become errors, not failures.

## Smoke check an endpoint before a run

```bash
curl -fsS -H "Authorization: Bearer ${LLM_API_KEY:-none}" "$LLM_BASE_URL/models" | jq -r '.data[].id'
curl -fsS -H "Authorization: Bearer ${LLM_API_KEY:-none}" -H 'Content-Type: application/json' \
  "$LLM_BASE_URL/chat/completions" \
  -d '{"model":"<model-id>","messages":[{"role":"user","content":"Say OK"}],"max_tokens":8,"temperature":0}' \
  | jq '.choices[0] | {finish_reason, content: .message.content}'
```

Official sources: https://www.promptfoo.dev/docs/providers/openai/, https://www.promptfoo.dev/docs/providers/vllm/, https://www.promptfoo.dev/docs/providers/llama.cpp/
