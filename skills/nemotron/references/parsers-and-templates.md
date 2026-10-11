# Nemotron parsers and templates

> Verified against the NVIDIA model cards for Nemotron 3.5 Lightning NVFP4, 3 Super NVFP4/FP8, 3 Ultra NVFP4, 3 Nano 30B, 3 Nano 4B and Nano Omni, vLLM docs (`nemotron_v3` parser), the NVIDIA DGX Spark Nemotron playbook and TensorFold v1.0.7 README, 2026-10-11

## Format in one paragraph

Nemotron 3 reasons first and answers second, using the Qwen3 convention: a `<think>` ... `</think>` reasoning block, then
the answer; tool calls use Qwen3-Coder XML (`<tool_call><function=NAME><parameter=KEY>...`). vLLM's docs state the
`nemotron_v3` parser "uses the same tool call and reasoning format as Qwen3" and swaps reasoning and content when
`enable_thinking=False` or `force_nonempty_content=True` and the content came back empty. That is why every card
pairs `--reasoning-parser nemotron_v3` with `--tool-call-parser qwen3_coder`. Exact template token strings were not
extracted from `chat_template.jinja`; read the file in the checkpoint if you need them (unverified here).

## Per-request toggles (`chat_template_kwargs`)

| Key                      | Models                        | Effect (from cards)                                                                                                                                                                                                                                                 |
| ------------------------ | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enable_thinking`        | all Nemotron 3                | `true` is the default. `false` answers directly, with a slight accuracy drop on hard prompts                                                                                                                                                                        |
| `force_nonempty_content` | Lightning, Super, Ultra, Nano | Cards say to set it for coding agents and for SGLang tool calls so content and tool calls are not empty. Ultra on SGLang: set `enable_thinking: true` plus `force_nonempty_content: true` on tool requests                                                          |
| `low_effort`             | Super                         | With `enable_thinking: true`: far fewer reasoning tokens. Card: a good start before tuning budgets                                                                                                                                                                  |
| `medium_effort`          | Ultra                         | Same idea for Ultra. Lightning's card shows no effort flag                                                                                                                                                                                                          |
| `reasoning_budget`       | Super, Ultra, Nano            | Not a server parameter. The cards show a client helper: a first call with `max_tokens=reasoning_budget` to cap the trace, then a second call that closes the trace and generates the answer. It closes at the next newline, or abruptly at `reasoning_budget + 500` |

Nano 4B: the card text says reasoning is "controlled via a system prompt" but its code samples use
`enable_thinking=False` in `apply_chat_template`. Test both on your build (unverified which wins).
Llama-Nemotron Super 49B v1.5 is different: empty system prompt means reasoning ON, `/no_think` in the system prompt
turns it off, sampling 0.6 / 0.95.

Send toggles as `extra_body={"chat_template_kwargs": {...}}` (OpenAI SDK) or `"chat_template_kwargs": {...}` in the
JSON body. TensorFold accepts the same body field and also `--thinking` / `--no-thinking` / `--reasoning-effort`
flags.

## Parser names per engine

| Engine       | Lightning, Super, Ultra, Omni                                                                                                              | Nano 30B, Nano 4B                                                                                                                           |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM         | `--reasoning-parser nemotron_v3 --enable-auto-tool-choice --tool-call-parser qwen3_coder`                                                  | `--reasoning-parser-plugin nano_v3_reasoning_parser.py --reasoning-parser nano_v3 --enable-auto-tool-choice --tool-call-parser qwen3_coder` |
| SGLang       | `--reasoning-parser nemotron_3 --tool-call-parser qwen3_coder`                                                                             | not shown on the Nano card here (unverified)                                                                                                |
| TensorRT-LLM | `--reasoning_parser nano-v3 --tool_parser qwen3_coder` (Ultra and Super snippets); Lightning snippet uses `--reasoning_parser nemotron-v3` | `--reasoning_parser nano-v3`                                                                                                                |
| llama.cpp    | `--jinja` (built-in template and parser)                                                                                                   | `--jinja`                                                                                                                                   |
| Ollama       | built in (`tools` and `thinking` capabilities listed)                                                                                      | built in                                                                                                                                    |

Plugin files: Nano 30B and Nano 4B ship `nano_v3_reasoning_parser.py` in the repo (a `DeepSeekR1ReasoningParser`
subclass that swaps reasoning and content when `enable_thinking` is false and content is empty). Super's cards also
ship `super_v3_reasoning_parser.py` (`--reasoning-parser-plugin ... --reasoning-parser super_v3`); the NVIDIA DGX
Spark playbook still uses it, but the Super HF vLLM snippet (vLLM 0.18.1) and the vLLM docs use the built-in
`nemotron_v3`. Use the built-in name on current vLLM and the plugin only when the name is unknown to your build.
The plugin path must be readable inside the container, so mount it.

## Copy-ready commands

All use values from the cards on 2026-10-11. Bind to loopback with `--host 127.0.0.1` unless exposure is approved; the
cards use `0.0.0.0`.

### vLLM, Lightning NVFP4 on DGX Spark (card quick start, `vllm/vllm-openai:v0.27.1`)

```bash
export MODEL_CKPT=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
export DSPARK_CKPT=nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark
vllm serve --model $MODEL_CKPT --host 127.0.0.1 \
  --moe-backend marlin --kv-cache-dtype fp8 --enable-prefix-caching \
  --gpu-memory-utilization 0.85 \
  --speculative_config.num_speculative_tokens 3 --speculative_config.model $DSPARK_CKPT \
  --mamba-backend flashinfer --mamba-cache-mode align \
  --reasoning-parser nemotron_v3 --tool-call-parser qwen3_coder --enable-auto-tool-choice
