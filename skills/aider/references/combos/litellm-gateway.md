# Aider with LiteLLM in front of local engines

> Verified against Aider v0.86.0 and LiteLLM v1.105.0 (docs: llms/openai-compat, config/adv-model-settings; proxy config), 2026-10-11

Use when you want one key and URL for several engines, budgets and logs. Gateway install, keys and Postgres belong to the `litellm` skill.

## Gateway side (summary)

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openai/qwen3-coder
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/ENGINE_API_KEY
  - model_name: small
    litellm_params:
      model: openai/qwen3-small
      api_base: http://127.0.0.1:8081/v1
litellm_settings:
  drop_params: true # drop parameters a backend does not support
```

## Aider side

```bash
export OPENAI_API_BASE=http://GATEWAY:4000/v1
export OPENAI_API_KEY="$(cat ~/.config/llm/litellm-key)"   # virtual key
aider --model openai/coder --weak-model openai/small
```

Aider adds its own `openai/` prefix, so the gateway receives model `coder`. Register `openai/coder` and `openai/small` in `.aider.model.metadata.json` and, if the small model garbles diffs, give it `edit_format: whole` in `.aider.model.settings.yml` (templates: `templates/`).

## Pitfalls

- Use the gateway alias, not the backend name.
- Keep `drop_params: true` so reasoning or temperature settings rejected by a backend do not fail the call.
- Raise `--timeout` for cold model loads behind the gateway; keep the proxy from buffering SSE.
- One virtual key per developer for attribution and revocation, stored in a `0600` file or secret manager.
