# Phi: chat templates, tool and reasoning parsers, toggles

> Verified against Phi model cards and `tokenizer_config.json` / `chat_template.jinja` files, vLLM v0.31.0 (docs, `vllm/tool_parsers`, `examples/tool_chat_template_phi4_mini.jinja`), SGLang v0.5.21 source, llama.cpp b11556, TensorRT-LLM supported-models page, TensorFold 1.0.7 README, 2026-10-11

## Two template families

| Family                          | Models                                                                                         | Format                                                                                                       |
| ------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| ChatML-like with `<\|im_sep\|>` | `phi-4`, `Phi-4-reasoning`, `-plus`, `Phi-4-reasoning-vision-15B`                              | `<\|im_start\|>role<\|im_sep\|>content<\|im_end\|>`; generation prompt `<\|im_start\|>assistant<\|im_sep\|>` |
| `<\|system\|>` style            | `Phi-4-mini-instruct`, `-mini-reasoning`, `-mini-flash-reasoning`, `Phi-4-multimodal-instruct` | `<\|system\|>...<\|end\|><\|user\|>...<\|end\|><\|assistant\|>`                                              |

There is no BOS in either template string (the chat templates start directly with the role token; `bos_token_id` is in
`generation_config.json`). Do not add a second BOS in prompts you build by hand.

## Reasoning behaviour per model

| Model                                                       | Thinking                                                            | How to control it                                                                                                                                             |
| ----------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Phi-4-reasoning`, `-plus`                                  | Always on: reply is `<think> ... </think>` then a solution section  | No toggle. The template **hard-codes** the system prompt (see gotcha below)                                                                                   |
| `Phi-4-mini-reasoning`                                      | Always on, math only                                                | Template prepends `<\|system\|>Your name is Phi, an AI math expert developed by Microsoft.` and appends any system content                                    |
| `Phi-4-mini-flash-reasoning`                                | Math reasoning                                                      | Plain chat template; no documented toggle                                                                                                                     |
| `Phi-4-reasoning-vision-15B`                                | Hybrid: model picks `<think>` or `<nothink>` from the system prompt | Force think: end the prompt with `<\|im_start\|>assistant<\|im_sep\|><think>`. Force no-think: end with `<nothink>`. No `enable_thinking` kwarg is documented |
| `phi-4`, `Phi-4-mini-instruct`, `Phi-4-multimodal-instruct` | None                                                                | n/a                                                                                                                                                           |

No Phi model documents `enable_thinking`, `reasoning_effort`, `/think` or `/no_think`.

**Gotcha: the reasoning template ignores your system message.** In `Phi-4-reasoning` (and `-plus`, and the vision model's
`chat_template.jinja`) the system block is a fixed string at the start of the template and the loop only renders `user` and
`assistant` roles. A `system` message you send is dropped. Put instructions in the first user turn. The cards say to
**always** use this template and system prompt.

`Phi-4-reasoning-vision-15B`'s system prompt defines NOTHINK / THINK modes and instructs the model to answer as
`<nothink> {solution}` or `<think> {thought} </think> {solution}`; clients should expect either shape.

## Recommended sampling (from cards)

| Model                          | Settings                                                                                                                                                                    |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Phi-4-reasoning`, `-plus`     | `temperature=0.8`, `top_k=50`, `top_p=0.95`, sampling on. Card marks this "must". `max_new_tokens=32768` for hard queries. `generation_config.json` carries the same values |
| `Phi-4-reasoning-vision-15B`   | `generation_config.json`: `temperature` 0.8, `top_p` 0.95. The card's Foundry sample uses `temperature` 0.0, `max_tokens` 4096                                              |
| `Phi-4-mini-reasoning`         | `temperature=0.8`, `top_p=0.95`, `max_new_tokens=32768` (card example)                                                                                                      |
| `Phi-4-mini-flash-reasoning`   | `temperature=0.6`, `top_p=0.95`, `max_new_tokens=32768` (card example)                                                                                                      |
| `Phi-4-mini-instruct`, `phi-4` | Card examples use `temperature=0.0`; no other recommendation                                                                                                                |

