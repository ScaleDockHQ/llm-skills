# LiteLLM with Claude Code

> Verified against LiteLLM v1.105.0 (docs: anthropic_unified, tutorials/claude_responses_api, proxy/config_settings) and Claude Code docs (env-vars, llm-gateway-connect, llm-gateway-protocol; Claude Code v2.1.296 is the latest GitHub release), 2026-10-11

Claude Code speaks Anthropic Messages. LiteLLM's unified `/v1/messages` serves it for any provider in `model_list`.

## Client side (names only; values come from your secret store)

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"      # gateway root, no /v1
export ANTHROPIC_AUTH_TOKEN="$LITELLM_VIRTUAL_KEY"     # sent as Bearer; a master key works but gives admin power
export ANTHROPIC_MODEL="claude-coder"                  # a gateway alias
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1    # /model picker lists gateway models
```

- Unified endpoint: base URL is the root. The pass-through variant `http://host:4000/anthropic` forwards to Anthropic unchanged; use it only when every model is a real Anthropic model.
- Discovery calls `GET /v1/models` and keeps IDs containing `claude` or `anthropic`. Name Claude-facing aliases accordingly (`claude-coder`), or choose with `ANTHROPIC_MODEL` / `ANTHROPIC_CUSTOM_MODEL_OPTION`.
- Non-Anthropic upstreams can reject Claude Code's beta headers and fields (`Unexpected value(s)` for `anthropic-beta`, `Extra inputs are not permitted`). Client fix: `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`. Gateway fix: `additional_drop_params` for the offending field.
- OpenAI-family models behind `/v1/messages` use the Responses API by default. For OpenAI-compatible backends without `/v1/responses`, set `litellm_settings.use_chat_completions_url_for_anthropic_messages: true` (env `LITELLM_USE_CHAT_COMPLETIONS_URL_FOR_ANTHROPIC_MESSAGES`).
- Do not buffer SSE anywhere between client and gateway.

## Gateway side

```yaml
model_list:
  - model_name: claude-coder
    litellm_params:
      model: openai/<backend-model-id>
      api_base: http://host.docker.internal:8080/v1
      api_key: "none"
      use_chat_completions_api: true
    model_info:
      {
        mode: chat,
        max_input_tokens: 131072,
        max_output_tokens: 16384,
        supports_function_calling: true,
      }
litellm_settings:
  use_chat_completions_url_for_anthropic_messages: true
```

Give each developer a virtual key with `models: ["claude-coder"]` and a budget (`keys-budgets.md`).

## Verify

```bash
curl -fsS http://127.0.0.1:4000/v1/messages -H "Authorization: Bearer $LITELLM_API_KEY" -H 'anthropic-version: 2023-06-01' \
  -H 'content-type: application/json' -d '{"model":"claude-coder","max_tokens":64,"messages":[{"role":"user","content":"Say ok"}]}' \
  | jq '{type, stop_reason, content: [.content[].type]}'
```

Then run one tool call and one streamed answer. Per-client settings files and other agents: install the `llm-clients` skill (`npx skills add ScaleDockHQ/llm-skills --skill llm-clients`).
