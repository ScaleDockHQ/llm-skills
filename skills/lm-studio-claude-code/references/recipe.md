# Recipe: Claude Code on LM Studio

> Verified against LM Studio 0.4.26 (docs: integrations/claude-code, developer/anthropic-compat/messages) and Claude Code docs (llm-gateway-connect), npm latest 2.1.296, 2026-10-11

## 1. Serve a model

```bash
lms get openai/gpt-oss-20b                       # downloads; append @q4_k_m style quants, --mlx or --gguf to filter
lms load openai/gpt-oss-20b --context-length 32768 --gpu max --identifier openai/gpt-oss-20b --estimate-only   # check memory first
lms load openai/gpt-oss-20b --context-length 32768 --gpu max --identifier openai/gpt-oss-20b
lms server start --port 1234                     # loopback by default
```

`gpt-oss-20b` is the upstream docs' example; any model you have that handles tool calls well is a candidate. Use more than about 25k tokens of context.

## 2. Verify the Messages endpoint

```bash
curl -s http://localhost:1234/v1/messages -H 'Content-Type: application/json' -H "x-api-key: ${LM_API_TOKEN:-lmstudio}" \
  -d '{"model":"openai/gpt-oss-20b","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}' | jq -r '.content[0].text'
```

With Require Authentication off the header is optional. A reply here means LM Studio is fine; failures after this are on the Claude Code side.

## 3. Point Claude Code at it

```bash
export ANTHROPIC_BASE_URL=http://localhost:1234          # root, not /v1
export ANTHROPIC_AUTH_TOKEN=lmstudio                      # any string when auth is off
export CLAUDE_CODE_ATTRIBUTION_HEADER=0                   # upstream LM Studio recommendation
claude --model openai/gpt-oss-20b
```

With authentication on, read the token from a `0600` file (never echo it):

```bash
export LM_API_TOKEN="$(cat ~/.config/lmstudio/token)"
export ANTHROPIC_AUTH_TOKEN="$LM_API_TOKEN"
```

Inside Claude Code run `/status`: the `Anthropic base URL` line should show `http://localhost:1234` and an `Auth token` line naming `ANTHROPIC_AUTH_TOKEN`. Then ask for a small read-only task that uses a tool (list files) to confirm tool calling.

## 4. Make it persistent (optional, with approval)

Shell profile exports apply to new terminals. A settings-file `env` block applies everywhere Claude Code runs, including background sessions; put it in `~/.claude/settings.json`, never in a project's committed `.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:1234",
    "ANTHROPIC_AUTH_TOKEN": "lmstudio",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0"
  }
}
```

When both a shell export and the settings `env` set a variable, the settings-file value applies.

## 5. Remote model

On a stronger machine run LM Studio there and connect with LM Link so the laptop keeps `localhost:1234` (see `lm-studio`, `combos/lm-link.md`). The Claude Code side stays unchanged.
