# DeepSeek parsers and templates

> Verified against vLLM v0.31.0 and recipes, SGLang v0.5.21 cookbook, llama.cpp b11556, TensorRT-LLM main, DeepSeek encoding READMEs, 2026-10-11

## Prompt format

| Generation           | Template source                                                                                                                                | Notes                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| V4, V4-0731, V4-0813 | No Jinja in the repos. `encoding/encoding_dsv4.py` (`encode_messages`, `parse_message_from_completion_text`)                                   | `thinking_mode="thinking"` or `"chat"`.                                                  |
| V4.1                 | `encoding/encoding.py`, and a `chat_template.jinja` merged into the repo (HF discussion 68). The model card text still says no Jinja template. | Carries `thinking_mode`, `enable_thinking` (alias), `drop_thinking`, `reasoning_effort`. |
| V3.2                 | `encoding/encoding_dsv32.py`                                                                                                                   | New tool format and thinking with tools.                                                 |
| R1, V3, V3.1         | Jinja templates in the repos; vLLM ships example templates for tool calling                                                                    | See "Legacy".                                                                            |

Special tokens (V4.1 README): `<｜begin▁of▁sentence｜>` (BOS, prepended once), `<｜end▁of▁sentence｜>` (EOS), `<｜User｜>`, `<｜Assistant｜>`, `<｜System｜>` (mid-conversation system message, V4.1), `<think>` and `</think>`.

- **Chat mode** puts `</think>` right after `<｜Assistant｜>`, so the model answers directly. **Thinking mode** puts `<think>` there.
- `drop_thinking` (default true) strips reasoning from earlier turns. With tools it switches off automatically and every turn keeps its reasoning, so send `reasoning_content` back on tool turns.
- A tool message is merged into the preceding user turn as `<tool_result>...</tool_result>`.
- V4.1 renders `Reasoning Effort: N (range 1-100, ...)` as a system prefix on the first turn only, and only in thinking mode.

## Tool call format (DSML)

| Generation           | Wrapper tags                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| V4, V4-0731, V4-0813 | `<｜DSML｜tool_calls>`, `<｜DSML｜invoke name="...">`, `<｜DSML｜parameter name="..." string="true\|false">` |
| V4.1                 | Same with a leading space: `<｜DSML｜ calls>`, `<｜DSML｜ invoke ...>`, `<｜DSML｜ parameter ...>`           |

`string="true"` means a raw string; `string="false"` means JSON. V4.1 also allows tool namespaces (`search::lookup`). The V4 detector cannot parse V4.1 tags, so use the V4.1 parser (vLLM issue 58640).

## vLLM

Needs 0.25.0+ for V4 and DSpark, and 0.30.0+ (nightly Docker image per the recipe, because "no pip wheel serves this architecture") for V4.1. Install and tuning: the `vllm` skill.

| Checkpoint                       | `--tokenizer-mode`             | `--tool-call-parser`                                                                        | `--reasoning-parser` |
| -------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------- | -------------------- |
| V4, V4-0731, V4-0813, Vision-Exp | `deepseek_v4`                  | `deepseek_v4`                                                                               | `deepseek_v4`        |
| V4.1-Flash                       | `deepseek_v41`                 | `deepseek_v41`                                                                              | `deepseek_v41`       |
| V3.2                             | not documented in sources read | `deepseek_v32`                                                                              | not documented       |
| V3.1                             | n/a                            | `deepseek_v31` with `examples/tool_chat_template_deepseekv31.jinja`                         | `deepseek_v3`        |
| V3-0324, R1-0528                 | n/a                            | `deepseek_v3` with `examples/tool_chat_template_deepseekv3.jinja` or `..._deepseekr1.jinja` | `deepseek_r1`        |
| R1 and R1 distills               | n/a                            | n/a                                                                                         | `deepseek_r1`        |

Always add `--enable-auto-tool-choice`. Recipe launch for V4-Flash-0731 (8 GPUs; adapt per `platforms-and-quants.md`):

```bash
vllm serve deepseek-ai/DeepSeek-V4-Flash-0731 \
  --trust-remote-code --kv-cache-dtype fp8 --block-size 256 \
  --enable-expert-parallel --tensor-parallel-size 8 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --speculative-config '{"method":"dspark","num_speculative_tokens":7,"draft_sample_method":"probabilistic"}'
```

The recipe also passes `--reasoning-config` with `reasoning_start_str` and `reasoning_end_str`; copy that line from the [recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash) rather than retyping it. V4.1 launch (nightly image, 2 GPUs shown in the recipe):

