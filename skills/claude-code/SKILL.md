---
name: claude-code
description: Claude Code, Anthropic's terminal coding agent, pointed at self-hosted or gateway models over the Anthropic Messages API. Use to install or update `claude`, set ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN or apiKeyHelper for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, map model slots, fix 401, 404 /v1/v1/messages, Extra inputs are not permitted, adaptive thinking, context errors, login loops. Not for Codex, OpenCode, Aider.
license: MIT
compatibility: Needs bash, curl and jq for the check script, and an endpoint that serves POST /v1/messages. Installs, updates, settings files and exposing a gateway need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Claude Code

Run `claude` against your own endpoint (vLLM, llama.cpp, Ollama, a LiteLLM or llama-swap gateway) with the right base URL, credential, model mapping and compatibility switches, then verify with one request before trusting a session.

**Scope:** the Claude Code CLI and its shared settings (VS Code and JetBrains integrations read the same files). Gateways and engines belong to their own skills. Anthropic does not support routing Claude Code to non-Claude models through any gateway, so say so and test edits, not just chat.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print the credential; print variable names and booleans only.

```bash
command -v claude && claude --version
claude doctor 2>&1 | head -40            # install health, settings validation, no session started
env | grep -E '^(ANTHROPIC|CLAUDE_CODE|API_TIMEOUT)' | sed -E 's/=.*/=<set>/'
for f in ~/.claude/settings.json .claude/settings.json .claude/settings.local.json; do
  [ -f "$f" ] && echo "$f: env keys: $(jq -r '(.env // {}) | keys | join(",")' "$f")"
done
```

Inside a session, `/status` shows `Anthropic base URL` and which credential is active (`Auth token`, `API key`, `apiKeyHelper` or a claude.ai login).

## Decision flow

1. **Endpoint serves `/v1/messages` natively** (vLLM, llama.cpp, Ollama, llama-swap, LiteLLM): point `ANTHROPIC_BASE_URL` at it directly. -> `references/custom-endpoints.md`
2. **Engine is chat-completions only:** put LiteLLM in front; it bridges `/v1/messages`. Use the `litellm` skill, then `references/combos/litellm-gateway.md`.
3. **Which model names and limits:** slots, aliases, discovery, context window. -> `references/models-and-limits.md`
4. **Tool calls, thinking, betas, streaming misbehave:** -> `references/compatibility.md`
5. **Install or update:** -> `references/install-and-update.md`
6. **Error text or login screen:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, writing `~/.claude/settings.json`, exporting variables in a shell profile and exposing a gateway need approval and an undo path (back up the file first).
- **Secrets never touch output or git.** The credential lives in an env var, a `0600` file or `apiKeyHelper`. Never put it in the committed `.claude/settings.json`; `.claude/settings.local.json` only if gitignored.
- **Base URL is the root.** No `/v1` suffix: Claude Code appends `/v1/messages`.
- **Set one credential variable.** `ANTHROPIC_AUTH_TOKEN` sends `Authorization: Bearer`, `ANTHROPIC_API_KEY` sends `x-api-key`, `apiKeyHelper` sends both. Pick the header the endpoint checks. Without a gateway credential a saved claude.ai login stays active.
- **Declare what Claude Code cannot know.** For an alias it cannot resolve to a Claude model, set `CLAUDE_CODE_MAX_CONTEXT_TOKENS` and `CLAUDE_CODE_MAX_OUTPUT_TOKENS` to the backend's real limits.
- **Test the endpoint first.** `scripts/check-endpoint.sh` before blaming Claude Code; its failure is the endpoint's, not the agent's.
- **Verify upstream.** Versions, variables and defaults come from code.claude.com docs read on the writing date; re-check after a Claude Code upgrade.

## Workflows

### Connect to a self-hosted endpoint

- [ ] Run discovery; note any existing `ANTHROPIC_*` values and claude.ai login.
- [ ] Export base URL, credential and model alias in the shell (not a file yet).
- [ ] `scripts/check-endpoint.sh` passes models, plain, stream and tool-call probes.
- [ ] Start `claude`, run `/status`, send one prompt that edits a scratch file.
- [ ] Persist: `env` block of `~/.claude/settings.json` (template `templates/settings.json`) or a `0600` env file (`templates/claude-code.env.example`).

### Non-Claude backend misbehaves

- [ ] `400 Extra inputs`, `thinking`, `adaptive`, tool schema errors: `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`, then `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` or fix the upstream. -> `references/compatibility.md`
- [ ] Context overflow: set window and output variables; `/compact` to recover. -> `references/models-and-limits.md`

## Reference index

| File                                   | Read when                                                              |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `references/custom-endpoints.md`       | Base URL, auth, per-engine setup (vLLM, llama.cpp, Ollama, llama-swap) |
| `references/models-and-limits.md`      | Slots, aliases, `/model` discovery, window and output limits           |
| `references/compatibility.md`          | Betas, thinking, tools, streaming, caching, count_tokens               |
| `references/install-and-update.md`     | Install paths, channels, pinning, doctor                               |
| `references/troubleshooting.md`        | Symptom to cause to fix                                                |
| `references/combos/litellm-gateway.md` | LiteLLM in front of local engines for Claude Code                      |

Templates: `templates/claude-code.env.example`, `templates/settings.json`. Script: `scripts/check-endpoint.sh` (probes an Anthropic-format endpoint, prints status codes only).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `litellm`: the gateway that bridges `/v1/messages` to chat-only engines.
- `llm-gateway`: whether to use a gateway and which one.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints Claude Code talks to.
- `tool-calling-parsers`: make tool calls parse on the engine side.
- `llm-clients`: other clients (IDEs, chat UIs, SDKs).
