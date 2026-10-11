# Claude Code: model names, slots and limits

> Verified against Claude Code v2.1.296 (docs: model-config, env-vars, llm-gateway-protocol), 2026-10-11

Claude Code sends the model name you give it as the `model` field. Mapping is therefore: choose the string your endpoint serves (vLLM `--served-model-name`, llama-swap model ID or alias, Ollama tag, LiteLLM `model_name`), and tell Claude Code which slot uses it.

## Slots

| Setting                                    | Used for                                                                                                                                               |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ANTHROPIC_MODEL` (or `--model`, `/model`) | The main model for the session.                                                                                                                        |
| `ANTHROPIC_DEFAULT_OPUS_MODEL`             | What the `opus` alias resolves to; also `opusplan` in Plan Mode.                                                                                       |
| `ANTHROPIC_DEFAULT_SONNET_MODEL`           | What the `sonnet` alias resolves to; `opusplan` outside Plan Mode.                                                                                     |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL`            | What `haiku` resolves to, and background work (titles, summaries). Pin it to a small fast local model.                                                 |
| `CLAUDE_CODE_SUBAGENT_MODEL`               | Subagents, agent-team teammates and workflow agents not assigned a model elsewhere. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` forces one model (v2.1.257+). |
| `ANTHROPIC_SMALL_FAST_MODEL`               | Deprecated; use the Haiku variable.                                                                                                                    |

Behind `ANTHROPIC_BASE_URL`, background tasks use the main model unless `ANTHROPIC_DEFAULT_HAIKU_MODEL` pins one (the Haiku default applies only when a Console API key supplies the credential and `ANTHROPIC_AUTH_TOKEN` is unset). Pin Haiku, or every background call loads your large model.

Minimal one-model setup: set only `ANTHROPIC_MODEL` and `ANTHROPIC_DEFAULT_HAIKU_MODEL`; set the Opus, Sonnet and subagent slots too if you want `/model` aliases and subagents to land on local names instead of Anthropic IDs (an Anthropic ID your endpoint lacks returns "model not found").

One alias per model family on the endpoint is simplest. For several versions per family use `modelOverrides` in settings: it maps an Anthropic model ID (key) to the string sent to the provider (value); unknown keys are ignored.

## Picker and discovery

- `ANTHROPIC_CUSTOM_MODEL_OPTION` (+ `_NAME`, `_DESCRIPTION`, `_SUPPORTED_CAPABILITIES` such as `effort,thinking`) adds one `/model` entry.
- `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` makes Claude Code call `GET /v1/models?limit=1000` at startup (3 s timeout; `CLAUDE_CODE_GATEWAY_MODEL_DISCOVERY_TIMEOUT_MS` on v2.1.269+) and add entries whose `id` contains `claude` or `anthropic` (case-insensitive). A redirect, including http to https, fails silently. Both credential headers are sent (v2.1.248+). Results cache in `~/.claude/cache/gateway-models.json`.
- Local names such as `qwen3-coder` are filtered out of discovery. Either name aliases `claude-local-coder` (LiteLLM `model_name`, llama-swap alias, vLLM `--served-model-name`), or add them with `ANTHROPIC_CUSTOM_MODEL_OPTION`, or select with `--model` / `ANTHROPIC_MODEL` directly. Setting a model by variable always works without discovery.
- Check discovery with `claude --debug` and look for `[gatewayDiscovery]` lines.

## Context window and output limits

For an ID Claude Code cannot resolve to a model it knows, it assumes a 200K window (1M when the ID contains `[1m]`), default output 32000 and output cap 128000. Declare the truth:

| Variable                                                 | Effect                                                                                                                                                                                                    |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS`                         | Window Claude Code assumes. Applies directly to unrecognized IDs. A recognized ID (contains a known model name, or bare `claude-...`) needs `DISABLE_COMPACT` too, so give local models non-Claude names. |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW`                        | Compaction threshold when the endpoint enforces less than the model's window. Plain integer, clamped between 100000 and the window; below 100K you rely on `/compact`.                                    |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS`                          | Max output per request; keep below the endpoint's limit (vLLM `--max-model-len` minus prompt, llama.cpp `-n`/`-c`).                                                                                       |
| `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` | Compact only after the API rejects with a too-long error Claude Code recognizes (not if the gateway rewrites the error).                                                                                  |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`                       | With a `[1m]` ID on an unknown model, sizes it like the unsuffixed ID so the window variable applies.                                                                                                     |
| `API_TIMEOUT_MS`                                         | Request timeout, default 600000. Raise for slow prefill or model swaps.                                                                                                                                   |

A declared window above 200K triggers a startup warning "the 200K limit isn't enforced"; expected. Local engines must really serve that window (vLLM `--max-model-len`, llama.cpp `-c`, Ollama `OLLAMA_CONTEXT_LENGTH` or `num_ctx`); Claude Code never raises the server's limit. A small server window with a large declared one ends in 400 context errors; see `troubleshooting.md`.

## Capabilities of aliases

`ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` have no effect behind an `ANTHROPIC_BASE_URL` gateway (they apply only to the Bedrock, Vertex, Foundry and Mantle provider configurations). `ANTHROPIC_CUSTOM_MODEL_OPTION_SUPPORTED_CAPABILITIES` is the per-entry route for the picker. For an unknown ID the request carries everything current Claude models accept (adaptive reasoning, effort, context management); trim with the switches in `compatibility.md`.

## Example: one local coder and a small helper

```bash
export ANTHROPIC_BASE_URL="http://llm.internal:8080"
export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/llm/key)"
export ANTHROPIC_MODEL="qwen3-coder"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3-coder"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3-coder"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3-small"
export CLAUDE_CODE_SUBAGENT_MODEL="qwen3-coder"
export CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=16384
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export API_TIMEOUT_MS=900000
```

Model names are placeholders; read the real ones with `curl -s -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" "$ANTHROPIC_BASE_URL/v1/models" | jq -r '.data[].id'`.
