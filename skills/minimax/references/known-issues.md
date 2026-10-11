# MiniMax known issues

> Verified against MiniMax-M2.7 vLLM and SGLang deploy guides, vLLM M3 recipe, SGLang M3 cookbook, TensorRT-LLM M3 guide, llama.cpp PR threads, Unsloth guides, MiniMax API docs, 2026-10-11

| Symptom                                                                                                  | Cause                                                      | Fix                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM: "MiniMax-M2 model is not currently supported"                                                      | Old vLLM                                                   | Upgrade vLLM. SGLang: use >= v0.5.4.post1.                                                                                                                                                   |
| vLLM M2 line: `torch.AcceleratorError: CUDA error: an illegal memory access was encountered`             | CUDA graph mode                                            | Add `--compilation-config '{"cudagraph_mode":"PIECEWISE"}'` (official M2.7 guide).                                                                                                           |
| vLLM M2 line: garbled output                                                                             | Old build                                                  | Upgrade; use a nightly newer than vLLM commit `cf3eacfe58fa9e745c2854782ada884a9f992cf7`.                                                                                                    |
| vLLM M3: crash `No common block size for 16`, or wrong sparse indexing                                   | KV block size left at default                              | Always pass `--block-size 128`.                                                                                                                                                              |
| M3 tool calls come back as text, or reasoning is mixed into content                                      | Using `minimax_m2` parsers for M3 (or the reverse)         | M3: `--tool-call-parser minimax_m3 --reasoning-parser minimax_m3`. M2 line: `minimax_m2` and `minimax_m2_append_think`.                                                                      |
| M3 OOM at long context on vLLM                                                                           | Full 1M window needs a large KV pool                       | Cap `--max-model-len`, add `--kv-cache-dtype fp8`, or scale to multi-node TP.                                                                                                                |
| M3 vLLM AMD: forced eager mode or slow decode                                                            | Breakable cudagraph path                                   | `export VLLM_USE_BREAKABLE_CUDAGRAPH=0`.                                                                                                                                                     |
| SGLang M3 multi-GPU start: `AttributeError: Module has no function 'plan'` at CUDA-graph capture         | Ranks racing to JIT-compile the MSA kernel on a cold cache | Run `python -c "from sglang.srt.layers.attention.minimax_sparse_ops.msa import msa_available; print(msa_available())"` once before launching. `SGLANG_DISABLE_MSA=1` forces the Triton path. |
| SGLang M3 ignores `top_k`                                                                                | `top_k` is not in `generation_config.json`                 | Send `top_k=40` per request.                                                                                                                                                                 |
| SGLang M3 requires an unreleased tag                                                                     | M3 shipped in PR #27944                                    | Use the `lmsysorg/sglang:dev-*minimax-m3` images or check your version loads the architecture.                                                                                               |
| TensorRT-LLM M3: `cudaErrorStreamCaptureUnsupported` / OOM at CUDA-graph capture                         | `max_seq_len` left at the checkpoint default (512K or 1M)  | Set a small `max_seq_len` just above input + output, as in the curated YAML.                                                                                                                 |
| TensorRT-LLM M3: KV reuse errors, or dense attention path missing                                        | Sparse path needs specific config                          | `kv_cache_config.enable_block_reuse: false`, `sparse_attention_config.algorithm: minimax_m3`. MTP is unsupported.                                                                            |
| TensorRT-LLM M3: reasoning not parsed                                                                    | Missing flags                                              | `--reasoning_parser minimax_m3 --tool_parser minimax_m3 --chat_template $MODEL/chat_template.jinja`; use `/v1/chat/completions`.                                                             |
| llama.cpp M2: `Unknown argument ensure_ascii for function tojson`                                        | Old minja or old GGUF template                             | Update llama.cpp or use a GGUF with a fixed template (Unsloth). Always pass `--jinja`.                                                                                                       |
| llama.cpp M2.7: crash with parallel `invoke` blocks (`Invalid diff: now finding less tool calls!`)       | Parser regression after the autoparser refactor            | PR #22106 was opened as the fix. Check your build includes it; unverified whether merged.                                                                                                    |
| Any engine: gibberish with CUDA 13.2                                                                     | CUDA bug reported by Unsloth                               | Use another CUDA version.                                                                                                                                                                    |
| M2 line agent quality collapses after a few turns                                                        | Client stripped the think block or `reasoning_details`     | Preserve the full assistant message; do not edit `content`. Only thinking from earlier user turns may be dropped by the template.                                                            |
| M3 template error "Message has tool role, but there was no previous assistant message with a tool call!" | Tool result without a preceding assistant `tool_calls`     | Send the assistant tool-call turn first, then the matching `tool` message.                                                                                                                   |

## Behavior notes

- M3 default thinking is `adaptive` when `thinking_mode` is unset. For agent loops set `enabled`; for latency set `disabled`.
- M3 on the hosted API: `thinking` accepts `enabled`, `adaptive`, `disabled` (M2.x ignores `disabled`). M3.1-Flash-Preview
  always thinks and rejects `disabled` with 400; it has no open weights.
- vLLM M3 NVFP4 needs a build including PR #46380 support; the NVIDIA card calls it "not yet in a stable release", while vLLM
  v0.31.0 release notes list M3 NVFP4 items. Verify with your image.
- MSA acceleration on llama.cpp: unclear. The Unsloth guide says unsupported (dense fallback); the merged llama.cpp PR title says MSA.

## Gaps (not verified on 2026-10-11)

- Whether SGLang stable v0.5.21 contains MiniMax-M3 without the dev images.
- M2.1 parameter count and license text, M2.5 license file contents beyond the model card.
- M3 MLX conversions, M3 on Apple Silicon and DGX Spark (no tested path found).
- Exact M3 think tag spelling in the tokenizer (`<mm:think>` taken from the vLLM recipe; the fetched template rendered blank token names).
- llama.cpp `--reasoning-format minimax-m2` existence, state of PR #22106 and vision PR #25113.
- H100 serving of M3 (listed by vLLM recipe, no validated command).
- SGLang per-request `thinking_mode` via `chat_template_kwargs`.
- TensorFold support (none found), Ollama local weights (none found).
- Legacy MiniMax-Text-01 / M1 sizes and serving details.

## Sources

- https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/docs/vllm_deploy_guide.md
- https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/docs/sglang_deploy_guide.md
- https://recipes.vllm.ai/MiniMaxAI/MiniMax-M3
- https://docs.sglang.io/cookbook/autoregressive/MiniMax/MiniMax-M3
- https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-minimax-m3-on-trtllm.html
- https://github.com/ggml-org/llama.cpp/pull/16831, https://github.com/ggml-org/llama.cpp/pull/22106
- https://unsloth.ai/docs/models/minimax-m27
- https://platform.minimax.io/docs/api-reference/text-openai-api
- https://huggingface.co/MiniMaxAI/MiniMax-M2/discussions/38
