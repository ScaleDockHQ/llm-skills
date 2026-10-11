# Model capabilities: context, tools, vision, reasoning

> Verified against Claude Code v2.1.296, Codex CLI rust-v0.162.1, OpenCode v1.19.0, Aider v0.86.0, Continue v2.0.0-vscode, Cline v4.1.23, Kilo Code v7.8.8, Open WebUI v0.12.0, LobeHub v2.2.19 and LiteLLM v1.105.0 docs, 2026-10-11

## What it is and when to choose it

Clients decide how much history to send, whether to offer tools, whether to accept image paste and whether to show reasoning, based on what they believe the model supports. For catalog models (official OpenAI, Anthropic, Google names) they look it up in a built-in table. For anything else, including every gateway alias, they fall back to defaults. Read this when a model "works in curl but not in the client".

## Where clients get capabilities

| Source | What it carries | Who reads it |
|---|---|---|
| Built-in model table keyed by model name | Context, output, tools, vision, prices | Claude Code, Codex, Aider (LiteLLM model map), Continue, Cursor |
| Client config | Whatever you declare | OpenCode, Kilo, Continue, Cline, Roo, Codex, Claude Code env, Aider metadata file, Open WebUI, LobeHub |
| `GET /v1/models` (OpenAI shape) | `id`, `object`, `created`, `owned_by` only | Model pickers in most clients |
| Gateway extensions (LiteLLM `/v1/model/info`, `/model_group/info`) | Full `model_info` | Few clients; use for checking, not as client input |

The OpenAI `/v1/models` response has no context, tool or vision fields. A client that "auto-detects" from it only learns the names. Plan to declare capabilities client-side.

## Install

Nothing to install. Inspect what the endpoint knows:

```bash
B=https://llm.example.com
curl -fsS "$B/v1/models" -H "Authorization: Bearer $LLM_API_KEY" | jq -r '.data[].id'
# LiteLLM only: per-alias metadata the gateway believes
curl -fsS "$B/model_group/info" -H "Authorization: Bearer $LLM_API_KEY" \
  | jq '.data[] | {model_group, max_input_tokens, max_output_tokens, supports_function_calling, supports_vision, supports_reasoning}'
```

## Minimal working config

Per client, the fields that matter:

| Client | Context | Output | Tools | Vision | Reasoning |
|---|---|---|---|---|---|
| Claude Code | `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | always on | always on | `MAX_THINKING_TOKENS` |
| Codex CLI | `model_context_window` | n/a | always on | n/a | `model_supports_reasoning_summaries`, `model_reasoning_effort` |
| OpenCode / Kilo | `limit.context` | `limit.output` | `tool_call` | `attachment` + `modalities.input` | `reasoning` |
| Aider | `max_input_tokens` (metadata file) | `max_output_tokens` | edit formats, not tools | n/a | `reasoning_tag`, `accepts_settings` |
| Continue | `defaultCompletionOptions.contextLength` | `maxTokens` | `capabilities: [tool_use]` | `capabilities: [image_input]` | `defaultCompletionOptions.reasoning` |
| Cline / Roo Code | Context Window | Max Output Tokens | Computer Use | Image Support | n/a |
| Open WebUI | n/a (enforced by the backend) | Advanced Params (max tokens) | Function Calling Native/Legacy | Vision capability | Model controls (for example `reasoning_effort`) |
| LobeHub | `<maxToken>` in model list | n/a | `fc` | `vision` | `reasoning` |

## How it plugs into the stack

Declare the same numbers in two places: the gateway's `model_info` (so routing, pre-call checks and context fallbacks work) and the client config (so the client compacts and offers features correctly). Keep the client value at or below the gateway value; the gateway value at or below what the engine was started with (for example the engine's context size flag).

```text
engine context size  >=  gateway max_input_tokens  >=  client context setting
```

## Operating

- After changing an engine's context size or swapping the model behind an alias, update gateway `model_info` and every client config that hard-codes the number.
- Keep a short table (alias, context, output, tools, vision, reasoning) in the team's docs and copy from it.

## Tuning knobs

- Set client context 5-10% below the real window so prompt templates and tool schemas fit.
- Reduce max output for small local models; a large output reservation eats the input budget.
- Turn off reasoning display for models that emit `<think>` in content without a separate reasoning field, or configure the client's reasoning tag (Aider `reasoning_tag`, OpenCode `interleaved.field`).

## Known pitfalls

- **Context too small by default.** Unknown models get conservative defaults (Claude Code assumes 200K; others far less), so long sessions either truncate early or overflow and error.
- **Tools never offered.** Continue without `tool_use`, OpenCode without `tool_call`, Open WebUI in Legacy mode: the model is never sent a tool definition.
- **Vision silently off.** Image paste does nothing or the image is dropped. Declare vision in the client and confirm the backend actually accepts image content.
- **Model name collisions.** An alias that matches a real catalog name (for example a famous OpenAI model ID) makes the client apply that model's capabilities and sometimes its API (Continue sends some OpenAI names to `/responses`). Use neutral aliases.
- **Field lesson: placeholder metadata from gateways.** LiteLLM's `/v1/models` returns the same `created` timestamp and `owned_by: "openai"` for every alias, and `/v1/models` does not expose `supports_vision`. UIs that sort by date or infer the provider from `owned_by` show odd results; declare models explicitly.

## Official links

- Claude Code model configuration: https://code.claude.com/docs/en/model-config
- Codex config reference: https://learn.chatgpt.com/docs/config-file/config-reference
- OpenCode models: https://opencode.ai/docs/models/
- Aider model metadata: https://aider.chat/docs/config/adv-model-settings.html
- Continue model capabilities: https://docs.continue.dev/customize/deep-dives/model-capabilities
- Open WebUI models: https://docs.openwebui.com/features/workspace/models
- LobeHub model list: https://lobehub.com/docs/self-hosting/advanced/model-list
- LiteLLM model discovery: https://docs.litellm.ai/docs/proxy/model_discovery
- OpenAI models endpoint: https://platform.openai.com/docs/api-reference/models/list