vLLM applies the model's `generation_config.json` as default sampling parameters unless you pass `generation_config="vllm"`
([generative models doc](https://docs.vllm.ai/en/latest/models/generative_models/)), so the 0.8 / 0.95 defaults apply to the reasoning models automatically; set them explicitly per request when you route through a gateway.

## vLLM (v0.31.0)

| Model                      | Architecture (vLLM supported-models doc)  | Command                                                                                          |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------ |
| phi-4, Phi-4-mini-instruct | `Phi3ForCausalLM`                         | `vllm serve microsoft/Phi-4-mini-instruct`                                                       |
| Phi-4-reasoning / plus     | `Phi3ForCausalLM`                         | `vllm serve microsoft/Phi-4-reasoning-plus --reasoning-parser deepseek_r1`                       |
| Phi-4-multimodal-instruct  | `Phi4MMForCausalLM`                       | see multimodal command below                                                                     |
| Phi-4-reasoning-vision-15B | `Phi4ForCausalLMV` (listed, text + image) | `vllm serve microsoft/Phi-4-reasoning-vision-15B --served-model-name Phi-4-reasoning-vision-15B` |
| Phi-4-mini-flash-reasoning | not in the supported-models doc           | see known-issues.md                                                                              |

- **Reasoning parser.** The reasoning-parser table in the vLLM docs has no Phi row. The Phi-4-reasoning and -plus cards say
  `--reasoning-parser deepseek_r1` (their `--enable-reasoning` flag does not appear in the current vLLM reasoning docs, so
  omit it and read `vllm serve --help` on your build). Check that `message.reasoning` is populated on a first request.
- **Tool calling (Phi-4-mini-instruct).** vLLM ships `--tool-call-parser phi4_mini_json` with
  `--chat-template examples/tool_chat_template_phi4_mini.jinja` (file in the vLLM repo `examples/`). The parser extracts
  `functools[{"name": ..., "arguments": {...}}, ...]`. It is not in the vLLM tool-calling doc's parser list, only in
  `vllm/tool_parsers/__init__.py`, so confirm it with `vllm serve --help=ToolParser` or a test request. Always add
  `--enable-auto-tool-choice`.
- **Native HF template.** Phi-4-mini-instruct's own template takes tools only via a system message field `tools`
  (a JSON string wrapped in `<|tool|>...<|/tool|>`), not via the OpenAI `tools` parameter, which is why the vLLM example
  template exists. Other Phi-4 models have no tool format. Do not enable tool parsers for them.
- **Multimodal (card command).**

```bash
vllm serve microsoft/Phi-4-multimodal-instruct --dtype auto --trust-remote-code \
  --max-model-len 131072 --enable-lora --max-lora-rank 320 --lora-extra-vocab-size 0 \
  --limit-mm-per-prompt audio=3,image=3 --max-loras 2 \
  --lora-modules speech=<model-dir>/speech-lora vision=<model-dir>/vision-lora
```

The card's command is from the vLLM ~0.7-era; flag names (for example `--lora-extra-vocab-size`) may have changed in
v0.31. Re-check `vllm serve --help` before copying. Select the LoRA per request with `model: speech` or `model: vision`.

- **Reasoning-vision requirements.** The card lists `torch >= 2.7.1`, `transformers >= 4.57.1`, `vllm >= 0.15.2`, bf16,
  tested on A6000, A100, H100, B200. The Microsoft GitHub vLLM README (older) says to `pip install` a bundled
  `phi_4_rv_vllm_plugin` and that it needs vLLM "16.0"; current vLLM lists `Phi4ForCausalLMV` as built in. Try plain vLLM
  first, and use the plugin only if the architecture is not recognised. `--enforce-eager` skips CUDA-graph capture.

## SGLang (v0.5.21)

- Models in the repo: `phi.py`, `phi3_small.py`, `phi4mm.py`, `phimoe.py`. The supported-models page lists
  `microsoft/Phi-4-multimodal-instruct` and `microsoft/Phi-3.5-MoE-instruct`.
- No Phi tool-call detector and no Phi reasoning parser exist in `function_call/` or `reasoning_parser_names.py`
  (names there include `deepseek-r1`, `qwen3`, `gemma4`, `mistral`, ... ). For the reasoning models, serve without
  `--reasoning-parser` and strip `<think>` client-side, or try `--reasoning-parser deepseek-r1` and test (**unverified**).
- No evidence of `Phi4ForCausalLMV` or Phi-4-mini-flash support. Not qualified: use vLLM.

## TensorRT-LLM (v1.3.0rc29)

Supported-models page lists `Phi3ForCausalLM` (Phi-4, `microsoft/Phi-4`) and `Phi4MMForCausalLM`. NVIDIA publishes
ModelOpt FP8/NVFP4 checkpoints for Phi-4-reasoning-plus and Phi-4-multimodal-instruct (platforms-and-quants.md). No
documented Phi tool or reasoning parser flags were found for `trtllm-serve` (**unverified**).

## llama.cpp (b11556)

- Architectures: Phi-3 / Phi-4 text via the `phi3` loader; `Phi4ForCausalLMV` (reasoning-vision) added by
  [PR #20168](https://github.com/ggml-org/llama.cpp/pull/20168), merged 2026-03-11. Community GGUF repos for it still say
  they need a patched build; that note predates the merge, so use a current build and the model's `mmproj` file.
- Serve with `--jinja` so the Hub chat template is used. For the reasoning models use `--reasoning-format deepseek` (or
  `auto`) to split `<think>` into `reasoning_content`; confirm on your build with a first request. There is no
  Phi-specific tool-call handler: [PR #12288 "tool-call: Phi-4 support"](https://github.com/ggml-org/llama.cpp/pull/12288)
  is still open and last updated 2025-03. Phi-4-mini tool calls are therefore unreliable via `--jinja` (**unverified**,
  test your tool schema).
- Phi-4-multimodal (audio + vision) in llama.cpp: no upstream support found in `docs/multimodal.md` (it does not mention Phi).

## Ollama (v0.40.3)

Library tags: `phi4`, `phi4-mini` (tools badge), `phi4-reasoning`, `phi4-mini-reasoning`. Ollama ships its own template
per tag; use the library tags instead of hand-importing GGUFs so the template is right. Library pages list context windows
of 16K, 128K, 32K and 128K respectively. Reasoning-vision and multimodal have no library page.

## TensorFold (1.0.7)

Not qualified. The README's qualified-models table (Nemotron 3.5 Lightning, Qwen3.8, GLM-5.3-Flash, Qwen3.5-2B) has no
Phi entry and the README's "under qualification" list does not name Phi. Say "no upstream support found".

## Sources

- https://huggingface.co/microsoft/Phi-4-reasoning (card, `tokenizer_config.json`, `generation_config.json`)
- https://huggingface.co/microsoft/Phi-4-reasoning-vision-15B (card, `chat_template.jinja`)
- https://huggingface.co/microsoft/Phi-4-mini-instruct
- https://huggingface.co/microsoft/Phi-4-mini-reasoning
- https://huggingface.co/microsoft/Phi-4-multimodal-instruct
- https://docs.vllm.ai/en/latest/models/supported_models/
- https://docs.vllm.ai/en/latest/features/reasoning_outputs/
- https://docs.vllm.ai/en/latest/features/tool_calling/
- https://github.com/vllm-project/vllm/blob/main/vllm/tool_parsers/phi4mini_tool_parser.py
- https://github.com/vllm-project/vllm/blob/main/examples/tool_chat_template_phi4_mini.jinja
- https://github.com/microsoft/Phi-4-reasoning-vision-15B/blob/main/vllm/README.md
- https://github.com/sgl-project/sglang/tree/main/python/sglang/srt/function_call
- https://github.com/sgl-project/sglang/blob/main/python/sglang/srt/parser/reasoning_parser_names.py
- https://nvidia.github.io/TensorRT-LLM/models/supported-models.html
- https://github.com/ggml-org/llama.cpp/pull/20168
- https://github.com/ggml-org/llama.cpp/pull/12288
- https://ollama.com/library/phi4-reasoning
- https://github.com/ashhart/TensorFold
