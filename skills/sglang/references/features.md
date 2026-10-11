# SGLang: features

> Verified against SGLang v0.5.21 (docs: advanced_features/{tool_parser,separate_reasoning,structured_outputs,speculative_decoding,lora,hicache*,radix_eviction_policy,deterministic_inference}, basic_usage/openai_api__, supported-models/_), 2026-10-11

## Contents

- [RadixAttention and prefix caching](#radixattention-and-prefix-caching)
- [HiCache (hierarchical KV cache)](#hicache)
- [Tool calling and reasoning parsers](#tool-calling-and-reasoning-parsers)
- [Structured outputs](#structured-outputs)
- [Speculative decoding](#speculative-decoding)
- [LoRA](#lora)
- [Multimodal](#multimodal)
- [Embeddings, rerank, score](#embeddings-rerank-score)
- [Deterministic inference](#deterministic-inference)

## RadixAttention and prefix caching

On by default. The server keeps KV for processed prefixes in a radix tree and reuses it for new requests that share a prefix (system prompts, tools, chat history, few-shot examples, agent loops). Related flags:

- `--disable-radix-cache`: turn off (A/B tests, strict determinism experiments).
- `--schedule-policy lpm`: longest-prefix-match ordering, more hits at some scheduling cost; `dfs-weight`, `routing-key` are other cache-aware policies.
- `--radix-eviction-policy lru|lfu|...` (`tlru` for agentic multi-turn tail latency; parameters via `--radix-eviction-policy-config` JSON).
- `--enable-cache-report`: returns `usage.prompt_tokens_details.cached_tokens`; also watch `sglang:cache_hit_rate`.
- `--strip-thinking-cache`: do not cache reasoning output, keep the prompt prefix only.
- Flush: `POST /flush_cache` (optional `?timeout=30` waits for idle).
- Claude Code and other agentic clients: set `CLAUDE_CODE_ATTRIBUTION_HEADER=0` (the upstream Anthropic API page calls it required for prefix-cache reuse). See `integrations.md`.
- EmbeddingGemma-style encoders disable radix cache automatically; hybrid/Mamba models use `--mamba-radix-cache-strategy`.

## HiCache

Three tiers: L1 GPU, L2 host memory, L3 shared storage. Only L3 is shared across instances.

```bash
--enable-hierarchical-cache --hicache-ratio 2 --page-size 64
# or --hicache-size <GB> (overrides ratio); --hicache-write-policy write_through
# L3: --hicache-storage-backend file|mooncake|hf3fs|nixl|aibrix  (+ --hicache-storage-backend-extra-config '<json or @file>')
```

`file` backend defaults to node-local `/tmp/hicache`; the others can reach cluster scope when instances share a namespace. Upstream also supports attaching/detaching the storage backend at runtime over HTTP admin endpoints (see `hicache_storage_runtime_attach_detach`). Best-practice page: `advanced_features/hicache_best_practices`.

## Tool calling and reasoning parsers

Tool calls and reasoning are parsed server-side only when you pass the parsers. Without `--tool-call-parser`, tool schemas are accepted but calls come back as raw text. `auto` detects from the chat template; set it explicitly for production and test.

```bash
python3 -m sglang.launch_server --model-path openai/gpt-oss-120b \
  --tool-call-parser gpt-oss --reasoning-parser gpt-oss
python3 -m sglang.launch_server --model-path Qwen/Qwen3-32B \
  --tool-call-parser qwen25 --reasoning-parser qwen3
```

`--tool-call-parser` values in 0.5.21: `auto`, `apertus2509`, `cohere_command4`, `deepseekv3`, `deepseekv31`, `deepseekv32`, `deepseekv4`, `dots`, `glm`, `glm45`, `glm47`, `gpt-oss`, `k2_horizon`, `kimi_k2`, `kimi_k3`, `lfm2`, `ling3`, `llama3`, `mimo`, `minicpm5`, `mistral`, `muse`, `poolside_v1`, `pythonic`, `qwen`, `qwen25`, `qwen3_coder`, `spark25`, `step3`, `step3p5`, `minimax-m2`, `minimax-m3`, `trinity`, `interns1`, `hermes`, `hunyuan`, `gigachat3`, `gigachat35`, `gemma4`, `inkling`.

`--reasoning-parser` values: `auto`, `apertus2509`, `deepseek-r1`, `deepseek-v3`, `deepseek-v4`, `dots`, `glm45`, `ling3`, `hunyuan`, `gpt-oss`, `k2_horizon`, `kimi`, `kimi_k2`, `kimi_k3`, `mimo`, `muse`, `poolside_v1`, `qwen3`, `qwen3-thinking`, `minimax`, `minimax-append-think`, `minimax-m3`, `step3`, `step3p5`, `mistral`, `nemotron_3`, `interns1`, `gemma4`, `gigachat35`, `inkling`, `cohere_command4`.

Which model uses which: the upstream tool-parser and separate-reasoning tables, for example `deepseekv3` -> DeepSeek-V3 (add `--chat-template ./examples/chat_template/tool_chat_template_deepseekv3.jinja` as recommended), `deepseekv31` -> V3.1/V3.2-Exp, `llama3` -> Llama 3.1/3.2/3.3, `pythonic` -> Llama 3.2+/4 style Python calls, `kimi_k2` -> Kimi K2, `mistral`, `glm`, `gpt-oss`. Reasoning: `deepseek-r1` (R1 family), `deepseek-v3` (V3.1/V3.2 hybrid, toggled with `thinking`, not `enable_thinking`), `qwen3` (supports `enable_thinking`), `qwen3-thinking`, `kimi_k2`, `gpt-oss`.

Behavior notes:

- Reasoning output appears in `message.reasoning_content` when the request sets `extra_body={"separate_reasoning": True}`; streaming uses `delta.reasoning_content`. Check the page for per-model defaults.
- `gpt-oss` tool parser filters analysis-channel events; content can be empty when explanations live in the analysis channel. For offline engine use add `"no_stop_trim": True` so the call token is not trimmed.
- `tool_choice="required"` and `{"type":"function",...}` use EBNF grammar; fully supported with the default `xgrammar` backend, not guaranteed with `outlines`.
- Defaults for chat-template kwargs: `--default-chat-template-kwargs '{"enable_thinking": false}'`.
- `--enable-strict-thinking` filters excluded tokens during the thinking phase.
- Check the actual behavior: send a request with a tool and assert `finish_reason == "tool_calls"` and `message.tool_calls[0].function.arguments` parses as JSON.

## Structured outputs

Grammar backends: `--grammar-backend xgrammar` (default; JSON schema, regex, EBNF), `outlines` (JSON schema, regex), `llguidance` (all three), `none`. One constraint per request.

```python
# OpenAI client
client.chat.completions.create(model="m", messages=[...],
  response_format={"type":"json_schema","json_schema":{"name":"foo","schema":{...}}})
client.chat.completions.create(model="m", messages=[...], extra_body={"regex": "(Paris|London)"})
client.chat.completions.create(model="m", messages=[...], extra_body={"ebnf": "root ::= ..."})
```

Still tell the model the desired format in the prompt. For reasoning models, structured output applies after the thinking phase (see `structured_outputs_for_reasoning_models` upstream). Pitfalls: `--disable-outlines-disk-cache` if the outlines disk cache crashes under concurrency; `--constrained-json-disable-any-whitespace` for compact JSON (xgrammar/llguidance).

## Speculative decoding

Pick by situation (upstream "quick guidance"):

| Method                              | Flag                                                                            | Needs                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| EAGLE-3 (recommended speed/quality) | `--speculative-algorithm EAGLE3 --speculative-draft-model-path <draft>`         | Trained EAGLE-3 draft                                                                  |
| EAGLE-2                             | `--speculative-algorithm EAGLE --speculative-draft-model-path <draft>`          | EAGLE draft; add `--speculative-token-map` for FR-Spec                                 |
| MTP (built-in heads)                | `--speculative-algorithm EAGLE` with small steps/topk                           | Model with MTP weights                                                                 |
| Standalone                          | `--speculative-algorithm STANDALONE --speculative-draft-model-path <small llm>` | Smaller same-vocab LLM; no DP attention                                                |
| NGRAM                               | `--speculative-algorithm NGRAM`                                                 | No draft model; CUDA only; no DP attention; disables overlap scheduler and mixed chunk |
| DFLASH                              | `--speculative-algorithm DFLASH ...`                                            | DFlash draft; `pp_size == 1`; no DP attention                                          |
| UNO                                 | `--speculative-algorithm UNO --uno-lora-path ...`                               | UNO adapter; CUDA + FA3; TP=PP=1                                                       |
| Adaptive                            | `--speculative-adaptive` (on EAGLE with `--speculative-eagle-topk 1`)           | Adjusts steps from acceptance rate                                                     |

Examples from the docs:

```bash
python3 -m sglang.launch_server --model meta-llama/Meta-Llama-3.1-8B-Instruct \
  --speculative-algorithm EAGLE3 --speculative-draft-model-path jamesliu1/sglang-EAGLE3-Llama-3.1-Instruct-8B \
  --speculative-num-steps 3 --speculative-eagle-topk 4 --speculative-num-draft-tokens 16 \
  --mem-fraction-static 0.7 --cuda-graph-max-bs-decode 8 --dtype float16
# MTP: --speculative-algorithm EAGLE --speculative-num-steps 1 --speculative-eagle-topk 1 --speculative-num-draft-tokens 2
```

Tuning: `--speculative-num-steps`, `--speculative-eagle-topk`, `--speculative-num-draft-tokens` (more is not always faster; benchmark). Draft weights consume memory: lower `--mem-fraction-static` if OOM (upstream has an OOM section). Spec decoding pays off at low to moderate concurrency; at high batch sizes it can lose. Watch `sglang:spec_accept_rate` and `sglang:spec_accept_length` if present on your version (verify with `curl /metrics`). Cross-engine strategy: skill `speculative-decoding`.

## LoRA

```bash
python3 -m sglang.launch_server --model-path meta-llama/Meta-Llama-3.1-8B-Instruct \
  --enable-lora --lora-paths lora0=/path/or/hf-id lora1=/path/b \
  --max-loras-per-batch 2 --max-lora-rank 64 --lora-target-modules all
```

- `--lora-paths` formats: `<PATH>`, `<NAME>=<PATH>`, or JSON `{"lora_name":..,"lora_path":..,"pinned":true}` (pin hot adapters on the GPU).
- Use from the OpenAI API with `model="base-model:adapter-name"` (preferred) or `extra_body={"lora_path": "adapter"}`; the native `/generate` takes `lora_path` (a list for batches, `null` = base).
- Dynamic: `POST /load_lora_adapter` and `/unload_lora_adapter` (set `--max-lora-rank` and `--lora-target-modules` up front if later adapters are larger).
- Backend `--lora-backend csgmv` (default) or `triton`; `--lora-eviction-policy lru|fifo`; `--enable-lora-overlap-loading` hides load latency (not with DP attention); `--max-loaded-loras` bounds CPU copies (>= `--max-loras-per-batch`).
- Works with TP; with DP attention see the "LoRA with DP attention" section upstream.

## Multimodal

Vision-language models accept OpenAI-format `image_url` content. Flags: `--enable-multimodal`, `--mm-attention-backend`, `--limit-mm-data-per-request '{"image":1,"video":1}'`, `--mm-process-config`, `--language-model-only`/`--language-only` (drop the encoder), `--encoder-only` plus `--encoder-urls` for encode/prefill disaggregation (EPD), `--mm-enable-dp-encoder`, `--enable-prefix-mm-cache`.

Security: set `--allowed-media-domains host1 host2` when clients are untrusted (exact hostnames; redirects are checked); `--media-url-max-file-size-mb` defaults to 64. Local paths and `data:` URLs are not subject to the allowlist.

Benchmark VLM: `python -m sglang.bench_serving --backend sglang-oai-chat --dataset-name image --image-count 3 --image-resolution 720p ...` (consider `--disable-radix-cache` when benchmarking).

## Embeddings, rerank, score

```bash
sglang serve --model-path Qwen/Qwen3-Embedding-4B --is-embedding --port 30000
curl -fsS http://127.0.0.1:30000/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen3-Embedding-4B","input":"What is the capital of France?"}' | jq '.data[0].embedding|length'
```

Native encoder architectures and `google/embeddinggemma-300m` are auto-detected (no `--is-embedding`; radix cache and chunked prefill adjustments happen automatically). Other endpoints: `/v1/rerank` (cross-encoder), `/v1/score` (decoder-only scoring), `/classify` (reward model), `/encode` (native). Benchmark with `--backend sglang-embedding`.

## Deterministic inference

`--enable-deterministic-inference` enables batch-invariant ops (some throughput cost); without it, outputs at `temperature 0` can differ run to run because of dynamic batching and prefix caching. `--disable-radix-cache` plus one request at a time gives mostly deterministic output.
