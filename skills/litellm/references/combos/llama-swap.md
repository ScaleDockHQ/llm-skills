# LiteLLM with llama-swap

> Verified against LiteLLM v1.105.0 and llama-swap v263 (README: OpenAI and Anthropic compatible endpoints, default listen `0.0.0.0:8080`), 2026-10-11

llama-swap hot-swaps local model servers behind one OpenAI/Anthropic-compatible port. LiteLLM sits in front as the authenticated public entry point: virtual keys, stable aliases, Messages/Responses bridging, `model_info`, param dropping. For llama-swap's own config install the `llama-swap` skill (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).

## Wiring

```yaml
model_list:
  - model_name: qwen-coder # public name
    litellm_params:
      model: openai/qwen-coder # openai/<llama-swap model ID, as /v1/models lists it>
      api_base: http://127.0.0.1:8080/v1 # host networking; from a container use host.docker.internal
      api_key: "none"
      use_chat_completions_api: true # bridge /v1/responses to chat completions
      timeout: 600 # cold swaps are slow
      stream_timeout: 300
      input_cost_per_token: 0
      output_cost_per_token: 0
    model_info:
      mode: chat
      max_input_tokens: 65536
      supports_function_calling: true
router_settings:
  model_group_alias:
    coder: qwen-coder
  num_retries: 0
litellm_settings:
  drop_params: true
```

## Rules that matter behind a swapper

- `use_chat_completions_api: true` on every chat entry. Without it LiteLLM forwards `/v1/responses` to the backend's own route; a backend without that route returned errors that corrupted pooled keep-alive connections (details in `api-bridging.md`).
- `num_retries: 0`. A retry during a cold swap queues a second model load.
- Timeouts long enough for a cold load, else the first request after idle fails (and may trigger a fallback).
- Never use authenticated `GET /health` or `background_health_checks: true` as a probe: they send a request to every deployment, so llama-swap loads each model in turn. Probe `/health/liveliness`; limit background checks with `background_health_check_model_groups` to always-loaded models.
- Engine-specific fields: LiteLLM forwards provider-specific params in `litellm_params`, but a nested `extra_body` key in `litellm_params` is not documented (unverified). Set engine fields such as `chat_template_kwargs` in llama-swap filters instead.
- LiteLLM's `/v1/models` has a placeholder `created` and no context size; clients that need them must read `/v1/model/info` or their own config.

## Verify

```bash
curl -fsS http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
curl -fsS http://127.0.0.1:4000/v1/responses -H "Authorization: Bearer $LITELLM_API_KEY" -H 'content-type: application/json' \
  -d '{"model":"coder","input":"Say ok"}' | jq '{status, output: [.output[].type]}'
```

Send two requests on one connection (for example `curl` with two URLs) to prove the bridge: the second must not break.
