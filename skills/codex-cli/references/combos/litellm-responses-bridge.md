# Codex CLI with LiteLLM in front of chat-only engines

> Verified against Codex CLI rust-v0.162.1 and LiteLLM v1.105.0 (docs: response_api, proxy/config_settings, tutorials/claude_responses_api), 2026-10-11

Use when the engine has no `/v1/responses`, when several engines sit behind one key, or when you want budgets and logs. Gateway install, keys and Postgres are the `litellm` skill.

## Gateway side (summary)

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openai/qwen3-coder # the engine's served name
      api_base: http://127.0.0.1:8080/v1 # vLLM, llama-server, llama-swap, Ollama /v1
      api_key: os.environ/ENGINE_API_KEY
      use_chat_completions_api: true # bridge /v1/responses to /v1/chat/completions
litellm_settings:
  drop_params: true # drop Responses fields the backend lacks
```

An `openai/` deployment with a custom `api_base` is assumed to implement Responses and is forwarded as-is. Without `use_chat_completions_api: true`, an engine without `/v1/responses` fails. For providers that lack Responses natively (Anthropic, Gemini and many others), LiteLLM bridges automatically.

## Codex side

```toml
# ~/.codex/local.config.toml  (use: codex --profile local)
model = "coder"
model_provider = "litellm"
model_context_window = 131072
model_auto_compact_token_limit = 110000
model_reasoning_summary = "none"

[model_providers.litellm]
name = "LiteLLM"
base_url = "http://GATEWAY:4000/v1"
env_key = "LITELLM_API_KEY"
wire_api = "responses"
stream_idle_timeout_ms = 600000
```

Put the provider table in `~/.codex/config.toml` or in the profile file; both are user-level files. A project `.codex/config.toml` is ignored for providers.

```bash
export LITELLM_API_KEY="$(cat ~/.config/llm/litellm-key)"
CODEX_BASE_URL=http://GATEWAY:4000/v1 CODEX_MODEL=coder scripts/check-endpoint.sh
```

## Pitfalls

- Tool calls pass through two translations (Responses, chat completions); a model or parser that is shaky on tools gets worse. Test a multi-file edit.
- Reasoning summaries are not meaningful for chat backends; keep `model_reasoning_summary = "none"`.
- Do not let LiteLLM or a reverse proxy buffer SSE.
- Virtual keys give per-developer attribution and revocation; keep each in a `0600` file or secret manager.
