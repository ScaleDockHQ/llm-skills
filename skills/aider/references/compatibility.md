# Aider: compatibility with self-hosted backends

> Verified against Aider v0.86.0 (docs: more/edit-formats, usage/modes, config/reasoning, troubleshooting), 2026-10-11

## Why aider is forgiving

Aider has the model write edits as text in a defined edit format and parses them itself; the docs describe the formats as text protocols (`whole` files, `diff` search/replace blocks, `udiff`). So it does not depend on the backend's structured tool-calling parser the way Claude Code, Codex and OpenCode do. That makes it a good fit for small or lightly served models. The costs are format discipline by the model and larger token use for `whole`.

## Edit formats

| Format                        | What the model returns                            | Use                                                                   |
| ----------------------------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| `whole`                       | Entire updated files                              | Weak models; small files; costly in tokens.                           |
| `diff`                        | Search/replace blocks                             | Strong coders; default for many popular models.                       |
| `diff-fenced`                 | Search/replace with the filename inside the fence | Models that mishandle the filename position (Gemini family per docs). |
| `udiff`                       | Unified diff                                      | Reduces "lazy" elision in some models.                                |
| `editor-diff`, `editor-whole` | Same, with a simpler prompt                       | The editor role in architect mode.                                    |

Set with `--edit-format`, `AIDER_EDIT_FORMAT` or model settings. Aider prints the active format in its startup banner. If edits fail to apply ("did not match any lines", empty edits), switch to `whole` for that model before debugging anything else.

## Modes

`/code` (default edit), `/ask` (no edits), `/architect` (a reasoning model proposes, an editor model applies; two model calls), `/help` (questions about aider). Architect mode helps when a strong planner is slow or expensive and a fast local model can type the edits: set `--model` as the architect and `--editor-model` for the editor.

## Streaming

Streaming is on by default (`--no-stream` to disable). A proxy that buffers SSE makes aider look frozen then dump a whole answer; fix the proxy (Caddy `flush_interval -1`, nginx `proxy_buffering off`; Cloudflare 524 on silent origins, see the `cloudflare-tunnel` skill). Set `streaming: false` in model settings for backends whose stream is broken.

## Reasoning and templates

- Inline `<think>` text: `reasoning_tag: think`, otherwise it pollutes parsing.
- Separate reasoning fields: enable the engine's reasoning parser.
- Models that reject `temperature` or a system prompt: `use_temperature: false`, `use_system_prompt: false`.
- Some local chat templates drop the system role; if the model ignores edit instructions, test a plain call with the check script and review the template (skill `tool-calling-parsers` covers template and parser details).

## Context pressure

Aider sends the chat files, the repo map (`--map-tokens`), history and read-only files every turn. Small windows overflow fast: add only files to be edited, use `/read-only` for reference, `/tokens` to inspect, `/drop` and `/clear` to trim. History is summarized by the weak model when it grows.

## Git behavior to know

Aider commits its edits automatically in a git repo (`--no-auto-commits` to stop, `/undo` to revert its last commit, `--no-git` to run without git). It also needs `.gitignore` handling for its own files (`.aider*`); `.env` must be ignored.

## Network and telemetry

Aider can check for updates on start (`--no-check-update`) and has opt-in analytics (`--analytics-disable` or `--no-analytics` to make sure it is off). Models are called only at your `OPENAI_API_BASE`; with no model chosen it may offer OpenRouter, so always pass `--model` on restricted hosts.

## Honest limits

A model that cannot follow a search/replace format will fail in `diff`; the fix is `whole` or a better model, not a flag. Quantized very small models may still produce partial files in `whole`; keep files small.
