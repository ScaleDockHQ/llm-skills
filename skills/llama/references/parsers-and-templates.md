# Chat templates, parsers and toggles

> Verified against vLLM v0.31.0 (tool-calling docs, Muse Glimmer and Llama 4 recipes), SGLang v0.5.21 (tool parser docs, Muse Glimmer cookbook), llama.cpp b11556 (Meta llama.cpp guide), Ollama v0.40.3, TensorRT-LLM 1.3.0rc29, TensorFold 1.0.7, 2026-10-11

## Formats at a glance

|                     | Muse Glimmer 30B                                                                                      | Llama 4 Scout / Maverick                                          | Llama 3.1 / 3.2 / 3.3                          |
| ------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------- |
| Turn framing        | `<\|start\|>role to=recipient<\|message\|>...<\|eot\|>`                                               | `<\|header_start\|>role<\|header_end\|>\n\n...<\|eot\|>`          | Llama 3 header tokens (template from the repo) |
| Reasoning           | Channel `to=self` written before the answer, always on                                                | None                                                              | None                                           |
| Tool-call format    | XML-style **ATEM** (`<atem:function_calls>`, `<atem:invoke name=...>`), one call per turn             | **Pythonic** list `[fn(arg="x")]` recommended; JSON also possible | JSON (`llama3_json`) or pythonic for 3.2/3.3   |
| Parallel tool calls | No                                                                                                    | Yes with `llama4_pythonic` (per vLLM docs)                        | No for Llama 3 in vLLM                         |
| Template ships with | Checkpoint (`chat_template.jinja`); also embedded in the GGUF                                         | Checkpoint, but engines ship better tool templates                | Checkpoint plus engine templates               |
| Stop tokens         | `eos_token_id = [200001 <\|end_of_text\|>, 200008 <\|eot\|>]`. **Never stop on `<\|eom\|>` (200007)** | `<\|eot\|>`                                                       | per card                                       |
| Sampling            | `temperature 1.0, top_p 0.95, top_k 64`, never greedy                                                 | `temperature 0.6, top_p 0.9, min_p 0.01` (Unsloth, quoting Meta)  | per card                                       |

