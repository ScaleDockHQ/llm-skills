# Kilo Code troubleshooting

> Verified against Kilo Code v7.8.8 docs and issue-tracker patterns, 2026-10-11

## What it is and when to choose it

Symptom to cause to fix for Kilo Code against self-hosted endpoints. Check the gateway or engine log first: it tells you whether the request arrived.

## Install

Not applicable; see `install.md`.

## Minimal working config

`providers-endpoints.md` and `assets/kilo.jsonc`.

## Symptoms

| Symptom                                        | Likely cause                                                                                | Fix                                                                                                               |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Provider unauthenticated, 401 or "missing key" | `{env:VAR}` in a project `kilo.json` (ignored there), or VAR not exported where Kilo starts | Move the provider to `~/.config/kilo/kilo.jsonc`; export the var in the launching shell or use `{file:/abs/path}` |
| Model not in the picker                        | Provider disabled, `whitelist` excludes it, or `/v1/models` fetch failed                    | `kilo models`; press Fetch models; add the model manually under `models`                                          |
| Picker shows hundreds of models                | Auto-fetch lists everything the key sees                                                    | Add `whitelist`, or scope the gateway key to the aliases you want                                                 |
| Context grows until the provider errors        | `limit.context` unset (0), so compaction is disabled                                        | Set `limit.context` and `limit.output`                                                                            |
| Response cut off, nothing useful               | `limit.output` reached, often by reasoning tokens                                           | Raise `limit.output` or turn reasoning off for that model                                                         |
| Agent answers in text but never edits files    | `tool_call` not true, or engine returns no `tool_calls`                                     | `tool_call: true`; vLLM tool-call parser; llama.cpp `--jinja`; run `scripts/probe.sh`                             |
| Loops, repeated or malformed tool calls        | Small or weak local model                                                                   | Larger coder model, shorter sessions, fewer MCP tools                                                             |
| Hangs at the first request                     | Model swap or cold load exceeds `timeout`, or SSE buffered by a proxy                       | Raise `options.timeout`; `flush_interval -1` in Caddy or `proxy_buffering off`; set `chunkTimeout`                |
| `max_tokens` unsupported error (Azure GPT-5)   | Generic provider sends `max_tokens`                                                         | Use the native `azure` provider                                                                                   |
| Ollama answers ignore earlier turns            | `num_ctx` too small, prompt truncated                                                       | Set Context Window Size 32k or more                                                                               |
| `ollama/...` model not found                   | Wrong prefix; `ollama-cloud/` is hosted                                                     | Use `ollama/<model>` and `ollama list`                                                                            |
| 404 on chat                                    | `baseURL` missing `/v1`, or doubled path                                                    | Use the base ending in `/v1`; the dialog also accepts the full endpoint URL                                       |
| Wrong model name error                         | Key vs `id` mismatch                                                                        | Set `id` to the endpoint's model id from `/v1/models`                                                             |
| Extension cannot see exported key              | Editor launched from GUI without shell env                                                  | Use `{file:...}` or start the editor from the shell                                                               |

## How it plugs into the stack

Kilo -> gateway or engine. Bisect: `scripts/probe.sh` from the same machine, then the gateway log, then Kilo.

## Operating

```bash
kilo debug config | jq '.provider | keys'     # resolved providers, check for the one you expect
kilo debug paths
kilo models | head
```

Do not paste `kilo debug config` output into issues unredacted; it may include keys.

## Tuning knobs

`timeout`, `chunkTimeout`, `limit`, `whitelist`, `blacklist`.

## Known pitfalls

- A literal key in `kilo.json` committed to a repo is the most common leak; use `{env:}` or `{file:}` in global config.
- Both `kilo.json` and `kilo.jsonc` can exist; the one you are editing may not be the one in effect (`kilo debug config`).

## Official links

- Custom models: https://kilo.ai/docs/code-with-ai/agents/custom-models
- Issues: https://github.com/Kilo-Org/kilocode/issues
