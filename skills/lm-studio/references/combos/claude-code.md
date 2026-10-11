# LM Studio with Claude Code

> Verified against LM Studio 0.4.26 (Anthropic-compatible `POST /v1/messages`, added in 0.4.1) and lmstudio.ai/docs/integrations/claude-code, 2026-10-11

Claude Code CLI version not checked.

Claude Code speaks the Anthropic Messages API; LM Studio serves it at the server root, so no gateway is needed.

## Steps

```bash
lms get openai/gpt-oss-20b
lms load openai/gpt-oss-20b --context-length 32768 --gpu max --identifier openai/gpt-oss-20b
lms server start --port 1234

export ANTHROPIC_BASE_URL=http://localhost:1234      # root, not /v1
export ANTHROPIC_AUTH_TOKEN=lmstudio                  # any string when auth is off
export CLAUDE_CODE_ATTRIBUTION_HEADER=0               # upstream's recommended setting
claude --model openai/gpt-oss-20b
```

With **Require Authentication** on, use a real token from a `0600` file; both `x-api-key` and Bearer are accepted:

```bash
export LM_API_TOKEN="$(cat ~/.config/lmstudio/token)"
export ANTHROPIC_AUTH_TOKEN="$LM_API_TOKEN"
```

## Pitfalls

- **Context:** use a model and load settings with more than about 25k tokens of context (upstream tip); Claude Code fills it quickly. Check with `lms load --estimate-only`.
- **Model name:** the `--model` value must be a model key or identifier LM Studio knows (`lms ls`). JIT loading will load it on first request if enabled, using default load settings, which may have a small context: preload with `lms load` instead.
- **Tools:** the Messages endpoint supports `tools` and `tool_choice`; quality of tool calling depends on the model.
- **Remote rig:** run the model on a stronger machine and keep `localhost:1234` on the laptop with LM Link (`combos/lm-link.md`).
- Set `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY`, not both.

## Verify

```bash
curl -s http://localhost:1234/v1/messages -H 'Content-Type: application/json' -H "x-api-key: ${LM_API_TOKEN:-lmstudio}" \
  -d '{"model":"openai/gpt-oss-20b","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}' | jq -r '.content[0].text'
```

## Official links

- https://lmstudio.ai/docs/integrations/claude-code
- https://lmstudio.ai/docs/developer/anthropic-compat
