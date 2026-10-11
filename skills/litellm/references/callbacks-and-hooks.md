# LiteLLM: callbacks and hooks

> Verified against LiteLLM v1.105.0 (docs: proxy/logging, proxy/prometheus, proxy/call_hooks, observability/custom_callback, proxy/config_settings, proxy/debugging), 2026-10-11

## What it is and when to choose it

Callbacks observe traffic (logging, metrics, tracing). Hooks change it (rewrite or reject requests and responses). Order of preference:

1. Config-only behavior: aliases, `model_info`, `drop_params`, `additional_drop_params`, `allowed_openai_params`, fallbacks, key and team settings.
2. Built-in callbacks by name: `langfuse`, `otel`, `prometheus`, `datadog` and many more.
3. Custom Python callback or hook: only when 1 and 2 cannot express it. You then own Python code inside the gateway image, which must be re-tested on every upgrade.

## Built-in callbacks

```yaml
litellm_settings:
  callbacks: ["prometheus", "otel"] # run on success and failure
  # success_callback: ["langfuse"]       # success only
  # failure_callback: ["langfuse"]       # failure only
  turn_off_message_logging: true # log metadata, not prompts or completions
```

- Each integration reads its own env vars (for example Langfuse keys, OpenTelemetry exporter settings). Put them in the env file, never in YAML.
- `prometheus` exposes `GET /metrics` on the proxy port; the Docker image already includes the client library.
- `general_settings.service_callback` reports gateway dependency failures (Redis, Postgres) to the listed services.
- Per request, a client can skip a callback with the header `x-litellm-disable-callbacks: <name>` (Enterprise feature per upstream logging docs).
- Dashboards and trace backends beyond LiteLLM: install the `llm-observability` skill (`npx skills add ScaleDockHQ/llms-skills --skill llm-observability`). See `observability.md` here for the LiteLLM side.

## Debug logging

- `--debug` (INFO) or `--detailed_debug` (DEBUG) on the proxy command, or `LITELLM_LOG=INFO|DEBUG|ERROR`.
- `litellm_settings.json_logs: true` for structured logs.
- Debug logs can contain prompts and headers. Enable briefly, then turn off.

## Custom hooks (last resort)

Hooks are methods on a `CustomLogger` subclass in a Python file mounted into the container, registered by module path:

```yaml
litellm_settings:
  callbacks: custom_callbacks.proxy_handler_instance # file custom_callbacks.py, object proxy_handler_instance
```

| Hook                                                   | Runs                          | Typical use                        |
| ------------------------------------------------------ | ----------------------------- | ---------------------------------- |
| `async_pre_call_hook`                                  | Before the provider call      | Rewrite or reject requests         |
| `async_moderation_hook`                                | In parallel with the call     | Input checks without added latency |
| `async_post_call_success_hook`                         | After a non-streaming success | Rewrite responses                  |
| `async_post_call_streaming_hook` / `..._iterator_hook` | On streaming output           | Stream filters                     |
| `async_post_call_failure_hook`                         | After a failure               | Friendlier client errors           |
| `async_filter_listed_models`                           | On model listing routes       | Hide models per caller             |

Minimal pre-call hook, only if no config option covers the need (adapted from the call hooks doc):

```python
from litellm.integrations.custom_logger import CustomLogger

class Handler(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        data.pop("reasoningSummary", None)   # prefer additional_drop_params for this exact case
        return data

proxy_handler_instance = Handler()
```

Mount the file into the container next to the config (for example `/app/custom_callbacks.py`) and keep it under version control with the config.

## Known pitfalls

- A hook that raises on every request takes the whole gateway down; wrap logic defensively and test with a staging container.
- Hook signatures change between releases; pin the image and re-run tests on upgrade.
- `turn_off_message_logging` affects callbacks; it does not scrub the proxy's own debug logs.
- Logging callbacks add latency only when they block; most built-ins are async, custom ones may not be.

## Official links

- Logging and callbacks: https://docs.litellm.ai/docs/proxy/logging
- Prometheus: https://docs.litellm.ai/docs/proxy/prometheus
- Call hooks: https://docs.litellm.ai/docs/proxy/call_hooks
- Custom callbacks: https://docs.litellm.ai/docs/observability/custom_callback
- Debugging: https://docs.litellm.ai/docs/proxy/debugging
