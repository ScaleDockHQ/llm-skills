# Models and providers

> Verified against LiteLLM v1.105.0 (docs: proxy/configs, proxy/load_balancing, providers/openai_compatible, providers/anthropic, providers/openrouter, completion/drop_params, completion/provider_specific_params, completion/vision, proxy/model_management, model_prices_and_context_window.json sample_spec), 2026-10-11

## What it is and when to use it

`model_list` is the gateway's registry. Each entry maps a public name (what clients send) to a provider deployment (what LiteLLM calls) plus metadata. Several entries can share one `model_name`; the router load-balances across them.

## Entry anatomy

```yaml
model_list:
  - model_name: coder                    # public alias clients use
    litellm_params:                      # how to call the provider
      model: openai/qwen-coder           # <provider>/<provider-model-id>
      api_base: http://127.0.0.1:8080/v1
      api_key: "none"
      rpm: 60                            # optional, used for weighted routing
      drop_params: true                  # per-deployment param dropping
    model_info:                          # what the model can do
      max_input_tokens: 131072
      max_output_tokens: 16384
      supports_function_calling: true
      supports_vision: false
      supports_reasoning: true
      mode: chat
```

### Provider prefixes you will use most

| Backend | `model` value | Notes |
|---|---|---|
| Any OpenAI-compatible server (llama.cpp, llama-swap, SGLang, LM Studio) | `openai/<served-id>` + `api_base` ending in `/v1` | Requires some `api_key` value even if the backend ignores it |
| vLLM | `hosted_vllm/<served-id>` + `api_base` | Dedicated provider; no fake key needed |
| Ollama | `ollama_chat/<model>` + `api_base: http://host:11434` | Or `openai/` against Ollama's `/v1` |
| OpenAI | `openai/<model>` + `api_key: os.environ/OPENAI_API_KEY` | |
| Anthropic | `anthropic/<model>` + `api_key: os.environ/ANTHROPIC_API_KEY` | |
| OpenRouter | `openrouter/<vendor>/<model>` + `api_key: os.environ/OPENROUTER_API_KEY` | |
| Wildcard | `model_name: "openai/*"`, `model: openai/*` | Exposes every model of a provider; pair with `litellm_settings.check_provider_endpoint: true` for accurate `/v1/models` |

Check the provider page in the LiteLLM docs for exact prefixes of other providers; do not guess.

## Stable names and aliases

- Put the stable name in `model_name` (`coder`, `chat-fast`, `embed`). Clients never see the provider ID.
- `router_settings.model_group_alias` maps extra names onto an existing group, for renames and typos:

```yaml
router_settings:
  model_group_alias:
    old-coder: coder                      # shown in /v1/models
    Coder:
      model: coder
      hidden: true                        # works but not listed
```

- `model_info.discoverable: false` hides a `model_list` entry from `/v1/models` while keeping it callable.
- An alias must not collide with an existing `model_name`.

## model_info

Fields LiteLLM reads come from its model cost map (`model_prices_and_context_window.json`). For hosted models LiteLLM fills them automatically; for local or aliased models you must declare them. Useful keys:

- `max_input_tokens`, `max_output_tokens` (`max_tokens` is legacy).
- `supports_function_calling`, `supports_parallel_function_calling`, `supports_tool_choice`, `supports_vision`, `supports_reasoning`, `supports_response_schema`, `supports_prompt_caching`, `supports_system_messages`.
- `mode`: `chat`, `completion`, `embedding`, `rerank`, `anthropic_messages` and others. Drives health checks.
- Pricing: set `input_cost_per_token: 0` and `output_cost_per_token: 0` in `litellm_params` (not `model_info`) for local models. Both must be explicitly `0`; such models skip budget checks, so they stay callable when a key's budget is exhausted.
- `base_model`: lets LiteLLM look up pricing and limits for a deployment whose name it does not recognise (documented mainly for Azure).
- Health tuning: `health_check_timeout`, `health_check_max_tokens`, `disable_background_health_check`.
- Arbitrary extra keys pass through to `/v1/model/info`.

Important: these fields drive LiteLLM routing, cost, pre-call checks and `/v1/model/info`. The OpenAI-shaped `/v1/models` list only returns `id`, `object`, `created`, `owned_by`. Clients that need context size or capabilities must read them elsewhere (their own config or a model DB). See `troubleshooting.md` and the `llm-clients` skill.

`router_settings.enable_pre_call_checks: true` makes LiteLLM reject or reroute requests that exceed `max_input_tokens` before calling the backend.

## Unsupported parameters

By default LiteLLM raises an error when a request carries an OpenAI param the target does not support.

- `litellm_settings.drop_params: true` (or `LITELLM_DROP_PARAMS=true`) drops unsupported params globally.
- `litellm_params.drop_params: true` does it per deployment.
- `litellm_params.additional_drop_params: ["reasoningSummary", "tools[*].input_examples"]` drops named params, including nested paths, even when LiteLLM thinks they are supported.
- `litellm_params.allowed_openai_params: ["tools"]` forces a param through when LiteLLM wrongly believes it is unsupported.

## Provider-specific parameters and passthrough

- Non-OpenAI params set in `litellm_params` (for example a provider's adapter or tenant field) are forwarded to that provider.
- Clients can send extra fields in the request body; with the OpenAI SDK use `extra_body={...}`. LiteLLM forwards provider-specific fields it does not map.
- Engine-specific sampling fields (for example `top_k`, `min_p`, `repetition_penalty` on llama.cpp or vLLM) reach an `openai/` backend this way. Verify each field against the engine's docs; an engine may ignore unknown fields silently.

## Credentials

- Always `api_key: os.environ/NAME`; never inline keys in YAML that might be committed.
- DB mode: named credentials in the Admin UI (LLM Credentials tab) reuse one provider key across many models; they are encrypted with `LITELLM_SALT_KEY`.

## Known pitfalls

- `api_base` for `openai/` must include `/v1`; LiteLLM appends `/chat/completions`.
- The `openai/` provider uses the OpenAI client, which requires a non-empty `api_key`.
- A `model_name` containing `/` (such as `openai/*`) is matched literally; prefer slash-free aliases for normal models.
- `supports_vision: true` in `model_info` does not make a client send images; clients decide that from their own config.
- Wildcard routes need `health_check_model` set to a concrete model for health probes.

## Official links

- Config reference: https://docs.litellm.ai/docs/proxy/configs
- OpenAI-compatible endpoints: https://docs.litellm.ai/docs/providers/openai_compatible
- Providers index: https://docs.litellm.ai/docs/providers
- Drop params: https://docs.litellm.ai/docs/completion/drop_params
- Provider-specific params: https://docs.litellm.ai/docs/completion/provider_specific_params
- Aliases and hidden models: https://docs.litellm.ai/docs/proxy/load_balancing
- Model discovery: https://docs.litellm.ai/docs/proxy/model_discovery
- Cost map: https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json
