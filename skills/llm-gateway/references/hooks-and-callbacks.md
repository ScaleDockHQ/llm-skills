# Hooks and callbacks

> Verified against LiteLLM v1.105.0 (docs: proxy/logging, proxy/prometheus, proxy/call_hooks, proxy/config_settings), 2026-10-11

## How it plugs into this stack

- Order of preference: config-only behavior, then built-in callbacks by name (`prometheus`, `langfuse_otel` (needs `LITELLM_OTEL_V2=true`, restart the proxy), `otel`), then a custom `CustomLogger` hook mounted into the container.
- Set `litellm_settings.callbacks` and `turn_off_message_logging: true` so callbacks log metadata, not prompts; provider keys for callbacks live in the env file.
- Debug logs (`--detailed_debug`, `LITELLM_LOG=DEBUG`) can contain prompts: enable briefly.
- Pitfalls: a hook that raises on every request takes the gateway down; hook signatures change between releases, so pin the image and retest on upgrade. Dashboards belong to the `llm-observability` skill.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llm-skills --skill litellm)
