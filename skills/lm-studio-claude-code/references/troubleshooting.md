# Troubleshooting

> Verified against LM Studio 0.4.26 docs and Claude Code docs (llm-gateway-connect troubleshooting table), 2026-10-11

Isolate first: run the `curl` to `/v1/messages` from `recipe.md`. If it works, the problem is on the Claude Code side; if not, it is LM Studio.

| Symptom                                                               | Cause                                                                      | Fix                                                                                                  |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Connection refused` / cannot reach the API                           | LM Studio server not running, wrong port, `/v1` appended to the base       | `lms server status --json --quiet`; base URL must be `http://localhost:1234`                         |
| `401` from LM Studio                                                  | Require Authentication on and token missing or in the wrong variable       | Set `ANTHROPIC_AUTH_TOKEN` (Bearer) or `ANTHROPIC_API_KEY` (`x-api-key`); both accepted by LM Studio |
| Claude Code shows a login screen                                      | No credential variable set; base URL alone is not a credential             | Export `ANTHROPIC_AUTH_TOKEN`; see `claude-code-side.md`                                             |
| Model not found / "issue with the selected model"                     | `--model` value is not a key or identifier LM Studio knows                 | `lms ls`, `lms ps`; use the `--identifier` given at load                                             |
| Local model missing from `/model`                                     | Discovery keeps only ids containing `claude` or `anthropic`                | Use `claude --model <id>` or `ANTHROPIC_MODEL`                                                       |
| Context errors or the agent forgets after a few steps                 | Loaded with a small context (JIT default)                                  | Reload with `--context-length 32768` or more; check `lms load --estimate-only`                       |
| Very slow first turn                                                  | Model loads on first request, or a second model loads for background tasks | Preload with `lms load`; do not pin a second model unless memory allows                              |
| `400` naming `context_management` or `Extra inputs are not permitted` | Endpoint rejects pre-release fields Claude Code sends                      | `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`                                                           |
| Tool calls malformed or ignored                                       | Model weak at tool calling                                                 | Try a model known for tool use; keep tasks small; verify the tools `curl` from the LM Studio docs    |
| Settings `env` value seems ignored                                    | Shell export and settings both set; settings-file value wins               | `/status` shows the effective base URL; edit the right place                                         |
| `/fast` unavailable                                                   | Fast-mode check goes to `api.anthropic.com`                                | Expected; not relevant for a local model                                                             |
| Works on the laptop, not from another machine                         | Server bound to loopback                                                   | Use LM Link or Tailscale; enable Require Authentication before any `--bind`                          |
| Both `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_API_KEY` set               | Auth conflict warning                                                      | Keep one                                                                                             |
