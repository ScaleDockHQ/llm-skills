# MiniMax parsers and templates

> Verified against MiniMax-M3 chat_template.jinja, vLLM v0.31.0 and the vLLM M3 recipe, SGLang cookbook (M3) and MiniMax-M2.7 deploy guides, TensorRT-LLM M3 deployment guide, llama.cpp PRs #16946/#24908/#22106, MiniMax API docs, 2026-10-11

## Two families, two formats

|                       | M2 line (M2, M2.1, M2.5, M2.7)                                                                                                  | M3                                                                                                                                                                                                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Role tokens           | `]~!b[]~b]system`, `]~b]user`, `]~b]ai`, `]~b]tool`, end `[e~[`                                                                 | same family; M3 adds a `developer` role and an image/video token (`]<]image[>[`, `]<]video[>[`)                                                                                                                                                                       |
| Tool-call format      | `<minimax:tool_call><invoke name="f"><parameter name="k">v</parameter></invoke></minimax:tool_call>`                            | namespace-token XML: `]<]minimax[>[<tool_call>` wrapping `]<]minimax[>[<invoke name="f">` and `]<]minimax[>[<k>v]<]minimax[>[</k>`; nested objects and arrays expand recursively                                                                                      |
| Thinking tag          | `<think>...</think>`; the generation prompt pre-opens `<think>`                                                                 | `<mm:think>` block (vLLM recipe: "the `<mm:think>` block"); the generation prompt depends on `thinking_mode`                                                                                                                                                          |
| Thinking control      | always on; API ignores `thinking: disabled`                                                                                     | `thinking_mode` template variable: `enabled`, `adaptive` (default when unset), `disabled`                                                                                                                                                                             |
| Reasoning in history  | keep it (interleaved thinking); the official template drops thinking of earlier user turns and keeps it inside the current turn | template renders thinking for every assistant turn ("all-turn visible"); pass `reasoning_content` back                                                                                                                                                                |
| Default system prompt | "You are a helpful assistant. Your name is MiniMax-M2.7 and is built by MiniMax."                                               | template default: "You are a helpful assistant." as the developer message, with a built-in system header naming MiniMax-M3 and a thinking-instructions block; Unsloth and vLLM quote "You are a helpful assistant. Your name is MiniMax-M3 and was built by MiniMax." |
| Sampling              | `temperature=1.0`, `top_p=0.95`, `top_k=40`                                                                                     | same (the M3 card lists only temperature and top_p; vLLM and Unsloth add `top_k=40`)                                                                                                                                                                                  |

M3 system handling: a `root` message becomes the high-priority system block; `system` or `developer` messages
become the lower-priority developer block; with only a `system` message you still get the default system header.
Tool JSON schemas are rendered into the developer block. The role name is `ai` for the assistant. BOS is `]~b]`
with a leading `]~!b[` on the system turn, EOS is `[e~[`. Verify the actual token strings of your checkpoint:

```bash
# Read-only: show template-relevant tokens and the declared architecture
jq -r '.added_tokens_decoder | to_entries[] | select(.value.content|test("think|minimax|\\]~|\\[e~")) | .value.content' "$MODEL_DIR/tokenizer_config.json" 2>/dev/null | head -20
jq -r '.architectures[0]' "$MODEL_DIR/config.json"
```

## Thinking toggles

| Where                                                                         | How                                                                                                                                                                                                                                                                                                                          |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M3 any OpenAI-compatible engine honoring `chat_template_kwargs` (vLLM recipe) | `extra_body={"chat_template_kwargs": {"thinking_mode": "enabled"}}`. `disabled` prefixes the generation with the end-think token; `adaptive` lets the model decide; `enabled` opens the think block. The vLLM `minimax_m3` reasoning parser reads the same value so `reasoning` and `content` split correctly in every mode. |
| vLLM server default                                                           | `--default-chat-template-kwargs '{"thinking_mode":"enabled"}'` (used in the vLLM recipe benchmark lane)                                                                                                                                                                                                                      |
| M3 hosted API                                                                 | `thinking: {"type": "enabled"                                                                                                                                                                                                                                                                                                | "adaptive" | "disabled"}`. This is the API field, not the template variable. |
| SGLang M3                                                                     | reasoning is split with `--reasoning-parser auto`; the cookbook benchmarks use "chat with `--thinking`". Per-request `thinking_mode` through `chat_template_kwargs` is expected from the template but the SGLang page does not show it: unverified.                                                                          |
| M2 line                                                                       | no off switch (thinking cannot be disabled; the API accepts and ignores `disabled`).                                                                                                                                                                                                                                         |
| Output split (hosted API)                                                     | `reasoning_split=true` puts thinking in `reasoning_details`; false keeps it inside `content` as tags. Pass the whole assistant message back either way.                                                                                                                                                                      |

## vLLM (stable v0.31.0 on 2026-10-05; M3 support landed in v0.24.0)

