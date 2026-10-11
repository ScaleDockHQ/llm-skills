# Kimi: known issues and gotchas

> Verified against vLLM issues 37184, 41182, 42426, 44906 and PRs 38579, 43155, 45003 (as quoted in their threads), vLLM K3 blog tips, vLLM K3 recipe, SGLang issue 37430, Kimi K3 and K2.6 model cards, Unsloth Kimi K3 page, 2026-10-11

Issue states change quickly. Re-open the linked item before relying on a "fixed in" line, and pin the engine version you tested.

## Tool calling

| Symptom                                                                                                     | Models / engine                                     | Cause and fix                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Tool-call markers (`<                                                                                       | tool_calls_section_begin                            | >`) leak into content, arguments cut at 8 KB, streaming drops content, schema accuracy about 87%                                                                                                                                                                         | K2.5, K2-0905, vLLM 0.16 to 0.19 | Issue 37184; the thread reports it fully fixed since vLLM 0.20.0 by PR 38579 (streaming parser rewrite). Upgrade to vLLM >= 0.20.0 |
| Streaming tool calls return only the text before the call (issue 41182, vLLM 0.18.0)                        | K2.5                                                | Maintainer reply: fixed upstream in v0.20.0                                                                                                                                                                                                                              |
| `tool_choice` set to `required` or a named function yields malformed arguments (raw markers in `arguments`) | K2.6, vLLM `kimi_k2` parser                         | Issue 44906; forced tools bypassed the Kimi-native parser. PR 43155 was closed as superseded by PR 45003, which sets a Kimi structural tag. Use a vLLM build that includes PR 45003 (check it is merged: not verified here) or avoid forced `tool_choice` and use `auto` |
| Empty `tool_calls` although the model "called" a tool                                                       | K3, vLLM                                            | vLLM blog: K3 occasionally emits a format the parser does not expect; validate against your schema, retry or fall back, consider strict/structured tool calling                                                                                                          |
| `tool_choice="required"` requests hang until client timeout (120 s in the report)                           | K3, SGLang, 2P2D PD-disaggregated, TP8/DCP8, DSPARK | SGLang issue 37430. Dynamic-tool variants also hang. Test forced tool choice before shipping a disaggregated deployment                                                                                                                                                  |
| No tool calls on Ascend NPU                                                                                 | K3, SGLang                                          | Cookbook: tool-call parser not yet supported on the A3 and A5 recipes                                                                                                                                                                                                    |

## Wrong or empty output

- **Reasoning field is only `!!!!!!!!!!`, `content` null (intermittent).** K2.6 and `RedHatAI/Kimi-K2.6-NVFP4` on Blackwell (issue 42426). Reporters point at the `FLASHINFER_MLA` attention backend (NaN logits); they report that `TOKENSPEED_MLA` works, with `--kv-cache-dtype fp8` (without it the backend refused to start), and suggest `TRITON_MLA` or other compatible MLA backends would also work (untested by them). The vLLM K2.6 recipe uses `--attention-backend TOKENSPEED_MLA` on B300. Note the K3 DSpark speculative config in the vLLM blog names `FLASHINFER_MLA` for the draft: that is upstream's tested K3 recipe, not a contradiction for K2.6.
- **Low benchmark scores or cut-off answers.** K3 thinks a lot. vLLM: raise `reasoning_effort`, set `max_tokens` generously, check for truncation before debugging anything else. Evals in the K3 card use `reasoning_effort` `max`.
- **Thinking disappears across turns or quality drops in agents.** K3 requires the full assistant message (`reasoning_content` and `tool_calls`) in later requests; K2.7-Code forces preserved thinking; K2.6 needs `preserve_thinking` opted in. Do not strip reasoning in a gateway or client.
- **Instant mode request has no effect.** K3 and K2.7-Code have no instant mode. For K2.6/K2.5 the vLLM key is `chat_template_kwargs.thinking=false`; llama.cpp uses `enable_thinking`.

## Engine and install

