# Clients, SDKs, LiteLLM and agents

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

Kong speaks OpenAI format by default on `llm/v1/chat` routes. The base URL is the Kong proxy plus the Route path you defined. On the OSS recipe in this skill the route path is `/v1/chat/completions` only, so the OpenAI SDK base URL `http://127.0.0.1:8100/v1` works for chat completions; add Routes (and `ai-proxy` instances) for other route types such as embeddings.

## OpenAI SDK, curl, most agents

```bash
export OPENAI_BASE_URL=http://127.0.0.1:8100/v1      # your Kong proxy plus the route base path
export KONG_CLIENT_KEY="$(cat ~/.config/kong/client-key)"  # the Kong consumer key, not the provider key (unset if the route has no inbound auth)
curl -s "$OPENAI_BASE_URL/chat/completions" -H "apikey: $KONG_CLIENT_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"ping"}]}' | jq -r '.choices[0].message.content'
```

- With `key-auth` the key travels in the header named in `config.key_names` (`apikey` by default). An OpenAI SDK sends `Authorization: Bearer <key>`, which `key-auth` does not read as a bare key, so send the key in the configured header (SDK `default_headers`, for example `{"apikey": "..."}`) or use `openid-connect` / a JWT plugin that expects a bearer token. On 2.x the AI Auth Strategy `key_names` decides (the docs example uses `X-API-Key`).
- The `model` field: on 3.x `ai-proxy` the upstream model comes from `config.model.name`; test whether the client's `model` value changes anything on your version before relying on it, and see `model_alias` in the schema. On 2.x the value must be one of `config.route.model.values`.
- AzureOpenAI SDK clients against a Bedrock-mode route can produce `403` signature mismatch because the SDK's `api_version` query parameter breaks the SigV4 signature; use the plain OpenAI client or avoid `api_version` on that route (Kong support article).

## Anthropic format and Claude Code

3.10+ `llm_format: anthropic`, or on 2.x a Model with `formats: [{type: anthropic}]`, `capabilities: [generate]` and a `config.route.paths` base such as `/`, exposes `/messages`. The docs run Claude Code with `ANTHROPIC_BASE_URL=http://localhost:8000/` and `claude --model <model name from route.model.values>`. Keep the provider key in the provider entity; Claude Code needs only the gateway URL (and a Kong consumer key if you added auth).

## LiteLLM

Treat Kong as an OpenAI-compatible upstream:

```yaml
model_list:
  - model_name: kong-chat
    litellm_params:
      model: openai/local # the model name Kong accepts
      api_base: http://127.0.0.1:8100/v1
      api_key: placeholder # unused when Kong reads its key from a custom header
      extra_headers:
        apikey: os.environ/KONG_CLIENT_KEY # confirm LiteLLM resolves env references in extra_headers on your version, else use a bearer-based Kong auth plugin
```

Use this only if you want LiteLLM virtual keys and budgets in front of Kong; Kong alone covers auth, limits and routing. See skill `litellm`.

## Open WebUI, Continue, others

Set the OpenAI-compatible base URL and key as above. Skill `llm-clients` covers tool-specific settings.

## Discover

```bash
curl -s "$OPENAI_BASE_URL/models" -H "apikey: $KONG_CLIENT_KEY" | jq -r '.data[].id' 2>/dev/null | head
curl -s -o /dev/null -w "%{http_code}\n" "$OPENAI_BASE_URL/chat/completions"
```

The 3.x recipe defines only the chat route, so `/models` returns 404 there; that is expected.
