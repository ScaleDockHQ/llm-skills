# Known issues and gotchas

> Verified against GitHub issues in vllm-project/vllm and ggml-org/llama.cpp (state read 2026-10-11), Meta Muse Glimmer developer docs, vLLM tool-calling docs, 2026-10-11

Issue states change. Re-open the link before telling the user a bug is still present.

## Symptom to fix

| Symptom                                                                        | Cause                                                                                                         | Fix                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ValueError: model architectures ... are not supported` for Muse Glimmer       | vLLM older than v0.28.0 (support merged 2026-08-14)                                                           | Use `vllm/vllm-openai:v0.28.0` or newer, or Meta's `muse-glimmer` tag                                                                                                                               |
| `invalid tool call parser`                                                     | Hyphenated name `muse-glimmer`                                                                                | vLLM: `muse_glimmer` (underscore). SGLang: `muse`                                                                                                                                                   |
| `unknown model architecture: 'muse-glimmer'` in llama.cpp                      | Build b10344 or older                                                                                         | Use b10353 or newer; `llama-server --version` prints the build                                                                                                                                      |
| Muse tool calls appear as plain text                                           | No tool parser, or llama.cpp without `--jinja`                                                                | vLLM: `--enable-auto-tool-choice --tool-call-parser muse_glimmer`. llama.cpp: `--jinja`, no `--chat-template-file`                                                                                  |
| Muse reasoning leaks into `content`                                            | No reasoning parser                                                                                           | `--reasoning-parser muse_glimmer` (vLLM) or `muse` (SGLang); llama.cpp server splits it by default, `llama-cli` never does                                                                          |
| Empty `content` with `finish_reason: stop` or `length` from Muse               | `max_tokens` ended before the final channel closed                                                            | Raise `max_tokens`; lower `reasoning_strength`; stream                                                                                                                                              |
| Only the first Muse tool call runs                                             | Parallel calls arrive as consecutive assistant messages                                                       | Read every assistant message, not only `tool_calls[0]`                                                                                                                                              |
| Muse never stops or truncates mid-turn                                         | Wrong stop tokens, or stopping on `<\|eom\|>` (id 200007)                                                     | `eos_token_id = [200001, 200008]` via `--generation-config auto` / `--jinja`; never stop on `<\|eom\|>`                                                                                             |
| Flat, repetitive or non-reproducible Muse output                               | Greedy decoding                                                                                               | `temperature 1.0, top_p 0.95, top_k 64`. Greedy is also not reproducible on this model (identical `temperature 0` requests with a fixed seed returned 70, 80 and 86 completion tokens)              |
| `reasoning_effort: none` or `--reasoning off` does nothing on Muse (llama.cpp) | Template opens the thinking channel unconditionally                                                           | Use `chat_template_kwargs.reasoning_strength: low` and `--reasoning-budget N`                                                                                                                       |
| Muse OOM right after start                                                     | Sized to 60 GB weights instead of the 72 GB serving footprint                                                 | Lower `--max-model-len`, raise TP, or use FP8/NVFP4                                                                                                                                                 |
| Llama 4 tool calls land in `content`                                           | Parser/format mismatch: `llama4_pythonic` expects `[fn(a="b")]` but the checkpoint (notably FP8) emitted JSON | Use the pythonic template with the pythonic parser; if the model still emits JSON, try `llama3_json` with a JSON template and test. [vllm#46863](https://github.com/vllm-project/vllm/issues/46863) |
| Llama 3 parallel tool calls missing; arrays serialized as strings              | vLLM limitation for Llama 3 JSON parser                                                                       | Single calls; validate arguments client-side                                                                                                                                                        |

## Open issues worth knowing (state on 2026-10-11)

Muse Glimmer in vLLM:

- [#60580](https://github.com/vllm-project/vllm/issues/60580): xgrammar lets control tokens (`<|eom|>`, `<|start|>`, `<|message|>`) into JSON strings; the parser then silently truncates the answer.
- [#53469](https://github.com/vllm-project/vllm/issues/53469) and [#52594](https://github.com/vllm-project/vllm/issues/52594): structured outputs are not enforced when `--reasoning-parser muse_glimmer` is active. Do not rely on `response_format` JSON schema with reasoning on; validate output yourself.
- [#54453](https://github.com/vllm-project/vllm/issues/54453): decoding becomes quadratic under structured output.
- [#55395](https://github.com/vllm-project/vllm/issues/55395): the tool parser can leak incomplete ATEM markers when streaming.
- [#57941](https://github.com/vllm-project/vllm/issues/57941): speculative decoding hits an illegal memory access when the draft model's context is shorter than the target's.
- [#51884](https://github.com/vllm-project/vllm/issues/51884): FP8 block weights fail on sm120 (RTX 5090) with DeepGEMM; workaround `VLLM_USE_DEEP_GEMM=0 VLLM_MOE_USE_DEEP_GEMM=0`.

Muse Glimmer in llama.cpp:

- [#26894](https://github.com/ggml-org/llama.cpp/issues/26894): DFlash drafter fails to bind (`vector::_M_range_check`) with the official GGUF's `sliding_window_pattern` array.
- [#27178](https://github.com/ggml-org/llama.cpp/issues/27178): a Muse NVFP4 GGUF fails to load, then emits one repeated token. Use the vendor K-quant GGUFs.
- [#29982](https://github.com/ggml-org/llama.cpp/issues/29982): prompt processing speed halved with the DFlash draft after a later change.
- [#27023](https://github.com/ggml-org/llama.cpp/issues/27023): `reasoning_effort` reported as broken; Meta's docs say it is simply not implemented, use `reasoning_strength`.

Llama 4:

- [vllm#46863](https://github.com/vllm-project/vllm/issues/46863): FP8 Scout emits JSON tool calls that `llama4_pythonic` does not parse, so Claude Code (Anthropic Messages endpoint) sees no tool calls; a fix covers the non-streaming path only per the thread.
- [vllm#31624](https://github.com/vllm-project/vllm/issues/31624): ModelOpt Llama-4 checkpoints take 5+ minutes to load.

## Stale or conflicting upstream docs

| Claim                                                                                                                   | Reality on 2026-10-11                                                                                                        |
| ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Meta's vLLM page: "Muse Glimmer support is an open, unmerged pull request; `pip install vllm` doesn't serve this model" | PR #51655 merged 2026-08-14; vLLM v0.28.0 (2026-08-26) and later contain it. The vLLM recipe uses `vllm/vllm-openai:v0.28.0` |
| SGLang cookbook: "not in a release yet, build the PR branch"                                                            | PR #34262 merged 2026-08-11; v0.5.19 (2026-09-05) and later contain it                                                       |
| vLLM Llama 4 recipe variant sizes (BF16 262 GB, FP8 131 GB, NVFP4 65 GB) next to a "1x H100 (FP8)" prerequisite         | Internally inconsistent: check real memory                                                                                   |
| HF org still lists Llama 4 as "Current"                                                                                 | True as of 2026-10-11, but Meta's newest open model is Muse Glimmer in `meta-models`                                         |

## Gaps (not verified)

- Llama 4 prompt-format details (BOS, system-prompt placement): Meta's `prompt_format.md` was not retrievable; rely on the engine templates.
- Llama 4 on DGX Spark / GB10 and on Apple MLX: no upstream evidence found.
- Llama 4 acceptable-use policy EU clause for multimodal weights: not read.
- Muse Glimmer field name for reasoning strength in Ollama requests: not documented on the pages read.
- Llama 3.1 and 3.2 licenses and context lengths: not re-read.
