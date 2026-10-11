# LiteLLM in front of Modal

> Verified against LiteLLM v1.105.0 docs (OpenAI-compatible endpoints, vLLM provider, routing and fallbacks) as used by the `litellm` skill, Modal Endpoint integrations and Proxy Tokens docs, modal 1.6.1, 2026-10-11

Gateway install, keys, budgets and exposure live in the `litellm` and `llm-gateway` skills. This is only the Modal entry.

```yaml
model_list:
  - model_name: llm # the name clients send to the gateway
    litellm_params:
      model: hosted_vllm/llm # your own vLLM Server; use openai/<model> for a Modal Endpoint
      api_base: https://<workspace>--<app>-server.<region>.modal.direct/v1
      api_key: os.environ/MODAL_PROXY_TOKEN # "<token id>.<token secret>", built in the shell
      timeout: 600 # cover a cold start
      num_retries: 3
  - model_name: llm-fallback # another provider for interactive traffic; see cloud-llms
    litellm_params:
      model: <provider>/<model>
      api_key: os.environ/<PROVIDER_KEY>

router_settings:
  fallbacks: [{ "llm": ["llm-fallback"] }]
```

- `api_base` must include `/v1`; a missing `/v1` gives "Not Found Error". Read the real URL with `modal server info <app>/<server> --json` or `modal endpoint info <name> --json`, and the served model id from `GET /v1/models`.
- `hosted_vllm/<model>` is LiteLLM's provider for a vLLM server; `openai/<model>` works for any OpenAI-compatible endpoint, including Modal Endpoints.
- Retry on 503 with backoff. Modal request timeouts cannot be customised server-side, so set `timeout` in the client.
- The proxy token is read from the environment of the LiteLLM process; clients of the gateway get LiteLLM virtual keys, never the Modal token.

Check through the gateway:

```bash
curl -sS --max-time 700 http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_KEY" -H "Content-Type: application/json" \
  -d '{"model":"llm","messages":[{"role":"user","content":"Say hi"}],"max_tokens":8}' | jq -r '.choices[0].message.content'
```

`LITELLM_KEY` is a virtual key from the `litellm` skill, read from the environment and never echoed.