```bash
vllm serve deepseek-ai/DeepSeek-V4.1-Flash \
  --tokenizer-mode deepseek_v41 --tensor-parallel-size 2 \
  --attention-config '{"backend":"FLASHINFER_MLA_SPARSE_DSV41","indexer_kv_dtype":"mxfp4","indexer_sparse_logits":true}' \
  --kv-cache-dtype fp8 --max-num-seqs 128 \
  --engram-config '{"cpu_offload":true}' \
  --tool-call-parser deepseek_v41 --enable-auto-tool-choice \
  --reasoning-parser deepseek_v41 --mm-encoder-tp-mode data
```

Add `--language-model-only` for text-only use; it drops the vision tower. The V4.1 recipe lists no DGX Spark or consumer GPU recipe.

- **Speculative decoding:** V4-0731/0813 and V4.1 use `--speculative-config '{"method":"dspark",...}'` (`num_speculative_tokens` 7 for V4 0731/0813 in the recipe, 5 for V4.1). `method: mtp` only works on the preview checkpoints; 0731 has no MTP head. V4.1 has no MTP at all.
- **`/v1/messages` and mid-conversation system messages:** pass `--chat-template` (the V4.1 `chat_template.jinja`) or prefix caching breaks (issue 60537).
- **Think Max:** needs `--max-model-len >= 393216`.

## SGLang

Use `lmsysorg/sglang:latest` for V4 and `lmsysorg/sglang:dev-dsv41` for V4.1 (no release carries V4.1 yet). Do not override `--attention-backend`, `--moe-runner-backend` or `--fp8-gemm-backend` on V4.1. Install and tuning: the `sglang` skill.

| Checkpoint           | `--reasoning-parser`                | `--tool-call-parser`                         |
| -------------------- | ----------------------------------- | -------------------------------------------- |
| V4, V4-0731, V4-0813 | `deepseek-v4`                       | `deepseekv4`                                 |
| V4.1-Flash           | `auto` (resolves to `deepseek-v41`) | `auto` (resolves to `deepseekv41`)           |
| V3.2 / V3.1 / V3     | not documented in sources read      | `deepseekv32` / `deepseekv31` / `deepseekv3` |
| R1                   | `deepseek-r1`                       | not documented                               |

```bash
sglang serve --trust-remote-code \
  --model-path deepseek-ai/DeepSeek-V4-Flash-0731 \
  --tp 4 --moe-runner-backend flashinfer_mxfp4 \
  --speculative-algorithm DSPARK \
  --mem-fraction-static 0.90 --chunked-prefill-size 4096 --swa-full-tokens-ratio 0.1 \
  --reasoning-parser deepseek-v4 --tool-call-parser deepseekv4
```

DSpark takes target and draft weights from the same checkpoint, so set no `--speculative-draft-model-path`. Do not use `--speculative-algorithm EAGLE` on 0731, 0813 or V4.1: it starts without error but accepts nothing. V4.1 recipes use `--speculative-dspark-block-size 5`. Prefill/decode disaggregation and speculative decoding cannot be combined.

## Reasoning toggles

| Engine and model             | How to switch                                                                                                                                                                                                                                                                             |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM V4 / 0731 / 0813        | Non-think is the default. Think High: `extra_body={"chat_template_kwargs": {"thinking": true, "reasoning_effort": "high"}}`. Think Max: `"reasoning_effort": "max"`. 0731 and 0813 name the levels `low`, `high`, `max`.                                                                  |
| vLLM V4.1                    | `chat_template_kwargs` keys `thinking` or `enable_thinking` (must agree) and `reasoning_effort`. The top-level OpenAI `reasoning_effort` works too, and `"none"` turns thinking off. `minimal` and `medium` are rejected. With neither set, thinking is **on** at effort 50.              |
| SGLang V4.1                  | Thinking off by default (`SGLANG_DEFAULT_THINKING=false`). Any `reasoning_effort` other than `none` turns it on. Integer effort goes through `chat_template_kwargs.reasoning_effort` together with `thinking`. Default effort `high` (75), override with `SGLANG_DSV41_REASONING_EFFORT`. |
| llama.cpp (Unsloth template) | `--chat-template-kwargs '{"reasoning_effort":"max"}'`, `'{"reasoning_effort":"high"}'`, `'{"enable_thinking":false}'`, or `--reasoning on` / `--reasoning off`. Think High is the default.                                                                                                |
| TensorRT-LLM                 | Instruct checkpoints need `custom_tokenizer="deepseek_v4"`. Base checkpoints take raw text and no chat template.                                                                                                                                                                          |

