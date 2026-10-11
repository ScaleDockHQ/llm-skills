# Claude Code with LiteLLM in front of local engines

> Verified against Claude Code v2.1.296 and LiteLLM v1.105.0 (docs: llm-gateway-protocol, anthropic_unified), 2026-10-11

Use when the engine has no `/v1/messages`, when several engines or models should sit behind one key, or when you want budgets, fallbacks and logging. Gateway setup, keys and Postgres are the `litellm` skill; this file is the Claude Code side.

## Gateway side (summary)

```yaml
model_list:
  - model_name: claude-local-coder # contains "claude": shows up in /model discovery
    litellm_params:
      model: openai/qwen3-coder # engine's served model name
      api_base: http://127.0.0.1:8080/v1 # vLLM, llama-server, llama-swap, Ollama /v1
      api_key: os.environ/ENGINE_API_KEY # reference, never a literal
litellm_settings:
  use_chat_completions_url_for_anthropic_messages: true # engine has no /v1/responses
  drop_params: true
```

- For OpenAI-family models behind `/v1/messages`, LiteLLM calls the Responses API by default; the setting above switches to chat completions, required for engines without `/v1/responses`.
- Name aliases with `claude` or `anthropic` in them if you want discovery to list them.
- Virtual keys per developer give per-user attribution and revocation.

## Client side

```bash
export ANTHROPIC_BASE_URL="http://GATEWAY:4000"          # root, no /v1
export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/llm/litellm-key)"   # Bearer; x-api-key also accepted by LiteLLM
export ANTHROPIC_MODEL="claude-local-coder"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-local-small"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072             # alias has no known window
scripts/check-endpoint.sh
```

Pitfalls seen in the docs of both products:

- An alias that contains `claude` is not necessarily resolved to a known Claude model, but an ID containing a real Claude model name (for example `anthropic/claude-opus-4-8`) is, which changes how the window variable applies. Use a plainly local suffix such as `claude-local-coder`.
- Betas and extra fields reach an upstream that rejects them: `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` on the client, or `additional_drop_params` in LiteLLM for specific fields.
- Do not let LiteLLM or a reverse proxy rewrite upstream error bodies; Claude Code's retry and compact logic matches on wording.
- SSE must not be buffered, and `ping` events must pass.