The vLLM recipe page still says M3 is not in a stable release and shows `vllm/vllm-openai:minimax-m3`; the
release notes show M3 support since v0.24.0, so a current stable image should work. NVFP4 M3 needs a build
with PR #46380 (NVIDIA card); vLLM release notes list "MiniMax-M3 ModelOpt NVFP4 support (#46756)" and a later
"MiniMax-M3 NVFP4 inference" fix (#48929), so use a recent stable image.
Confirm with `vllm --version` and the flag help.

| Flag                        | M3                                                        | M2 line                                                                              |
| --------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `--tool-call-parser`        | `minimax_m3`                                              | `minimax_m2`                                                                         |
| `--reasoning-parser`        | `minimax_m3`                                              | `minimax_m2_append_think` (keeps the think tag inside `content`, as the model needs) |
| `--enable-auto-tool-choice` | required for tool calling                                 | required                                                                             |
| `--block-size 128`          | mandatory on every platform (MSA index cache)             | not used                                                                             |
| `--trust-remote-code`       | needed for the NVFP4 and MXFP4 checkpoints in the recipes | in the official guide                                                                |
| `--tensor-parallel-size`    | 8 on H200 for BF16                                        | 4 (96 GB cards) or 8 with `--enable_expert_parallel`                                 |
| `--max-model-len`           | cap it, e.g. `131072`; default auto-fit                   | cap; per-sequence max 196K                                                           |
| `--kv-cache-dtype fp8`      | "about 1.5x KV pool, lossless in our testing" (recipe)    | not documented in the M2 guide                                                       |
| `--language-model-only`     | skips the vision encoder (text-only workloads)            | n/a                                                                                  |

```bash
# M3 BF16 on 8x H200 (vLLM recipe, "verified on NVIDIA H200")
vllm serve MiniMaxAI/MiniMax-M3 \
  --tensor-parallel-size 8 --block-size 128 --max-model-len 131072 \
  --tool-call-parser minimax_m3 --reasoning-parser minimax_m3 --enable-auto-tool-choice

# M3 NVFP4 on Blackwell (NVIDIA card; needs a build with M3 NVFP4 support)
vllm serve nvidia/MiniMax-M3-NVFP4 --tensor-parallel-size 8 --block-size 128 \
  --tool-call-parser minimax_m3 --reasoning-parser minimax_m3 --enable-auto-tool-choice

# M2.7, 8 GPUs (official guide)
SAFETENSORS_FAST_GPU=1 vllm serve MiniMaxAI/MiniMax-M2.7 --trust-remote-code \
  --enable_expert_parallel --tensor-parallel-size 8 \
  --enable-auto-tool-choice --tool-call-parser minimax_m2 --reasoning-parser minimax_m2_append_think
```

M3 extras from the recipe: expert parallel (`--enable-expert-parallel`), `--mm-encoder-tp-mode data`,
`--mm-processor-cache-type shm` for vision, and EAGLE3 with `--speculative-config
'{"method":"eagle3","model":"Inferact/MiniMax-M3-EAGLE3-GQA","num_speculative_tokens":3,...}'`. On AMD set
`VLLM_USE_BREAKABLE_CUDAGRAPH=0` and `--attention-backend TRITON_ATTN`.

## SGLang (stable v0.5.21 listed on 2026-10-11)

The M3 cookbook says M3 ships in SGLang PR #27944 and was "not yet in a tagged release" when written; use the
`lmsysorg/sglang:dev-cu13-minimax-m3`, `dev-cu12-minimax-m3` (Hopper) or `dev-minimax-m3` images, or check that your
installed version knows `MiniMaxM3SparseForConditionalGeneration`. Whether 0.5.21 contains it is unverified.

| Flag                    | M3                                                                                                | M2 line                    |
| ----------------------- | ------------------------------------------------------------------------------------------------- | -------------------------- |
| `--tool-call-parser`    | `auto` (detects from the chat template)                                                           | `minimax-m2`               |
| `--reasoning-parser`    | `auto` (returns `reasoning_content`)                                                              | `minimax-append-think`     |
| `--trust-remote-code`   | required                                                                                          | in the guide               |
| `--tp` / `--tp-size`    | `--tp 8` B200 and H200 BF16; `--tp 4` B300/GB300 MXFP8                                            | 4, or 8 with `--ep-size 8` |
| `--attention-backend`   | `fa4` on Blackwell (MSA kernel `fmha_sm100`, page size forced to 128); FlashAttention-3 on Hopper | default                    |
| `--mem-fraction-static` | 0.65 B200, 0.75 B300/GB300, 0.80 AMD                                                              | 0.85 in the guide          |

```bash
# M2.7, 4 GPUs (official guide)
python -m sglang.launch_server --model-path MiniMaxAI/MiniMax-M2.7 --tp-size 4 \
  --tool-call-parser minimax-m2 --reasoning-parser minimax-append-think \
  --trust-remote-code --mem-fraction-static 0.85 --host 127.0.0.1 --port 8000
```

SGLang applies `temperature` 1.0 / `top_p` 0.95 from `generation_config.json`; send `top_k=40` per request.

## TensorRT-LLM

|                  | M3                                                                                                                                 | M2 / M2.1 / M2.7                                        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Architecture     | `MiniMaxM3SparseForConditionalGeneration` (text, image, video), `MiniMaxM3SparseForCausalLM` (text only)                           | `MiniMaxM2ForCausalLM`                                  |
| Precisions       | BF16 and MXFP8 only (MXFP8 is dequantized on load); NVFP4 and FP8 serving not supported                                            | FP8 block scales tested in CI; attention DP recommended |
| Required config  | `sparse_attention_config.algorithm: minimax_m3`; `kv_cache_config.enable_block_reuse: false`; no MTP; cap `max_seq_len`            | none specific                                           |
| Serve flags      | `--reasoning_parser minimax_m3 --tool_parser minimax_m3 --chat_template $MODEL/chat_template.jinja --extra_llm_api_options <yaml>` | model-specific parser flags not documented here         |
| Reference config | `examples/configs/curated/minimax-m3-throughput.yaml`; documented topology is 2 nodes x 4 GB200                                    | n/a                                                     |

Use `/v1/chat/completions`, not `/v1/completions`: only chat applies the template and parsers.

## llama.cpp

- **M2 line:** use a recent build with `--jinja`. The M2 chat template and XML tool-call handling landed in
  PR #16946 (reasoning kept in context, non-interleaved) and a specialized parser PR #22106 (tool calls with
  multiple `invoke` blocks) was opened as a fix for a crash regression. Check its status in your build.
  Old GGUF templates containing `tojson(ensure_ascii=False)` failed in minja; use a current GGUF/template.
  Whether `--reasoning-format minimax-m2` exists in your build: unverified (it was proposed in the PR thread);
  check `llama-server --help`.
