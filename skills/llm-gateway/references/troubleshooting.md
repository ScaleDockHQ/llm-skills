# Troubleshooting

> Verified against LiteLLM v1.105.0 (docs: completion/drop_params, proxy/health, proxy/reliability, response_api), 2026-10-11

## How it plugs into this stack

Always reproduce in two steps: call the backend directly (`curl http://127.0.0.1:8080/v1/models`), then the same request through the gateway on port 4000. The difference localizes the fault.

Most frequent causes in this stack:

- `400` unsupported parameter: set `drop_params: true` or `additional_drop_params`.
- `404` from an `openai/` backend: `api_base` lacks `/v1` or the model ID is wrong.
- `Connection refused` to `127.0.0.1` from Docker: use `host.docker.internal`.
- `No connected db.` or budgets never trigger: Postgres missing, or local models lack explicit zero cost.
- Responses client breaks after the first call: `use_chat_completions_api: true`.
- Chat UI shows wrong context or dates: `/v1/models` is OpenAI-shaped; configure the client (`llm-clients` skill).
- Stored credentials unreadable: `LITELLM_SALT_KEY` changed.

Depth: install the litellm skill (npx skills add ScaleDockHQ/llms-skills --skill litellm)