```

The card's `main` revision of this snippet adds `--max-model-len 1048576` and uses `--gpu-memory-utilization 0.91`;
`0.85` was the earlier revision. On a Spark that shares memory with the OS, start at 0.85 and raise it only after
checking free memory. Prefix caching with DSpark crashed on startup in one report; see `known-issues.md`.

### vLLM, Lightning NVFP4 on 1x H100 (max throughput, no drafter)

```bash
VLLM_HUMMING_MOE_GEMM_TYPE=indexed vllm serve --model nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 \
  --max-num-seqs 256 --max-num-batched-tokens 16384 --enable-prefix-caching --async-scheduling \
  --mamba-backend flashinfer --moe-backend humming --linear-backend humming \
  --mamba-ssu-algorithm horizontal --mamba-cache-mode align --mamba-ssm-cache-dtype float16 \
  --enable-mamba-cache-stochastic-rounding --mamba-cache-philox-rounds 5 \
  --reasoning-parser nemotron_v3 --tool-call-parser qwen3_coder --enable-auto-tool-choice
```

The card has other recipes: H100 interactive with DSpark (`--max-num-seqs 128`), 8x H100 (`--tensor-parallel-size 8
--enable-expert-parallel`), 1x GB200 (DSpark with 5 draft tokens, `--no-enable-prefix-caching`) and Ampere W4A16
(`--quantization modelopt_fp4 --moe-backend humming --linear-backend humming --mamba-ssu-algorithm simple`).

### vLLM, Super NVFP4 on one DGX Spark (NVIDIA playbook, `vllm/vllm-openai:cu130-nightly`)

```bash
docker run --rm -it --gpus all \
  -e VLLM_NVFP4_GEMM_BACKEND=marlin -e VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
  -e VLLM_FLASHINFER_ALLREDUCE_BACKEND=trtllm -e VLLM_USE_FLASHINFER_MOE_FP4=0 \
  -v ~/.cache/huggingface:/root/.cache/huggingface -e HF_TOKEN \
  -p 127.0.0.1:8000:8000 vllm/vllm-openai:cu130-nightly \
  --model nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4 --served-model-name nemotron-3-super \
  --host 0.0.0.0 --port 8000 --async-scheduling --dtype auto --kv-cache-dtype fp8 \
  --trust-remote-code --gpu-memory-utilization 0.90 --enable-chunked-prefill --max-num-seqs 4 \
  --max-model-len 1000000 --moe-backend marlin --mamba_ssm_cache_dtype float32 --quantization fp4 \
  --speculative_config '{"method":"mtp","num_speculative_tokens":3,"moe_backend":"triton"}' \
  --reasoning-parser nemotron_v3 --enable-auto-tool-choice --tool-call-parser qwen3_coder
```

The playbook mounts `super_v3_reasoning_parser.py` and uses `--reasoning-parser-plugin ... --reasoning-parser super_v3`
instead of the last parser flag; the Super NVFP4 card's own Spark command differs again (`--max-model-len 394000`,
`--attention-backend TRITON_ATTN`, no MTP). Pick one source and keep it: the playbook for a first success. `HF_TOKEN`
passes by name from the environment, never inline.

### vLLM, Ultra NVFP4 on 4x B200 (card, `vllm/vllm-openai:v0.22.0`)

Key flags: `--tensor-parallel-size 4 --enable-expert-parallel --kv-cache-dtype fp8 --max-model-len 262144
--max-num-seqs 16 --enable-chunked-prefill --enable-prefix-caching --mamba-ssm-cache-dtype float16 --mamba-backend
flashinfer --enable-mamba-cache-stochastic-rounding --mamba-cache-philox-rounds 5 --speculative-config
'{"method": "nemotron_h_mtp", "num_speculative_tokens": 5}'` plus the three parser flags. Two nodes of 4x GB300 use
`--tensor-parallel-size 4 --pipeline-parallel-size 2 --distributed-executor-backend ray`. Ultra needs
`--trust-remote-code` in the card.

### SGLang (Lightning card, container `lmsysorg/sglang:dev-nemotron3-5-lightning`)

```bash
sglang serve --model-path nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 \
  --mamba-ssm-dtype float16 --mem-fraction-static 0.78 --cuda-graph-max-bs-decode 4 \
  --reasoning-parser nemotron_3 --tool-call-parser qwen3_coder --port 8000