- **M3:** merged as PR #24908 on 2026-07-26 (text; vision was a separate PR #25113, status unverified). Unsloth's
  guide (written earlier) says its experimental GGUFs are text-only and "MiniMax Sparse Attention is not supported
  yet, so inference falls back to dense attention", so keep `--ctx-size` modest. Re-read that guide against your build.
- Sampling: `--temp 1.0 --top-p 0.95 --top-k 40` (Unsloth also uses `--min-p 0.01` for the server).

```bash
llama-server --model MiniMax-M2.7-UD-IQ4_XS-00001-of-00004.gguf --jinja \
  --temp 1.0 --top-p 0.95 --top-k 40 --ctx-size 32768 --host 127.0.0.1 --port 8001
```

Avoid CUDA 13.2 for any model: Unsloth reports gibberish output.

## TensorFold and Ollama

- **TensorFold v1.0.7:** the README has no MiniMax entry. Not qualified; no upstream support found.
- **Ollama:** only cloud tags exist (`minimax-m3:cloud`, `minimax-m2.7:cloud`); no local weights in the library. For local
  use, run GGUF through llama.cpp (`local-llms` skill) instead.
- **MLX:** `mlx-lm` loads `mlx-community/MiniMax-M2.7-4bit` and applies its template; see `platforms-and-quants.md`.

## Client rules

- Keep the full assistant message (including `reasoning_content`/`reasoning`, or the `<think>` text inside `content`
  for the M2 append-think parsers) in the next request. Do not post-process the content.
- Request `tools` in the OpenAI format; tool results go back as `tool` messages. M3 template raises
  "Message has tool role, but there was no previous assistant message with a tool call!" if a tool message has no preceding call.
- vLLM exposes the M3 trace as `message.reasoning`; SGLang and TensorRT-LLM use `reasoning_content`.

## Sources

- https://huggingface.co/MiniMaxAI/MiniMax-M3/blob/main/chat_template.jinja
- https://recipes.vllm.ai/MiniMaxAI/MiniMax-M3
- https://github.com/vllm-project/vllm/releases
- https://docs.sglang.io/cookbook/autoregressive/MiniMax/MiniMax-M3
- https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/docs/vllm_deploy_guide.md
- https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/docs/sglang_deploy_guide.md
- https://github.com/MiniMax-AI/MiniMax-M2.7/blob/main/docs/tool_calling_guide.md
- https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-minimax-m3-on-trtllm.html
- https://nvidia.github.io/TensorRT-LLM/latest/models/supported-models.html
- https://github.com/ggml-org/llama.cpp/pull/16946, https://github.com/ggml-org/llama.cpp/pull/24908, https://github.com/ggml-org/llama.cpp/pull/22106
- https://platform.minimax.io/docs/api-reference/text-openai-api
- https://platform.minimax.io/docs/guides/text-m3-function-call
- https://huggingface.co/MiniMaxAI/MiniMax-M2/discussions/38
- https://github.com/ashhart/TensorFold
