# Aider: model metadata, model settings, reasoning

> Verified against Aider v0.86.0 (docs: config/adv-model-settings, config/reasoning, troubleshooting/warnings, troubleshooting/token-limits, config/options), 2026-10-11

## Context window and cost: `.aider.model.metadata.json`

Aider takes model metadata from LiteLLM's model list. For a self-hosted name it does not know, it warns "Unknown context window size and costs, using sane defaults", then assumes an unlimited window and zero cost. Per the docs you can usually ignore this: **aider never enforces token limits**, it only reports token-limit errors the provider returns, and its token counts are estimates.

Register the model to silence the warning and make `/tokens` and cost output meaningful:

```json
{
  "openai/coder": {
    "max_tokens": 16384,
    "max_input_tokens": 131072,
    "max_output_tokens": 16384,
    "input_cost_per_token": 0,
    "output_cost_per_token": 0,
    "litellm_provider": "openai",
    "mode": "chat"
  }
}
```

Use the fully qualified name with the provider prefix; the prefix must match `litellm_provider`. Locations: home, git root, current directory (later wins) or `--model-metadata-file`. Leave costs at 0 for local models (no hardcoded prices).

Real enforcement is the server's: vLLM `--max-model-len`, llama.cpp `-c`, Ollama's context (see `custom-endpoints.md`). When the server rejects a request, aider prints a token-limit message with options; reduce chat files (`/drop`, `/tokens`), ask for smaller edits, or raise the server window.

## Behavior: `.aider.model.settings.yml`

A YAML list, one entry per model; only override what you need. Fields and defaults (docs): `edit_format: whole`, `weak_model_name`, `use_repo_map: false`, `send_undo_reply`, `lazy`, `overeager`, `reminder: user`, `examples_as_sys_msg`, `extra_params`, `cache_control`, `caches_by_default`, `use_system_prompt: true`, `use_temperature: true`, `streaming: true`, `editor_model_name`, `editor_edit_format`, `reasoning_tag`, `remove_reasoning`, `system_prompt_prefix`, `accepts_settings`.

```yaml
- name: openai/coder
  edit_format: diff
  use_repo_map: true
  weak_model_name: openai/small
  editor_model_name: openai/coder
  editor_edit_format: editor-diff
  extra_params:
    max_tokens: 8192

- name: openai/tiny
  edit_format: whole
  use_repo_map: false
  streaming: true
```

| Setting                  | Why change it for local models                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| `edit_format`            | `diff` or `diff-fenced` for strong coders; `whole` when a small model garbles search/replace.    |
| `use_repo_map`           | Repo map costs tokens (`--map-tokens`); turn off or shrink for small windows.                    |
| `weak_model_name`        | Used for commit messages and history summaries; point to a cheaper local model or the same one.  |
| `editor_model_name`      | Architect mode: the architect plans, the editor applies edits (`editor-diff` or `editor-whole`). |
| `use_temperature: false` | Models or gateways that reject `temperature`.                                                    |
| `streaming: false`       | Backends whose streaming is broken or models that forbid it.                                     |
| `extra_params`           | Passed to `litellm.completion()`: headers, `max_tokens`, `num_ctx`, body fields.                 |

CLI equivalents: `--edit-format`, `--weak-model`, `--editor-model`, `--editor-edit-format`, `--architect`, `--map-tokens`, `--no-stream`. Without `--weak-model` or `--editor-model`, the default depends on `--model` (docs); check the startup banner for what was chosen.

## Reasoning models

- `--reasoning-effort low|medium|high` for models whose settings accept `reasoning_effort`; `--thinking-tokens 8k` (or `0` to disable) for `thinking_tokens`. In chat: `/reasoning-effort`, `/thinking-tokens`.
- Aider checks `accepts_settings` for the model and ignores unsupported settings with a warning; `--no-check-model-accepts-settings` forces them (useful for custom providers). Add `accepts_settings: [reasoning_effort]` in model settings to declare support.
- Reasoning that comes back inline inside XML tags (for example `<think>...</think>`) needs `reasoning_tag: think` (or the tag the model uses): aider displays the thinking but excludes it from edit parsing and chat history. `remove_reasoning` is the related field to strip it.
- Reasoning returned in a separate API field (vLLM `--reasoning-parser`, llama.cpp `--reasoning-format`) is not mixed into the content, so no tag is needed. Pick one: engine-side parsing or `reasoning_tag`, not both.
- Many reasoning models restrict streaming, temperature or system prompts; set `streaming`, `use_temperature`, `use_system_prompt` accordingly when served through custom providers.

## Aliases

`--alias fast:openai/small` creates a short name usable in `--model` and `/model`. Chat commands `/model`, `/weak-model`, `/editor-model` switch models mid-session.