| Topic                            | Detail                                                                                                                                                      |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| K3 on vLLM needs Docker images   | Pre-release dependencies (FlashInfer); pip install is not usable "now" per the 2026-07-27 blog. Image from the recipes page                                 |
| K3 prefix caching off by default | Pass `--enable-prefix-caching`. KDA state checkpoints are controlled by `VLLM_PREFIX_CACHE_RETENTION_INTERVAL`                                              |
| K3 engine readiness              | Recipe sets `VLLM_ENGINE_READY_TIMEOUT_S=3600`; loading a 1.56 TB checkpoint is slow (use `--load-format fastsafetensors`)                                  |
| K3 TensorRT-LLM                  | Blackwell SM100 only and built from source; no MTP or EAGLE-3 head (DSpark instead)                                                                         |
| Vision encoder under TP          | K3's ViT has `head_size=12`, cannot shard evenly at TP8; vLLM defaults `--mm-encoder-tp-mode=data`. K2.6 recipe also recommends `--mm-encoder-tp-mode data` |
| Multimodal cache cost            | Unique inputs: `--mm-processor-cache-gb 0`; repeated inputs: `--mm-processor-cache-type shm` (K2.6 recipe)                                                  |
| `transformers` 5.x               | K2.5/K2.6/K2.7-Code cards require `>=4.57.1, <5.0.0`                                                                                                        |
| Video input                      | K2.6/K2.7-Code cards: video chat is experimental and only supported in Moonshot's official API for now, not vLLM/SGLang                                     |
| AMD MI350X/MI355X, K2.6          | Needs `--moe-backend flydsl`, `--compilation-config '{"pass_config": {"fuse_allreduce_rms": false}}'`, no `--enable-expert-parallel` (recipe)               |

## Local and quantized runs

- **llama.cpp needs a recent build or Unsloth's fork for K3 vision.** K3 text support is upstream (commit ad1de39); Unsloth's vision support lives in its fork branch, and Unsloth had to raise an internal `n_tokens * 40` budget to `* 160` at large batch sizes.
- **Third-party K3 GGUFs vary hugely.** Unsloth reports some similarly sized community K3 quants with perplexity 21-45x worse than its own. Compare PPL/KLD before trusting a quant.
- **Ollama is cloud-only for Kimi.** `kimi-k2.6:cloud` and `kimi-k3:cloud` proxy to Ollama's service and nothing runs locally; `kimi-k2.5` was retired on 2026-07-31.
- **Kimi-Linear needs `fla-core >= 0.4.0`** on the Transformers path and a llama.cpp build with the `kimi-linear` arch.
- **NVFP4 K3 is not calibrated.** NVIDIA's card says it was converted "without calibration data", with attention weights in 128x128 block FP8.
- **Throughput expectations.** vLLM reports 111 tok/s per user on TP8 and 118 on TP16 at batch size 1 for K3 on GB300 NVL72, and 331-370 tok/s with DSpark; these are datacenter numbers.

## License gotchas

- K3's licence has a "Model as a Service" revenue clause that K2.x's Modified MIT does not. A hosting provider above 20M USD revenue (over 12 months) needs a separate agreement unless it is a Moonshot-certified inference partner. See `models.md`.

## Sources

- https://github.com/vllm-project/vllm/issues/37184 , https://github.com/vllm-project/vllm/issues/41182 , https://github.com/vllm-project/vllm/issues/42426 , https://github.com/vllm-project/vllm/issues/44906
- https://github.com/vllm-project/vllm/pull/38579 , https://github.com/vllm-project/vllm/pull/43155
- https://github.com/sgl-project/sglang/issues/37430
- https://github.com/vllm-project/vllm-project.github.io/blob/main/_posts/2026-07-27-k3.md
- https://recipes.vllm.ai/moonshotai/Kimi-K3 , https://recipes.vllm.ai/moonshotai/Kimi-K2.6
- https://unsloth.ai/docs/models/kimi-k3
- https://huggingface.co/nvidia/Kimi-K3-NVFP4
- https://ollama.com/library/kimi-k3:cloud
