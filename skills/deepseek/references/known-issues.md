# DeepSeek known issues

> Verified against vLLM and SGLang GitHub issues (open on 2026-10-11), vLLM recipes, SGLang cookbook, Unsloth guide, 2026-10-11

Issue states change daily. Re-open the link before telling a user a bug is still present.

## Symptoms and first checks

| Symptom                                                      | Cause                                                                                                                                                                                                                                                       | Fix                                                                                                             |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `content` empty, `finish_reason=length`, model looks broken  | V4.1 on vLLM thinks by default (effort 50); a small `max_tokens` is spent on the trace                                                                                                                                                                      | Set `thinking: false` or raise `max_tokens` (vLLM V4.1 recipe)                                                  |
| `reasoning_content` always empty on SGLang V4.1              | Thinking is off by default                                                                                                                                                                                                                                  | Send `reasoning_effort` other than `none`, or set `SGLANG_DEFAULT_THINKING=1`                                   |
| Raw `<｜DSML｜...` in `content`                              | Tool-call parser missing or wrong version                                                                                                                                                                                                                   | `--tool-call-parser deepseek_v4` (V4) or `deepseek_v41` (V4.1) on vLLM; `deepseekv4` or `deepseekv41` on SGLang |
| SGLang leaks raw DSML with `tool_choice="none"`              | Open bug [SGLang 35736](https://github.com/sgl-project/sglang/issues/35736)                                                                                                                                                                                 | Do not rely on `tool_choice="none"`                                                                             |
| Streaming tool arguments arrive in one chunk                 | vLLM buffers long string parameters until `</parameter>`, [vLLM 52846](https://github.com/vllm-project/vllm/issues/52846); V4 parser against V4.1's spaced tags also drops argument deltas, [vLLM 58640](https://github.com/vllm-project/vllm/issues/58640) | Use the matching V4.1 parser; accept non-incremental long arguments                                             |
| DSpark enabled but no speedup, `accept rate: 0.00` on SGLang | `EAGLE` used on a checkpoint with a DSpark head                                                                                                                                                                                                             | `--speculative-algorithm DSPARK` for 0731, 0813, V4.1                                                           |
| `method: mtp` configured on 0731                             | 0731 has no MTP head (the recipe says not to use it)                                                                                                                                                                                                        | Use `dspark`                                                                                                    |
| Think Max truncated                                          | Context under 384K                                                                                                                                                                                                                                          | `--max-model-len >= 393216`                                                                                     |
| Prefix cache never hits on `/v1/messages`                    | Mid-conversation system messages hoisted without `--chat-template`, [vLLM 60537](https://github.com/vllm-project/vllm/issues/60537)                                                                                                                         | Pass the V4.1 `chat_template.jinja`                                                                             |
| V4.1 decode rate is a fraction of expectation on SGLang      | Backend flags overridden, forcing a Triton fallback                                                                                                                                                                                                         | Remove `--attention-backend`, `--moe-runner-backend`, `--fp8-gemm-backend`                                      |

## Open engine bugs worth knowing

| Engine    | Issue                                                                                                                  | Summary                                                                                                         |
| --------- | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| vLLM      | [60771](https://github.com/vllm-project/vllm/issues/60771)                                                             | V4-Flash-0731 repeats and emits garbled characters on 8xH20 with v0.31.0                                        |
| vLLM      | [53257](https://github.com/vllm-project/vllm/issues/53257)                                                             | Non-deterministic output at `temperature=0` on V4-Flash NVFP4 with DSpark; rate rises with concurrency          |
| vLLM      | [43416](https://github.com/vllm-project/vllm/issues/43416)                                                             | V4 Flash garbled output (filed 2026-08-12; read title only)                                                     |
| vLLM      | [58155](https://github.com/vllm-project/vllm/issues/58155)                                                             | `temperature`, `presence_penalty`, `frequency_penalty` are applied in V4 thinking mode, unlike the DeepSeek API |
| vLLM      | [59203](https://github.com/vllm-project/vllm/issues/59203)                                                             | V4.1-Flash fails on SM120 (RTX PRO 6000): no sparse-MLA decode kernel for `page_block_size=32`                  |
| vLLM      | [61040](https://github.com/vllm-project/vllm/issues/61040)                                                             | V4.1 crashes in decoder-replay CUDA graph with `--moe-backend flashinfer_moe_ep_*`                              |
| vLLM      | [57469](https://github.com/vllm-project/vllm/issues/57469)                                                             | V4.1-Flash on 4xH20 hits a host-memory (shmem) cgroup OOM during load                                           |
| vLLM      | [59609](https://github.com/vllm-project/vllm/issues/59609)                                                             | `--enable-eplb` never loads the redundant expert slots on V4 and V4.1                                           |
| vLLM      | [57144](https://github.com/vllm-project/vllm/issues/57144), [50576](https://github.com/vllm-project/vllm/issues/50576) | Ampere (A100/A800) not supported for V4.1 or V4 DSpark                                                          |
| vLLM      | [52065](https://github.com/vllm-project/vllm/issues/52065)                                                             | 8xH100 V4-Flash-0731 TP8+EP started on 0.26.0 and failed at startup on 0.27.0 (from the recipe)                 |
| SGLang    | [41076](https://github.com/sgl-project/sglang/issues/41076)                                                            | V4.1-Flash with DSPARK: unbounded sparse-prefill workspace allocation can OOM the whole TP group                |
| SGLang    | [42367](https://github.com/sgl-project/sglang/issues/42367)                                                            | SM120 V4.1 decode CUDA graph capture fails with FlashInfer 0.7.0                                                |
| SGLang    | Discussion [39791](https://github.com/sgl-project/sglang/discussions/39791)                                            | H100 is not a supported V4.1-Flash target; V4-Flash-0731 has a verified H100 recipe                             |
| llama.cpp | PR [28696](https://github.com/ggml-org/llama.cpp/pull/28696)                                                           | V4.1 not upstream yet                                                                                           |

## Version traps

- vLLM V4.1 needs the nightly Docker image (any nightly after 2026-09-10 per the recipe); there is no pip wheel for that architecture. V4 DSpark needs vLLM 0.25.0 or newer; ROCm DSpark 0.26.0 or newer.
- 0731 on RTX PRO 6000 (sm_120) with DSpark needs `vllm/vllm-openai:nightly` and a FlashInfer build with flashinfer-ai/flashinfer#4380.
- SGLang V4.1 has no release yet; the cookbook uses `lmsysorg/sglang:dev-dsv41`. Vision-Exp needs the preview image `lmsysorg/sglang:dev-dsv4-flash-vision`.
- SGLang V4.1 rejects `--enable-deterministic-inference`; output is not bitwise stable across batch composition.
- SGLang V4.1 decoder SWA bounded replay is not numerically equivalent to full prefill and refuses prompt logprobs.
- MI300X, MI325X and MI355X need ROCm-specific flags for V4.1 (`VLLM_USE_BREAKABLE_CUDAGRAPH`, `--no-swa-bounded-replay`, Engram CPU offload); follow the recipe.
- DSpark on AMD in vLLM V4.1 must disable adaptive verification.
- First V4.1 boot on a DGX Station ran a 75-90 minute FlashInfer autotune; mount `/root/.cache/vllm` on persistent storage.

## Format caveats

- Community GGUFs that re-quantize the MXFP4 experts are not equivalent to the official weights (Unsloth KLD measurements). Prefer `UD-Q8_K_XL` or `UD-Q4_K_XL`.
- GGUF for V4 loaded in vanilla llama.cpp before the V4 PRs needed forks; use a build from after 2026-08-02 (PR 25784) for DSpark.
- Base repos (`-Base`) are pre-training checkpoints. Do not serve them with a chat template or tool parser.

## Sources

- <https://github.com/vllm-project/vllm/issues/57448>
- <https://github.com/sgl-project/sglang/issues/42170>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4_1>
- <https://unsloth.ai/docs/models/deepseek-v4>
