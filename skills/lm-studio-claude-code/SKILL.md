---
name: lm-studio-claude-code
description: Run Claude Code against a local model served by LM Studio over its Anthropic-compatible /v1/messages endpoint (ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, lms server start, claude --model). Use for coding agents on local GGUF or MLX models, context length for Claude Code, LM Studio auth tokens, LM Link rigs, "model not found", 401, slow first turn. Not a vendor-supported setup for non-Claude models.
license: MIT
compatibility: LM Studio 0.4.1+ (macOS 14+ Apple Silicon, Windows, Linux) with the lms CLI, Claude Code CLI, curl and jq. Installs, server start, network exposure, tokens, shell profile and settings edits need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LM Studio with Claude Code

Point the `claude` CLI at a model served locally by LM Studio, with a context length large enough for agent work, a verified request path, and clear limits on what the vendors support.

**Scope:** this combination. LM Studio depth (install, serving, tuning, LM Link) belongs to `lm-studio`; Claude Code itself is not yet a published skill here, so for its settings, permissions and hooks install later: `npx skills add ScaleDockHQ/llms-skills --skill claude-code` once it exists; sizing the machine belongs to `apple-silicon` or `choosing-hardware`; a multi-backend gateway belongs to `litellm`.

Work through the steps in order. Load a reference only when a step names it. Facts were read from lmstudio.ai/docs (Claude Code integration, Messages endpoint) and code.claude.com/docs (LLM gateway pages, model configuration) on 2026-10-11; Claude Code npm `latest` was 2.1.296 and `stable` 2.1.287 that day.

## Support statement

Anthropic's gateway documentation states that Anthropic "doesn't support routing Claude Code to non-Claude models through any gateway" and does not endorse third-party gateway products. LM Studio documents this Claude Code setup itself. Treat it as a community setup: quality, tool calling and context handling depend on the local model, and Claude Code releases can change what it sends.

## Discover first

Read-only; nothing here prints secrets.

```bash
command -v lms claude && claude --version 2>/dev/null          # CLIs present?
lms server status --json --quiet                                # {"running":true,"port":1234} or not running
lms ls | head -20; lms ps                                       # downloaded and loaded models
curl -s http://localhost:1234/v1/models | jq -r '.data[].id' | head    # add the token header if auth is on
env | grep -E '^(ANTHROPIC|CLAUDE_CODE)_' | sed -E 's/(TOKEN|KEY)=.*/\1=<set>/'   # existing Claude Code settings, secrets masked
sysctl -n hw.memsize 2>/dev/null; free -h 2>/dev/null | head -2 # memory for model + context
```

## Decision flow

1. LM Studio not serving: install and start it first (`lm-studio`). `references/recipe.md`.
2. Pick a tool-capable model and load it with a context of more than about 25k tokens (upstream tip); check memory with `lms load --estimate-only`. `references/lm-studio-side.md`.
3. Set `ANTHROPIC_BASE_URL` (server root, not `/v1`), a token, and `CLAUDE_CODE_ATTRIBUTION_HEADER=0`, then `claude --model <identifier>`. `references/claude-code-side.md`.
4. Verify the Messages endpoint with `curl` before blaming either tool. `references/recipe.md`.
5. Model on another machine: LM Link keeps `localhost:1234` on the laptop (`lm-studio`, `references/lm-studio-side.md`).
6. Failing: `references/troubleshooting.md`. Updating either side: `references/updating.md`.

## Rules

- **Ask before changing the system.** Starting a server, editing a shell profile or `~/.claude/settings.json`, enabling LM Studio authentication, and binding beyond loopback need approval.
- **Base URL is the root.** `ANTHROPIC_BASE_URL=http://localhost:1234`, not `.../v1`.
- **Set one credential variable.** `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY`, not both. A gateway credential variable takes precedence over a saved claude.ai login.
- **Secrets stay out of output and files in the repo.** Tokens live in a `0600` file or the environment; never in a project's committed `.claude/settings.json`.
- **Model name must match LM Studio.** Use the identifier from `lms ls` or `lms ps`; a typo only fails on the first request.
- **Preload the model with the right context.** JIT loading uses default load settings, often a small context.
- **Loopback unless authenticated.** Turn on Require Authentication before any `--bind` or CORS change.
- **Verify upstream.** Re-read both vendors' docs before relying on a flag; Claude Code ships often.

## Build the stack

- [ ] LM Studio serving on loopback with the model loaded at a large context -> `references/lm-studio-side.md`
- [ ] Claude Code environment set (base URL, token, attribution header, model) -> `references/claude-code-side.md`
- [ ] `curl` to `/v1/messages` returns text -> `references/recipe.md`
- [ ] `claude --model <identifier>` answers; `/status` shows the base URL; a tool-using task works -> `references/recipe.md`
- [ ] Verify: the first response arrives, context is not exceeded after a few tool calls, and `lms ps` shows only the intended model resident.

## Reference index

- `references/recipe.md`: end-to-end commands and verification.
- `references/lm-studio-side.md`: model, context, load and server settings, auth, LM Link.
- `references/claude-code-side.md`: environment variables, settings file, picker, background traffic, support limits.
- `references/troubleshooting.md`: symptom to fix.
- `references/updating.md`: updating LM Studio, runtimes and Claude Code.

## Companion skills

- `lm-studio`: install, serve, tune, auth, LM Link. Install: `npx skills add ScaleDockHQ/llms-skills --skill lm-studio`.
- `apple-silicon`: memory sizing and wired limit on a Mac. Install: `npx skills add ScaleDockHQ/llms-skills --skill apple-silicon`.
- `litellm`: one endpoint in front of several backends. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `claude-code`: not yet published; install later with `npx skills add ScaleDockHQ/llms-skills --skill claude-code` once it is listed.