**Effort mapping differs by source.** The V4.1 encoding README maps `low`/`high`/`max` to 50/75/100 (default `high` = 75). The vLLM recipe says its encoder maps `low`/`high`/`xhigh`/`max` to 25/50/75/100, and SGLang maps `low` 50, `high` 75, `xhigh` 75, `max` 100. Send an integer when you need the same effort across engines. The V4.1 report notes efforts of 60-80 recover most of the accuracy of 100 at under half the tokens.

Always give `max_tokens` room. A thinking request with a small `max_tokens` spends everything on the trace and returns empty `content` with `finish_reason=length`.

## Sampling

| Model                  | Recommended                                                                                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| V4-0731, V4-0813, V4.1 | `temperature=1.0`; `top_p=0.95` for agentic use, `1.0` otherwise; V4.1 `max_tokens` at least 256K and 384K at `high`/`max` for 0731/0813 |
| V4 preview             | `temperature=1.0`, `top_p=1.0`                                                                                                           |
| V3.2                   | `temperature=1.0`, `top_p=0.95`                                                                                                          |
| R1 family              | `temperature=0.6` (0.5-0.7), `top_p=0.95`                                                                                                |

The DeepSeek API ignores `temperature`, `presence_penalty` and `frequency_penalty` in V4 thinking mode; vLLM applies them (issue 58155), so omit them rather than rely on that.

## llama.cpp

Upstream has the V4 architecture (PR 24162, merged 2026-06-29), DSpark (PR 25173), V4 MTP and DSpark drafting (PR 25784) and V4-Flash-Vision-Exp support (PR 28133). V4.1 is not upstream: PR 28696 is open. Use `--jinja` and the Unsloth template. DSpark on GGUF:

```bash
./llama-server -m DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00001-of-00004.gguf \
  -md dspark-DeepSeek-V4-Flash-0731-Q8_0.gguf \
  --spec-type draft-dspark --spec-draft-n-max 3 -ngl 99 -ngld 99 \
  --jinja --temp 1.0 --top-p 1.0 --min-p 0.01
```

Unsloth reports `--spec-draft-n-max 3` as a good default (1.9x) and larger values slower. Community GGUFs for V4 Flash built on forks may need the fork; check each card. Install and flags: the `llama-cpp` skill.

## Ollama

Only cloud tags were found: `deepseek-v4.1-flash:cloud` (vision, tools, thinking, 1M) and `deepseek-v4-flash:0731-cloud`. The plain `deepseek-v4-flash` page says it was retired on 2026-09-25. No local V4 tag found.

## MLX

mlx-lm merged V4.1 on `main` (PR 1895, 2026-09-29). Its latest tagged release read was v0.31.3 (April 2026), so install from `main` for V4.1. Community repos: `mlx-community/DeepSeek-V4.1-Flash-MLX-4bit` and `-MLX-2bit`. Open mlx-lm issues cover a `deepseek_dsml` tool parser (1337) and a Chinese-script drift in the mlx-vlm path (1404). Install and flags: the `mlx` skill.

## TensorFold

Not qualified: the TensorFold 1.0.7 README lists DeepSeek-V4 as "still under qualification for 1.0.x" and no DeepSeek model in its qualified table. No upstream support found for V4.1 or older DeepSeek.

## Legacy (R1, V3.x)

- **R1 and distills:** do not add a system prompt on the original R1 distills, put instructions in the user turn, use `temperature=0.6`, and for maths ask for step-by-step reasoning with the answer in `\boxed{}`. The card recommends forcing the response to start with `<think>\n` because the model sometimes emits an empty think block. R1-0528 and its Qwen3-8B distill support a system prompt. Use `--reasoning-parser deepseek_r1` on vLLM.
- **SGLang R1 detector:** original R1 always reasons without a `<think>` start tag; R1-0528 emits `<think>`.
- **V3.1:** reasoning is off by default; enable with `thinking=True` in `chat_template_kwargs`. Tool calling works in non-thinking mode.
- **V3.2-Speciale:** no tool calling.

## Sources

- <https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash/blob/main/encoding/README.md>
- <https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731/blob/main/encoding/README.md>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash>
- <https://github.com/vllm-project/vllm/blob/main/docs/features/tool_calling.md>
- <https://github.com/vllm-project/vllm/blob/main/docs/features/reasoning_outputs.md>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4_1>
- <https://unsloth.ai/docs/models/deepseek-v4>
- <https://github.com/NVIDIA/TensorRT-LLM/tree/main/examples/models/core/deepseek_v4>
- <https://github.com/ggml-org/llama.cpp/pull/24162>
- <https://github.com/ggml-org/llama.cpp/pull/28696>
- <https://github.com/ml-explore/mlx-lm/pull/1895>
- <https://ollama.com/library/deepseek-v4.1-flash>
- <https://github.com/ashhart/TensorFold>
