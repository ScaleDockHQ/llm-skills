# Features

> Verified against TensorRT-LLM v1.2.1 (`speculative-decoding.md`, `guided-decoding.md`, `kvcache.md`, parser factories, `llm_args.py`) and `main` parser factories, 2026-10-11

## Speculative decoding (PyTorch backend)

Two flavors: **one-model** (drafter inside the model code, drafting loop captured in one CUDA graph, fastest, fewer algorithm/model pairs) and **two-model** (draft tokens produced in the executor; set `disable_overlap_scheduler: true` as upstream examples do; upstream also says the overlap scheduler is disabled automatically for it).

| Algorithm             | One-model        | Two-model                                     | `decoding_type` in YAML |
| --------------------- | ---------------- | --------------------------------------------- | ----------------------- |
| EAGLE 3               | Llama 4 Maverick | Llama 4 Maverick, Llama 3.1 8B, Llama 3.3 70B | `Eagle`                 |
| MTP / EAGLE-style MTP | DeepSeek V3/R1   |                                               | `MTP`                   |
| Draft/target          |                  | all models (same tokenizer required)          | `DraftTarget`           |
| NGram (prompt lookup) |                  | all models                                    | `NGram`                 |
| User-provided drafter |                  | all models (Python API only)                  |                         |

One sequence of `max_draft_len` tokens per request (no tree). Speculation cannot be switched off dynamically, so speedups show at low batch sizes. Only greedy sampling is supported for two-model verification (docs).

YAML (works for `trtllm-serve` and `trtllm-bench` via `--config`):

```yaml
disable_overlap_scheduler: true # two-model only
speculative_config:
  decoding_type: Eagle
  max_draft_len: 4
  speculative_model: yuhuili/EAGLE3-LLaMA3.1-Instruct-8B # Hub id or local path (alias speculative_model_dir)
```

```yaml
speculative_config: # DeepSeek MTP
  decoding_type: MTP
  max_draft_len: 3
  num_nextn_predict_layers: 3 # must match max_draft_len
```

```yaml
speculative_config: # NGram
  decoding_type: NGram
  max_draft_len: 3
  max_matching_ngram_size: 4
  is_public_pool: true
```

EAGLE-3 draft checkpoints: `yuhuili/*` for Llama 3, `nvidia/Llama-4-Maverick-17B-128E-Eagle3`, others (gpt-oss-120b, Qwen3) from NVIDIA's "Speculative Decoding Modules" collection. Eagle3 one-model on Llama 4: `eagle3_one_model: true` (Python `EagleDecodingConfig`). For cross-engine technique guidance and quality gates use `speculative-decoding` (`npx skills add ScaleDockHQ/llm-skills --skill speculative-decoding`). Reuse across requests works with all speculative models.

## Reasoning and tool parsers

`--reasoning_parser <name>` splits `<think>` output into `reasoning_content`; `--tool_parser <name>` turns model tool-call syntax into OpenAI `tool_calls`.

| Parser kind | v1.2.1 names                                                                     | `main` adds                                                                                                                                                       |
| ----------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| reasoning   | `deepseek-r1`, `qwen3`, `nano-v3`                                                | more keys (`qwen3_5`, `minimax_m2`, `minimax_m2_append_think`, ...; run `--help`) and an `auto` choice that selects by model (`resolve_auto_*` helpers in source) |
| tool        | `qwen3`, `qwen3_coder`, `kimi_k2`, `deepseek_v3`, `deepseek_v31`, `deepseek_v32` | `kimi_k3`, `deepseek_v4`, `deepseek_v41`, `gemma4`, `glm4`, `glm47`, `minimax_m2`, `minimax_m3`, `poolside_v1`                                                    |

Example from NVIDIA's Spark playbook (Nemotron Omni): `--reasoning_parser nano-v3 --tool_parser qwen3_coder`. Mismatched parser and model give empty `reasoning_content` or unparsed tool text; pick the parser from the model's card or deployment guide. `auto` exists only on `main` builds (from the source helpers; behavior not exercised here).

## Guided decoding (JSON schema, regex, EBNF, structural tags)

```yaml
guided_decoding_backend: xgrammar # or llguidance (JSON schema, regex, EBNF; no structural tags)
```

Then use `response_format` (`json_schema`, `regex`, `ebnf`, `structural_tag`) in chat requests. The log line `Guided decoder initialized with backend: GuidedDecodingBackend.XGRAMMAR` confirms it. Without the YAML key, constrained requests are not enforced.

## KV cache

- Block reuse across requests (prefix caching) is on by default: `kv_cache_config.enable_block_reuse`. Radix tree with prioritized LRU eviction; priorities 0 to 100 (default 35); per-request retention policy through `KvCacheRetentionConfig` (Python API).
- Partial reuse on (`enable_partial_reuse`), `copy_on_partial_reuse`.
- Host offload: `kv_cache_config.host_cache_size` (bytes, default 0), `secondary_offload_min_priority` (default 35).
- `cache_salt` per request isolates reuse between tenants.
- `max_attention_window` for models with sliding-window layers; `max_tokens` caps blocks (the smaller of `max_tokens` and `free_gpu_memory_fraction` wins).
- `dtype: fp8` or `nvfp4` for quantized KV (`models-and-formats.md`).
- Disable reuse for multimodal models.
- Deprecated: `use_uvm`, `sink_token_length`.

## Scheduling

- **Overlap scheduler**: on by default; turn off with `disable_overlap_scheduler: true` for two-model speculation and disaggregated context servers (the NVIDIA Spark playbook also disables it for Llama 3.1 8B and gpt-oss-20b).
- **Chunked prefill**: `--enable_chunked_prefill` or `enable_chunked_prefill: true`; Dynamo's prefill configs use it.
- **CUDA graphs**: `cuda_graph_config` (default object, so on). Graphs are captured only for decode-only batches at the listed sizes; each can use up to about 200 MB. `enable_padding: true` pads a batch up to the next captured size.
- **Attention DP / DP load balancing**: `enable_attention_dp`, `attention_dp_config`.
- `stream_interval`: larger values reduce streaming overhead at high batch sizes.
- `allreduce_strategy`: `AUTO` default, others `NCCL`, `UB`, `MINLATENCY`, `ONESHOT`, `TWOSHOT`, `LOWPRECISION`, `MNNVL`, `NCCL_SYMMETRIC`.

## LoRA, multimodal, embeddings, diffusion

LoRA adapters are supported through `lora_config` / request-level LoRA (see the LoRA feature doc; not exercised here). Multimodal and embeddings: `models-and-formats.md`. Request-level sampling controls (`temperature`, `top_p`, `logit_bias`, `n`) follow OpenAI semantics; for `n > 1` on the default deterministic path Dynamo's docs say TensorRT-LLM rejects the request unless `TLLM_ALLOW_N_GREEDY_DECODING=1` is set (reported there for greedy decoding).

## Official links

- Speculative decoding: https://nvidia.github.io/TensorRT-LLM/features/speculative-decoding.html
- Guided decoding: https://nvidia.github.io/TensorRT-LLM/features/guided-decoding.html
- KV cache: https://nvidia.github.io/TensorRT-LLM/features/kvcache.html
- Feature combination matrix: https://nvidia.github.io/TensorRT-LLM/features/feature-combination-matrix.html
