# Reasoning effort

> Verified against vLLM v0.31.0 (reasoning outputs docs), llama.cpp v0.6.0, llama-swap v263, LiteLLM v1.105.0, 2026-10-11

Clients expose "reasoning effort" or "thinking" toggles, but models disagree on what they accept.
The stack maps client-facing names to whatever each model understands, in config only, without
custom gateway code.

## What models actually accept

There is no common value set. Check each model's card and chat template; typical families:

| Model family | Control | Values |
| --- | --- | --- |
| gpt-oss | `reasoning_effort` (top-level request field) | `low`, `medium`, `high` |
| Qwen3-style templates | `chat_template_kwargs.enable_thinking` | `true` (default) / `false` |
| DeepSeek-V3.1, IBM Granite 3.2 | `chat_template_kwargs.thinking` | `false` (default) / `true` |
| Gemma 4 | `chat_template_kwargs.enable_thinking`, or any `reasoning_effort` | off by default |
| Non-reasoning models | none | the field should be removed |

Engine behaviour on top of that:

- **vLLM**: `reasoning_effort` of `low`/`medium`/`high` also injects `enable_thinking=true`, and
  `none` injects `false`, for templates that declare it. Explicit `chat_template_kwargs` win.
  `--default-chat-template-kwargs '{"enable_thinking": false}'` sets a server default.
  `--reasoning-parser` must be set for reasoning to come back in `reasoning_content`.
- **llama.cpp**: request `chat_template_kwargs` are passed to the template; server flags
  `--reasoning-effort LEVEL`, `--reasoning-budget N` (`0` ends thinking immediately) and
  `--reasoning-format` (`deepseek` puts thoughts in `reasoning_content`).
- **TensorFold**: `--reasoning-effort` and `--thinking` / `--no-thinking` at startup (`engine-tensorfold.md`).

A value outside the model's set (for example `minimal` sent to a model that knows only
`low`/`medium`/`high`) may be rejected, ignored, or rendered into the prompt as-is, depending on
engine and template. Test each value you expose.

## Mapping in config: variant names

Expose each supported level as its own model name. llama-swap's `filters.setParamsByID` creates an
alias per key that runs the **same** process with fields forced, so variants cost no extra memory:

```yaml
# llama-swap.yaml
"gpt-oss":
  filters:
    setParamsByID:
      "${MODEL_ID}-low":
        reasoning_effort: low
      "${MODEL_ID}-high":
        reasoning_effort: high
"qwen-coder":
  filters:
    setParamsByID:
      "${MODEL_ID}-nothink":
        chat_template_kwargs:
          enable_thinking: false
```

Then one LiteLLM entry per public variant (`templates/litellm-config.yaml`):

```yaml
- model_name: gpt-oss-high
  litellm_params:
    model: openai/gpt-oss-high
    api_base: http://127.0.0.1:8080/v1
    api_key: "none"
```

Alternative for effort only: set `reasoning_effort` in the LiteLLM entry's `litellm_params` and keep
the llama-swap side plain. `chat_template_kwargs` belong in llama-swap (or engine defaults), because
a nested `extra_body` in LiteLLM `litellm_params` is not documented (unverified).

## Removing unsupported fields

When clients send `reasoning_effort` to a model that rejects it, strip it on that model:

```yaml
"small-gguf":
  filters:
    stripParams: "reasoning_effort"
```

LiteLLM `drop_params: true` drops parameters LiteLLM knows the provider does not support; for
`openai/` deployments with a custom `api_base` it cannot know what the engine accepts, so do not
rely on it for this.

## Catalog and clients

- Mark reasoning variants in `catalog.json` (`capabilities.reasoning`) and LiteLLM `model_info`
  (`supports_reasoning`), so clients show the right toggles.
- Clients that send their own effort field on top of a variant name: the llama-swap
  `setParamsByID` value overrides the request field, so the variant wins.
- Anthropic Messages clients (Claude Code) send a `thinking` block; how it maps onto an `openai/`
  backend is not relied on here (unverified). Point those clients at a variant name instead.

## Verify

Run smoke test 8 (`smoke-test.md`): reasoning length should differ between variants, and the
`-nothink` variant should return no `reasoning_content`.

## Known pitfalls

- One shared `reasoning_effort` vocabulary assumed across models.
- `chat_template_kwargs` key names copied between families (`enable_thinking` vs `thinking`).
- Missing `--reasoning-parser` (vLLM/SGLang) or `--reasoning-format` (llama.cpp): thoughts appear
  inside `content`, and clients show them as answer text.
- Separate engine processes per effort level: doubles memory for no reason; use aliases.

## Official links

- [vLLM reasoning outputs](https://docs.vllm.ai/en/latest/features/reasoning_outputs.html)
- [llama.cpp server options](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)
- [llama-swap filters](https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml)
- [LiteLLM reasoning content](https://docs.litellm.ai/docs/reasoning_content)
