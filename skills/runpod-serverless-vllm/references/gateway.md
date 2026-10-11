# LiteLLM in front of the endpoint

> Verified against LiteLLM v1.105.0 docs (OpenAI-compatible endpoints, routing and fallbacks) as used by the `litellm` skill, runpod-workers/worker-vllm v2.29.0, 2026-10-11

Gateway installation, keys, budgets and exposure live in the `litellm` and `llm-gateway` skills. This file is only the Runpod-specific entry.

```yaml
model_list:
  - model_name: llm # the name your clients send to the gateway
    litellm_params:
      model: openai/llm # openai/ + the served name (MODEL_NAME or OPENAI_SERVED_MODEL_NAME_OVERRIDE)
      api_base: https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
      api_key: os.environ/RUNPOD_API_KEY
      timeout: 600 # cold start plus model load
      num_retries: 2
  - model_name: llm-fallback # another provider for interactive traffic; see the cloud-llms skill
    litellm_params:
      model: <provider>/<model>
      api_key: os.environ/<PROVIDER_KEY>

router_settings:
  fallbacks: [{ "llm": ["llm-fallback"] }]
```

- `api_base` ends in `/openai/v1`; LiteLLM appends `/chat/completions`.
- The key comes from the environment of the process that starts LiteLLM; never write it into the YAML.
- Runpod has no dedicated LiteLLM prefix: it is an OpenAI-compatible server. Use `hosted_vllm/` only for load-balancing endpoints that run the stock vLLM server (see `runpod` `litellm-and-clients.md`).
- Interactive clients should not hang through a cold start: keep the fallback, or keep one active worker and accept the idle cost.

Check through the gateway:

```bash
curl -sS --max-time 700 http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_KEY" -H "Content-Type: application/json" \
  -d '{"model":"llm","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq -r '.choices[0].message.content'
```

`LITELLM_KEY` is a virtual key from the `litellm` skill, read from the environment, never echoed.
