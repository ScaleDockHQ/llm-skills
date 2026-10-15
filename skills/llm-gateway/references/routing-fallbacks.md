# Routing, retries and fallbacks

> Verified against LiteLLM v1.105.0 (docs: routing, proxy/load_balancing, proxy/reliability, proxy/timeout), 2026-10-11

## How it plugs into this stack

- Replicas share one `model_name`; overflow to a cloud alias with `router_settings.fallbacks` and `context_window_fallbacks` (see `assets/litellm-config.yaml`). Keep these keys in `router_settings` only.
- Set `num_retries`, `timeout`, `stream_timeout`, `allowed_fails`, `cooldown_time`; `enable_pre_call_checks: true` enforces `model_info.max_input_tokens`.
- Behind an on-demand swapper (llama-swap) use `num_retries: 0` and timeouts long enough for a cold load.
- Test by stopping one backend on purpose and watching the fallback and cooldown.
- Pitfalls: a single-deployment group is benched after a few errors (`disable_cooldowns` or more replicas); without Redis each instance keeps its own cooldown state.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llm-skills --skill litellm)
