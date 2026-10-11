# Codex CLI: model names, limits and reasoning settings

> Verified against Codex CLI rust-v0.162.1 (docs: config-reference, config-advanced), 2026-10-11

Codex sends `model` verbatim in the Responses request. Mapping is therefore: set `model` to the string the endpoint serves (vLLM `--served-model-name`, llama-swap model ID or alias, Ollama tag, LiteLLM `model_name`). There is no alias table in Codex; add aliases on the server side.

## Keys

| Key                                    | Effect                                                                                                                                                                                          |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `model`                                | Served model name.                                                                                                                                                                              |
| `model_provider`                       | Provider ID from `[model_providers.<id>]`.                                                                                                                                                      |
| `model_context_window`                 | Context tokens available to the active model. Set it for any model Codex does not know.                                                                                                         |
| `model_auto_compact_token_limit`       | Token threshold that triggers compaction (unset uses model defaults). Set below the server's real window, with headroom for output.                                                             |
| `model_auto_compact_token_limit_scope` | `total` (default) counts the full active context; `body_after_prefix` counts growth after the compaction prefix.                                                                                |
| `tool_output_token_limit`              | Token budget for storing individual tool outputs in history. Lower it for small windows.                                                                                                        |
| `model_reasoning_effort`               | `low`, `medium`, `high`, `xhigh`, `max`, `ultra`; available levels depend on model and client.                                                                                                  |
| `model_reasoning_summary`              | `auto`, `concise`, `detailed` or `none`. Use `none` if the backend rejects reasoning summaries.                                                                                                 |
| `model_supports_reasoning_summaries`   | Force Codex to send or not send reasoning metadata.                                                                                                                                             |
| `model_verbosity`                      | `low`, `medium`, `high`; Responses-API only, a GPT-5 setting, ignored by backends that do not know it.                                                                                          |
| `model_catalog_json`                   | Path to a JSON model catalog loaded at startup; profile files can override it. Richer per-model metadata; the file format is defined upstream (see the Codex models docs), not reproduced here. |

## Sizing the window

- The server decides what really fits: vLLM `--max-model-len`, llama.cpp `-c` (per slot when `--parallel` > 1), Ollama `OLLAMA_CONTEXT_LENGTH` or `num_ctx`. Codex does not raise it. Set `model_context_window` to the same number.
- Agent prompts are large (instructions, tool schemas, repo context): 32k is the practical floor, 64k or more is comfortable.
- Compact before the server limit: for a 131072 window, `model_auto_compact_token_limit = 110000` leaves room for a reply.
- A server that returns `context_length_exceeded` does not trigger recovery: Codex maps that 400 to a generic invalid-request error for local providers (open issue openai/codex#48870 at write time), so compaction cannot rescue an overflow. Set the limits so overflow never happens, and `/compact` by hand if it does.
- Small local models degrade as context fills; compacting earlier is cheaper than recovering from bad edits.

## Reasoning models

- Reasoning models (gpt-oss, Qwen3 thinking, DeepSeek) need the engine's reasoning parser so thinking is returned as reasoning items rather than answer text (vLLM `--reasoning-parser`, llama.cpp `--reasoning-format`).
- If requests fail with a parameter error mentioning `reasoning` or `summary`, set `model_reasoning_summary = "none"` and `model_supports_reasoning_summaries = false`.
- `model_reasoning_effort` maps to the Responses `reasoning.effort` field. vLLM and Ollama accept it on `/v1/responses`; for other engines verify with the check script before relying on it.

## One model per task

Codex has one active model per session. For a larger model on hard tasks and a smaller one for speed, define two profile files (`fast.config.toml`, `deep.config.toml`) pointing at different served names and start with `codex --profile fast` or `deep`. llama-swap and LiteLLM can serve both behind one provider.

## Discovery

```bash
curl -s -H "Authorization: Bearer $LOCAL_LLM_API_KEY" "$BASE/models" | jq -r '.data[].id'   # BASE ends in /v1
```

Select a custom served name with `model` in config or `codex --model <name>`. Whether the in-session `/model` picker lists models from a custom endpoint was not verified; do not rely on it.