```

That is the GB10 recipe. B200 adds `--mamba-backend flashinfer --enable-mamba-cache-stochastic-rounding
--mamba-cache-philox-rounds 5 --mem-fraction-static 0.85 --cuda-graph-max-bs-decode 16`. Speculative flags:
MTP `--speculative-algorithm EAGLE --speculative-draft-model-path <same ckpt> --speculative-num-steps 5
--speculative-eagle-topk 1 --speculative-num-draft-tokens 6`; DFlash `--speculative-algorithm DFLASH`; DSpark
`--speculative-algorithm DSPARK --speculative-dspark-block-size 3`. Ultra: `lmsysorg/sglang:v0.5.12.post1`,
`--tp-size 4 --ep-size 4`, `SGLANG_DISABLE_DEEP_GEMM=1`, `--mamba-scheduler-strategy no_buffer`; for 1M context set
`SGLANG_ALLOW_OVERWRITE_LONGER_CONTEXT_LEN=1`.

### TensorRT-LLM (Lightning card, 1x H100)

`trtllm-serve $MODEL_CKPT --max_batch_size 8 --max_num_tokens 8192 --reasoning_parser nemotron-v3 --tool_parser
qwen3_coder --config nemotron-35-lightning-nvfp4-mtp.yaml` with a YAML that sets `kv_cache_config.dtype: fp8`,
`moe_config.backend: MARLIN` and `speculative_config` of `decoding_type: MTP`, `max_draft_len: 3`. Container for
Ultra: `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc17`; the Super Spark playbook used `...release:1.3.0rc9`.

### llama.cpp

```bash
llama-server -hf ggml-org/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF:Q4_0 \
  --temp 1.0 --top-p 0.95 -np 1 -c 40960 --port 8000 --host 127.0.0.1 -ngl 99 -fa on --jinja --no-webui --fit off
```

The Lightning card writes `:Q4_K_M` here, but `ggml-org/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF` holds only BF16,
Q4_0 and Q8_0 (plus `mtp-*` draft-head files) on 2026-10-11, so use `:Q4_0` or `:Q8_0`, or a community repo with
Q4_K_M. `--jinja` is required for tools. To turn reasoning off use `--chat-template-kwargs '{"enable_thinking":false}'`;
`--reasoning-format deepseek` puts thoughts in `reasoning_content`. Nano 4B: `llama-server -hf
nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF:Q4_K_M -c 0 -ngl 999`. Use a recent build: Nemotron-H needs a new enough
llama.cpp (Super needed b8295 or newer per the issue below).

### Ollama

`ollama run nemotron-3.5-lightning` (tools and thinking). Ollama's page lists a 1M-context tag at 25 GB and a 256K tag at
23 GB. The card says Ollama sets context from VRAM (under 24 GB: 4K, 24-48 GB: 32K, 48 GB and up: 256K); raise it with
`/set parameter num_ctx N`. `nemotron-3-nano`, `nemotron-3-super` (87 GB, 256K) exist; `nemotron-3-ultra` is `:cloud`
only.

### TensorFold (Lightning only)

```bash
tensorfold serve ~/models/nemotron-lightning --name nemotron-tf --host 127.0.0.1 --port 8090 --context 32768 --parallel 4
```

See the `tensorfold` skill and `platforms-and-quants.md`. Reasoning flags: `--thinking`, `--no-thinking`,
`--reasoning-effort`.

## Client call that works for agents

```python
client.chat.completions.create(
    model=MODEL, messages=messages, tools=tools, max_tokens=16000,
    temperature=1.0, top_p=0.95,
    extra_body={"chat_template_kwargs": {"enable_thinking": True, "force_nonempty_content": True}},
)
```

## Sampling from the cards

| Model                         | Reasoning                                                  | Tool calling |
| ----------------------------- | ---------------------------------------------------------- | ------------ |
| Lightning, Super              | 1.0 / 0.95 for everything                                  | 1.0 / 0.95   |
| Ultra                         | card examples use 1.0 / 0.95 (no separate statement found) | same         |
| Nano 30B                      | 1.0 / 1.0                                                  | 0.6 / 0.95   |
| Nano 4B                       | 1.0 / 0.95                                                 | 0.6 / 0.95   |
| Llama-Nemotron Super 49B v1.5 | 0.6 / 0.95                                                 | not stated   |

Cards recommend `max_tokens` of about 10,000 or more with reasoning on (Nano) and 16,000 in the Lightning examples.

## Sources

- https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-FP8
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-BF16
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF
- https://huggingface.co/nvidia/Llama-3_3-Nemotron-Super-49B-v1_5
- https://docs.vllm.ai/en/latest/api/vllm/parser/nemotron_v3/
- https://build.nvidia.com/spark/nemotron
- https://github.com/NVIDIA-NeMo/Nemotron/blob/main/usage-cookbook/Nemotron-3.5-Lightning/vllm_cookbook.ipynb
- https://ollama.com/library/nemotron-3.5-lightning
- https://github.com/ashhart/TensorFold
