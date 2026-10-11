# OpenRouter with LiteLLM and clients

> Verified against OpenRouter API v1 (docs: cookbook/coding-agents/claude-code-integration, guides/community/*, quickstart) and LiteLLM docs for the OpenRouter provider, 2026-10-11

## LiteLLM

Prefix `openrouter/` and keep the OpenRouter ID after it. Env vars read by LiteLLM: `OPENROUTER_API_KEY`, optional `OPENROUTER_API_BASE` (defaults to `https://openrouter.ai/api/v1`), optional `OR_SITE_URL`, `OR_APP_NAME`. OpenRouter-specific `models`, `route` and `transforms` can be passed as request arguments. Embeddings and image generation and edit are supported through the same prefix.

```yaml
model_list:
  - model_name: coder
    litellm_params:
      model: openrouter/<author>/<slug>
      api_key: os.environ/OPENROUTER_API_KEY
    model_info:
      # fill context and output limits from GET /api/v1/models; do not guess
```

The key stays in the LiteLLM process environment. Per-key budgets and aliases live in LiteLLM (skill `litellm`); OpenRouter's own routing runs behind the alias. If both layers retry, failures multiply: keep LiteLLM `num_retries` low and let OpenRouter's `models` list or provider fallbacks do the failover, or the reverse, but not both.

## OpenAI-compatible clients

```bash
export OPENAI_BASE_URL=https://openrouter.ai/api/v1
export OPENAI_API_KEY="$(cat ~/.config/openrouter/api-key)"   # 0600 file; never echo
```

Use full OpenRouter model IDs (`author/slug`). Pass routing and fallbacks via `extra_body={"provider": {...}, "models": [...]}` in the OpenAI SDK.

## Claude Code

Per OpenRouter's guide, Claude Code speaks its native protocol directly; no local proxy.

```bash
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY=""     # must be explicitly empty to avoid conflicts
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1   # optional model picker
```

Use the full URL with scheme and no `/v1`. The guide warns it is only guaranteed with the Anthropic first-party provider, so set Anthropic 1P as the top `provider.order` priority (for example through a preset). If the key is expanded from a profile, define it before the export line. The guide also notes one newer Claude Code model class is only selectable by setting its `ANTHROPIC_DEFAULT_<CLASS>_MODEL` variable; read the page. Other agents have cookbook pages (Codex CLI, Cursor, OpenCode and others). See `llm-clients` for tool-by-tool settings.

## Smoke test through any path

```bash
curl -fsS "$OPENAI_BASE_URL/chat/completions" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"<author>/<slug>","messages":[{"role":"user","content":"Reply with OK"}],"max_tokens":8}' | jq '{model, usage}'
```