Sources: [Muse prompting guide](https://dev.meta.ai/docs/muse-glimmer/prompting), [Muse model card](https://huggingface.co/meta-models/Muse-Glimmer-30B), [Unsloth Llama 4 guide](https://unsloth.ai/docs/models/tutorials/llama-4-how-to-run-and-fine-tune), [vLLM tool calling](https://docs.vllm.ai/en/latest/features/tool_calling/).

Always build prompts with `apply_chat_template` (or the server's chat endpoint). Hand-built Muse prompts degrade output. BOS for Muse is `<|begin_of_text|>`; the rendered Muse prompt also contains a system block with the reasoning-strength line and `# Valid recipients: "self", "user".`. Use `transformers` 5.15 or later for Muse, which has the native path (older versions prompt for `trust_remote_code`). For Llama 4, Meta's prompt-format page was not retrievable on the writing date, so BOS and system-prompt handling come from the engine templates: do not hand-build.

## Muse Glimmer

### vLLM

Support merged upstream on 2026-08-14 (PR #51655), which is before v0.28.0, so any release image from `vllm/vllm-openai:v0.28.0` onward carries it (checked with the GitHub compare API; latest release is v0.31.0). Meta's docs still say "unmerged, use `vllm/vllm-openai:muse-glimmer`": that is stale, but the tag still exists on that page. Prefer a pinned release tag.

```bash
docker run --rm --gpus all --ipc=host -p 8000:8000 \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  vllm/vllm-openai:v0.31.0 meta-models/Muse-Glimmer-30B \
  --served-model-name muse-glimmer \
  --tensor-parallel-size 1 \
  --enable-auto-tool-choice \
  --tool-call-parser muse_glimmer \
  --reasoning-parser muse_glimmer \
  --generation-config auto
```

| Flag                                                                                                                                                    | Why                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `--tool-call-parser muse_glimmer`                                                                                                                       | Underscore, not hyphen (`invalid tool call parser` otherwise). Converts ATEM to OpenAI `tool_calls`                   |
| `--reasoning-parser muse_glimmer`                                                                                                                       | Moves the `to=self` channel to `message.reasoning` (streaming: `delta.reasoning`). Forces `skip_special_tokens=False` |
| `--generation-config auto`                                                                                                                              | Loads published sampling and the two EOS ids                                                                          |
| no `--chat-template`                                                                                                                                    | The checkpoint's template is correct                                                                                  |
| `--max-model-len N`                                                                                                                                     | Cap to save KV memory; recipe uses 131072 at TP=4                                                                     |
| `--speculative-config '{"method": "dflash", "model": "meta-models/Muse-Glimmer-30B-assistant", "num_speculative_tokens": 15}'` with `--max-num-seqs 32` | DFlash drafting; 15 is fixed (block size 16), needs the matching draft head                                           |

Parallel tool calls arrive as consecutive assistant messages, not several entries in one `tool_calls` array: harnesses that read only `tool_calls[0]` drop work. Stream long reasoning requests. Recipe: <https://recipes.vllm.ai/meta-models/Muse-Glimmer-30B>, Meta page: <https://dev.meta.ai/docs/muse-glimmer/vllm>.

### SGLang

Merged 2026-08-11 (PR #34262), which is before v0.5.19 (2026-09-05), so release v0.5.19 or newer contains it. The SGLang cookbook still tells you to build the PR branch or use `lmsysorg/sglang:dev-muse-glimmer`; treat that as stale and check `sglang serve --help` after upgrading.

```bash
sglang serve --model-path meta-models/Muse-Glimmer-30B --served-model-name muse-glimmer \
  --reasoning-parser muse --tool-call-parser muse --mem-fraction-static 0.85 \
  --host 127.0.0.1 --port 30000
```

Parser names are `muse` (both flags), not `muse_glimmer`. Reasoning arrives as `message.reasoning_content`. Image input needs the BF16 checkpoint; add `--language-model-only` for text-only to free vision memory. GGUF in SGLang is text only and "not optimized"; MLX artifacts need `SGLANG_USE_MLX=1`, `--disable-radix-cache` and Macs with 48 GB or more. Cookbook: <https://docs.sglang.io/cookbook/autoregressive/Meta/MuseGlimmer>.

### llama.cpp

Support landed in PR #26841 (commit `62bf73d25`), first release **b10353**; older builds fail with `unknown model architecture: 'muse-glimmer'`. Current build on the writing date is b11556.

```bash
llama-server -m Muse-Glimmer-30B-KQuant-17GB-Q4_K_M.gguf \
  --mmproj mmproj-Muse-Glimmer-30B-Q4_K_M.gguf \
  -a muse-glimmer -ngl 99 -c 131072 -np 1 \
  --host 127.0.0.1 --port 8080 --jinja \
  --chat-template-kwargs '{"reasoning_strength":"low"}'
# speculative: -md dflash-Muse-Glimmer-30B-Q4_K_M.gguf --spec-type draft-dflash -ngld 99 --spec-draft-n-max 4
```

| Topic               | Behavior                                                                                                                                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--jinja`           | Required. Uses the template embedded in the GGUF and selects the ATEM tool parser by template detection. Do not pass `--chat-template-file`                                                                            |
| Reasoning toggle    | `chat_template_kwargs.reasoning_strength` (`low` / `medium` / `high` / `xhigh`), server-wide or per request. `reasoning_effort` is **not** implemented. Reasoning cannot be turned off; `--reasoning-budget N` caps it |
| Reasoning output    | `message.reasoning_content` by default; `--reasoning-format none` keeps it inline. `llama-cli` always prints it inline                                                                                                 |
| Context             | `-np N` divides `-c` N ways. Check `n_ctx_slot` in the log; use `-c 524288 -np 4` for four 131072 slots                                                                                                                |
| Stale GGUF metadata | If the log says `exceeds the training context ... - capping`, fix with `gguf-py/gguf/scripts/gguf_set_metadata.py <model>.gguf muse-glimmer.context_length 131072`                                                     |
| CLI                 | `llama-cli ... --jinja -st`; images need `llama-mtmd-cli`                                                                                                                                                              |

Source: <https://dev.meta.ai/docs/muse-glimmer/llama-cpp>.

### Ollama

`ollama run muse-glimmer` (GGUF) or `ollama run muse-glimmer:30b-mlx` on Apple Silicon (MLX engine with DFlash and image input). Reasoning strengths `low` to `xhigh` are supported per the [Ollama blog](https://ollama.com/blog/muse-glimmer); the exact request field was not documented on the pages read, so test it. `ollama launch claude|opencode|hermes|openclaw|pi --model muse-glimmer` wires up agent tools.

### TensorRT-LLM and Edge-LLM

Muse Glimmer is **not** in the TensorRT-LLM supported-models page. It is supported by NVIDIA **TensorRT Edge-LLM** (`model_type: muse_glimmer`, FP16 text/image/video, `RadixArk/Muse-Glimmer-NVFP4` text only, DFlash and DFlash2 drafts): `tensorrt-edgellm-serve meta-models/Muse-Glimmer-30B --cache-dir <dir> --speculative-config '{"method":"dflash","model":"meta-models/Muse-Glimmer-30B-assistant"}'`. See [supported models](https://nvidia.github.io/TensorRT-Edge-LLM/latest/user_guide/getting_started/supported-models.html).

### TensorFold

Not qualified. TensorFold 1.0.7's qualified list names Nemotron 3.5 Lightning, Qwen3.8 Flash Next, GLM-5.3-Flash and Qwen3.5-2B; Muse Glimmer and Llama are not on it. TensorFold publishes MLX conversions of Muse Glimmer on Hugging Face, but those are for MLX-VLM (needs MLX-VLM source at or after commit `5262cb6`, version 0.6.12), not for the TensorFold runtime. See `self-hosted-llms` `references/engine-tensorfold.md`.

## Llama 4

### vLLM

```bash
vllm serve meta-llama/Llama-4-Scout-17B-16E-Instruct \
  --tensor-parallel-size 8 --max-model-len 131072 \
  --enable-auto-tool-choice --tool-call-parser llama4_pythonic \
  --chat-template examples/tool_chat_template_llama4_pythonic.jinja
```

The vLLM tool-calling page says: for Llama 4 use `--tool-call-parser llama4_pythonic --chat-template examples/tool_chat_template_llama4_pythonic.jinja`. The older `pythonic` parser is also listed for Scout and Maverick. `llama3_json` also lists Llama 4 as supported (JSON format; the generic template is `examples/tool_chat_template_llama3.1_json.jinja`). The recipe's base command (vLLM 0.12.0 or newer) is `vllm serve ... --tensor-parallel-size 8 --async-scheduling --no-enable-prefix-caching --max-num-batched-tokens 8192`; on AMD `--max-num-seqs 64 --max-model-len 32000` and `VLLM_ROCM_USE_AITER=1`. Scout is released as BF16; FP4 is Blackwell-only (compute capability 10.0, B200/GB200) per the recipe, use FP8 on Hopper. The `--max-model-len` above is an example: size it to the KV cache you can afford, not to the 10M card number. Sources: [tool calling](https://docs.vllm.ai/en/latest/features/tool_calling/), [recipe](https://recipes.vllm.ai/meta-llama/Llama-4-Scout-17B-16E-Instruct).

### SGLang

Tool parser options for Llama: `llama3` (3.1), `pythonic` (3.2, 3.3 and 4) and `llama4` (listed for Scout). SGLang recommends `--tool-call-parser pythonic --chat-template=examples/chat_template/tool_chat_template_llama4_pythonic.jinja` for Llama 4 and warns that tool calling may fail without the right template; it also notes the feature is "still under development on Blackwell". Source: [SGLang tool parser](https://docs.sglang.io/docs/advanced_features/tool_parser). Which of `pythonic` or `llama4` is better for Scout was not benchmarked: test both on your tool set.

### llama.cpp and Ollama

Unsloth's GGUFs run in llama.cpp. Unsloth's published settings: `--temp 0.6 --min-p 0.01 --top-p 0.9`, `--ctx-size 16384` as a practical start, `-ot ".ffn_.*_exps.=CPU"` to keep expert tensors on CPU when VRAM is short. For tool calls use `llama-server --jinja`. Ollama: `ollama run llama4:scout` or `llama4:maverick` (the library tags are `llama4:16x17b` 67 GB and `llama4:128x17b` 245 GB).

### TensorRT-LLM

First-class: [Scout deployment guide](https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-llama4-scout-on-trtllm.html) (FP8 and NVFP4, Blackwell and Hopper, container `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc29`), [Maverick README](https://github.com/NVIDIA/TensorRT-LLM/blob/main/examples/models/core/llama4/README.md) (B200, FP8) and a [Maverick + Eagle3 guide](https://nvidia.github.io/TensorRT-LLM/blogs/tech_blog/blog6_Llama4_maverick_eagle_guide.html).

```bash
trtllm-serve nvidia/Llama-4-Scout-17B-16E-Instruct-FP8 --host 127.0.0.1 --port 8000 --config llama-4-scout.yaml
# curated config: max_batch_size 1024, max_num_tokens 2048, moe_expert_parallel_size 1,
# trust_remote_code true, kv_cache_config.dtype fp8, cuda_graph_config.enable_padding true
```

### TensorFold

Not qualified; no Llama 4 entry in the 1.0.7 qualified list or release notes.

## Llama 3.x

- vLLM JSON tool calling: `--tool-call-parser llama3_json --chat-template examples/tool_chat_template_llama3.1_json.jinja` (3.1) or `tool_chat_template_llama3.2_json.jinja` (3.2, adds images). Parallel calls are not supported for Llama 3, and the model can serialize arrays as strings.
- Pythonic format for 3.2 and 3.3: `--tool-call-parser pythonic` (vLLM and SGLang). Small Llama models frequently emit malformed calls.
- Llama 3.3 70B supports tool use through transformers chat templates (`apply_chat_template(..., tools=[...])`).
