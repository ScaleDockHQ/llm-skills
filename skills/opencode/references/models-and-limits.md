# OpenCode: model entries, limits and capability flags

> Verified against OpenCode v1.19.0 (docs: providers, models, config; JSON schema opencode.ai/config.json), 2026-10-11

Standard providers pull limits and capabilities from models.dev automatically. Custom providers do not, so every field below is yours to declare truthfully.

## Model entry fields (schema)

| Field                           | Meaning                                                                                                                                                         |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                          | Display name in the picker.                                                                                                                                     |
| `id`                            | ID sent to the API when different from the config key.                                                                                                          |
| `limit.context`, `limit.output` | Required pair. `limit.input` optional. Used to track remaining context and compact on time.                                                                     |
| `tool_call`                     | The model supports tool calling. Set `true` only if the engine parses tool calls (see `compatibility.md`).                                                      |
| `reasoning`                     | The model emits reasoning.                                                                                                                                      |
| `attachment`                    | The model accepts file/image attachments.                                                                                                                       |
| `modalities.input` / `.output`  | Arrays from `text`, `audio`, `image`, `video`, `pdf`. Image paste needs `image` in input.                                                                       |
| `temperature`                   | Boolean: whether the model accepts a temperature parameter.                                                                                                     |
| `interleaved`                   | `true`, a field name, or `{ "field": "reasoning_content" }` (also `reasoning`, `reasoning_text`): where interleaved reasoning text lives in assistant messages. |
| `options`, `headers`            | Extra request options and headers for this model.                                                                                                               |
| `variants`                      | Named option sets (for example `reasoningEffort`, `textVerbosity`, `reasoningSummary`), cycled in the TUI.                                                      |
| `provider.npm`                  | Per-model package override for mixed wire formats under one provider.                                                                                           |

Setting limits: `limit.context` equals what the server really serves (vLLM `--max-model-len`, llama.cpp `-c` per slot, Ollama `OLLAMA_CONTEXT_LENGTH`/`num_ctx`). Agent sessions need at least 32k; 64k or more is comfortable. `limit.output` stays below the server's max output. OpenCode cannot raise the server's window; a larger declared value just yields 400 errors from the server.

## Default and small model

- `model`: `<provider>/<model>`. `small_model`: lightweight tasks such as title generation. By default OpenCode tries a cheaper model from the provider and falls back to the main one; set it explicitly to a small local model so titles do not occupy your large model.
- `opencode models [provider]` prints the exact `provider/model` strings; `--refresh` refreshes the models.dev cache; `--verbose` includes metadata.
- `disabled_providers` / `enabled_providers` (disabled wins) restrict which auto-loaded providers appear. Set `disabled_providers` for cloud providers on an air-gapped host.

## Variants and reasoning

```json
"models": {
  "reasoner": {
    "name": "Reasoner",
    "reasoning": true,
    "interleaved": { "field": "reasoning_content" },
    "limit": { "context": 131072, "output": 32768 },
    "variants": { "high": { "reasoningEffort": "high" }, "low": { "reasoningEffort": "low" } }
  }
}
```

- `interleaved.field` tells OpenCode which assistant-message field carries reasoning so it can send it back on later turns. vLLM now returns `reasoning` (renamed from `reasoning_content`), llama.cpp returns `reasoning_content` depending on `--reasoning-format`; match the field to your engine.
- Variant option names are provider-package specific; a backend that does not know an option may reject it (see `compatibility.md`).

## Images

Image paste or attach does nothing useful until the model entry has `attachment: true` and `modalities.input` including `image`, and the served model is multimodal. OpenCode resizes images above 2000x2000 by default (`attachment.image` config).

## Compaction

OpenCode compacts automatically using `limit.context`; `OPENCODE_DISABLE_AUTOCOMPACT` turns it off. Without a correct `limit.context` compaction is late and the first symptom is a server-side context error.

## Example: two models behind one provider

```json
"models": {
  "coder":  { "name": "Coder",  "limit": { "context": 131072, "output": 16384 }, "tool_call": true },
  "small":  { "name": "Small",  "limit": { "context": 32768,  "output": 4096 },  "tool_call": true },
  "vision": { "name": "Vision", "limit": { "context": 32768,  "output": 4096 },  "tool_call": true,
              "attachment": true, "modalities": { "input": ["text", "image"], "output": ["text"] } }
}
```

with `"model": "local/coder"` and `"small_model": "local/small"`.
