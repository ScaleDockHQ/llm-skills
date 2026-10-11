# Reasoning models: gateway mapping, field naming and the reasoning gate

> Verified against llama-swap main (docs/config.example.yaml), LiteLLM docs (reasoning_content), vLLM v0.31.0 (docs: features/reasoning_outputs), SGLang v0.5.21 (docs: advanced_features/separate_reasoning), 2026-10-11

Promoted and corrected from the reasoning-effort notes of the `self-hosted-llms` skill. Engine flags live in `engine-reasoning-matrix.md`.

## Field naming

| Engine / layer       | Field holding the trace                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------- |
| vLLM                 | `reasoning` (old name `reasoning_content`)                                                         |
| SGLang               | `reasoning_content`                                                                                |
| llama.cpp            | `reasoning_content`                                                                                |
| TensorFold           | `reasoning_content`                                                                                |
| Ollama native API    | `message.thinking`                                                                                 |
| LiteLLM (normalised) | `reasoning_content` ("returned across all providers"); `thinking_blocks` only for Anthropic models |

Whether LiteLLM maps vLLM's `reasoning` onto `reasoning_content` for an `openai/` deployment was not verified (unverified). Test the full path: send a thinking prompt through the gateway and read both fields. If the field is empty, either run the engine in a mode that emits `reasoning_content`, or put a gateway that renames it in front. A client that reads the wrong field shows an empty trace and no error.

## Mapping effort in config (llama-swap)

`filters.setParamsByID` in llama-swap creates a model alias for each key; the alias runs the same process with the listed fields set, so variants cost no extra memory. Aliases use a `:` suffix in the upstream example, and values may be nested objects:

```yaml
"gpt-oss":
  filters:
    setParamsByID:
      "${MODEL_ID}":
        chat_template_kwargs:
          reasoning_effort: medium
      "${MODEL_ID}:high":
        chat_template_kwargs:
          reasoning_effort: high
      "${MODEL_ID}:low":
        chat_template_kwargs:
          reasoning_effort: low
```

Rules from the upstream comments: `setParamsByID` runs after `setParams`, so it overrides it; protected params such as `model` cannot be overridden; a `setParams` key ending in `?` is set only if the request does not contain it. Whether your engine reads `reasoning_effort` from `chat_template_kwargs` or the top-level field depends on the engine and template (see the matrix: TensorFold reads both with the top-level winning; vLLM and llama.cpp take the top-level field). Check with the probe and use the form the engine honors.

Toggle-style models (Qwen3 `enable_thinking`, DeepSeek-V3.1 `thinking`):

```yaml
"qwen-coder":
  filters:
    setParamsByID:
      "${MODEL_ID}:nothink":
        chat_template_kwargs:
          enable_thinking: false
```

Then register one public model name per variant in the gateway (`llm-gateway` skill), with the same `api_base` and the variant name as the upstream model.

## Stripping unsupported fields

`filters.stripParams` is a comma-separated list of request keys removed before the request reaches the model; `model` can never be removed; upstream recommends it mainly for sampling parameters. For a model that rejects `reasoning_effort`:

```yaml
"small-gguf":
  filters:
    stripParams: "reasoning_effort"
```

LiteLLM `drop_params` drops parameters LiteLLM knows the provider does not support; whether it can know what a custom `api_base` engine accepts is not documented (unverified), so do not rely on it for this. LiteLLM's `modify_params: true` handles one case: Anthropic thinking with tool calls when clients drop `thinking_blocks`; it drops the `thinking` param for that turn.

## Effort and budget mapping

| Client sends                       | Engine behavior                                                                                                                                                            |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `reasoning_effort` low/medium/high | vLLM: also sets `enable_thinking=true` where the template declares it; llama.cpp: passed to template; TensorFold: mapped to nearest level the template names               |
| `reasoning_effort: none`           | vLLM: `enable_thinking=false`; llama.cpp: thinking disabled; TensorFold: thinking off                                                                                      |
| Level the model lacks (`minimal`)  | Depends on engine and template: mapped (TensorFold), ignored, or rendered as-is. Test every level you expose                                                               |
| Effort as a token cap              | Effort does not set a budget; use the budget controls (vLLM `thinking_token_budget`, SGLang strict thinking, llama.cpp `--reasoning-budget`, TensorFold `thinking_budget`) |
| Anthropic `thinking` block         | How it maps onto an `openai/` backend is not relied on here (unverified); point those clients at a variant name                                                            |

## Reasoning gate

Reasoning on or off, an effort level, and a thinking budget all change what the model answers and what it costs. Run this with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`) before exposing a variant or changing a default. Write thresholds first.

1. **Golden set.** Real tasks with checkable answers, plus tasks that need long reasoning, tasks that need none, structured-output tasks and tool-calling tasks if the product uses them.
2. **Arms.** Baseline (current default) versus one candidate: thinking off, a lower effort, a budget of N, or a new engine or parser. One change per run. Same sampling settings; use the model card's recommended temperature for thinking mode.
3. **Metrics per arm:** task accuracy; completion tokens, reasoning tokens (`completion_tokens_details.reasoning_tokens` where reported) and end-to-end latency per task; budget truncation rate (answers where the budget closed the block) and accuracy on truncated versus untruncated items; empty-answer rate (`content` empty because the model spent `max_tokens` thinking); trace-leak rate (thoughts or tags in `content`); loop rate (reasoning hitting `max_tokens`).
4. **Decide.** Accept only if accuracy is not worse than baseline beyond measured noise and the token or latency saving meets the target you wrote. Keep effort levels only if they separate on cost or accuracy; otherwise drop the variant.
5. **Budget specifics.** Run a deterministic check: budget set versus unset at temperature 0 on the same prompt. If the output is identical token for token, the budget knob is not applied (SGLang docs describe this check).
6. **Rollback.** Keep the previous flags, `setParamsByID` block and image tag in version control; reverting is restoring them and reloading the gateway and engine.

## Pitfalls

- Missing `--reasoning-parser` (vLLM, SGLang) or `--reasoning-format` (llama.cpp): the trace lands in `content` and clients show it as the answer.
- Clients reading `reasoning_content` from vLLM (now `reasoning`).
- `enable_thinking` versus `thinking` copied between families; DeepSeek-V3.1 on vLLM takes `thinking`.
- Budget that silently does nothing: SGLang `chat_template_kwargs.thinking_budget` on a template without that variable, missing `require_reasoning: true` on `/generate`, built-in logit processors whose token IDs do not match the tokenizer.
- Budget set below what the task needs: truncated reasoning lowers accuracy; the answer still looks fluent.
- `max_tokens` counts reasoning tokens: too small a limit yields an empty `content`.
- vLLM `include_reasoning: false` hides the trace but does not save tokens; the model still generates it.
- Tool calls and structured output with a reasoning model: tool calls are parsed from `content` in vLLM; grammars apply after the think block. See the `tool-calling-parsers` and `structured-outputs` skills.
- Separate engine processes per effort level double memory; use aliases.

## Official links

- https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml
- https://docs.litellm.ai/docs/reasoning_content
- https://docs.vllm.ai/en/latest/features/reasoning_outputs/
- https://docs.sglang.io/docs/advanced_features/thinking_budget.md
