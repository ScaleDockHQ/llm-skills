# Speculative Decoding: Methods, Tuning and Troubleshooting

> Verified against vLLM v0.31.0 (speculative decoding and acceptance-metrics docs), SGLang v0.5.21 (speculative decoding docs), TensorRT-LLM v1.2.1 (speculative-decoding), llama.cpp master docs/speculative.md, TabbyAPI config_sample.yml, 2026-10-11

Load this when choosing a method or tuning draft length. Flags per engine are in `engine-matrix.md`. The method comparison is qualitative upstream guidance, not a benchmark: measure your own model, traffic and hardware.

## How it works, in one paragraph

A cheap drafter proposes K tokens, the target verifies them in one forward pass, and the matching prefix plus one bonus token is kept. It pays off when the GPU is underused at small batch sizes (TensorRT-LLM) and in memory-bound, medium-to-low QPS workloads (vLLM). Gains depend heavily on the task: predicting code is easier than predicting a summary.

## Method choice

Qualitative table from the vLLM docs, with matching names in other engines:

| Method                                                    | Low QPS        | High QPS       | Needs                                 | Engines (see matrix)                                                                    |
| --------------------------------------------------------- | -------------- | -------------- | ------------------------------------- | --------------------------------------------------------------------------------------- |
| EAGLE / EAGLE-3                                           | High gain      | Medium to high | Trained drafter for this exact target | vLLM, SGLang, TensorRT-LLM, llama.cpp                                                   |
| MTP                                                       | High gain      | Medium to high | Target with native MTP heads          | vLLM, SGLang, TensorRT-LLM, llama.cpp, Ollama (embedded MTP), TensorFold, ExLlamaV3     |
| Draft model                                               | High gain      | Medium         | Small model with the same vocabulary  | vLLM, SGLang (`STANDALONE`), TensorRT-LLM, llama.cpp, Ollama, ExLlamaV3                 |
| Parallel draft (PARD) and block drafters (DFlash, DSpark) | High gain      | Medium to high | Matching drafter checkpoint           | vLLM (PARD, DFlash), SGLang (`DFLASH`), llama.cpp, TensorFold (DFlash2 for Qwen3.8-27B) |
| MLP speculator                                            | Medium to high | Medium         | IBM accelerator checkpoint            | vLLM                                                                                    |
| N-gram and suffix                                         | Low to medium  | Medium         | Nothing                               | vLLM, SGLang (CUDA), TensorRT-LLM, llama.cpp, ExLlamaV3                                 |

Rules of thumb that upstream states:

- Draft and target must share a tokenizer. Otherwise TensorRT-LLM warns the acceptance rate is extremely low and performance regresses. vLLM's `use_heterogeneous_vocab` is the documented exception for `draft_model`.
- Model-free methods win when the output copies from the prompt or earlier output: summarization, document QA, multi-turn chat, code editing (TensorRT-LLM NGram), reasoning models that repeat their thinking in the final answer (llama.cpp `ngram-mod`).
- llama.cpp notes for `ngram-mod`: small `n` is not recommended, MoE models need long drafts, dense models can lower `--spec-ngram-mod-n-min` and `--spec-ngram-mod-n-max`.
- Combine a neural drafter with a model-free one where the engine supports it: llama.cpp accepts a comma-separated `--spec-type` list; TensorRT-LLM main-branch docs describe a Suffix Automaton option layered on MTP, EAGLE 3 or PARD (not in v1.2.1).

## Memory and startup cost

- Drafters use extra VRAM: TabbyAPI marks the `draft_model` section "This will use more VRAM!". SGLang notes the draft tree, CUDA graphs and verification buffers consume extra memory and lists OOM steps.
- SGLang OOM order from upstream: lower `--mem-fraction-static`, then `--cuda-graph-max-bs-decode`, then shrink `--speculative-num-steps`, `--speculative-eagle-topk` and `--speculative-num-draft-tokens`, then `--max-running-requests`. Raise values again one at a time.
- llama.cpp draft models can be placed separately: `--spec-draft-ngl`, `--spec-draft-device`, and a draft KV type via `--spec-draft-type-k` and `--spec-draft-type-v`.
- Budget the drafter before you size the target's KV cache (see the `kv-cache-quantization` and `choosing-hardware` skills).

## Tuning order

1. Start with the engine's conservative setting: vLLM `mtp` with `num_speculative_tokens` `1`; SGLang MTP example with steps 1, topk 1, draft tokens 2; llama.cpp `--spec-draft-n-max` default 3; Ollama `draft_num_predict` 4 for separate drafts.
2. Measure acceptance, not just tokens per second.
   - vLLM: `--per-request-spec-decode-metrics summary`; `mean_acceptance_length` is `1 + accepted_draft_tokens / spec_steps`, ranging from `1.0` to `num_speculative_tokens + 1`. Aggregate counters at `/metrics`.
   - llama.cpp: `draft acceptance rate = X (accepted / generated)` in the log.
   - SGLang: `bench_speculative.py` is named by upstream for finding good step/topk/draft-token combinations.
3. Raise the draft length only while the mean acceptance length keeps rising and tokens per second at your concurrency rises with it. Deeper drafts raise rejection cascades and memory.
4. For SGLang EAGLE, change `--speculative-num-steps`, `--speculative-eagle-topk` and `--speculative-num-draft-tokens` together (all unset for auto, or all set). Use `topk 1` when the overlap scheduler matters.
5. Re-measure at the real concurrency. TensorRT-LLM cannot disable speculation dynamically, so a setting tuned at batch 1 can hurt at higher batch.
6. Repeat the quality gate after any change that touches acceptance or sampling.

## Troubleshooting

| Symptom                                                                                     | Likely cause                                                                  | Action                                                                                                  |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Acceptance near zero, slower than baseline                                                  | Drafter trained for another checkpoint, or draft and target tokenizers differ | Use the drafter published for this exact target; check vocabulary.                                      |
| Slower under load                                                                           | Batch is no longer memory-bound                                               | Lower concurrency target, switch to n-gram or suffix, or disable.                                       |
| vLLM log shows `SpeculativeConfig(method='draft_model', ...)` for a Gemma 4 assistant       | vLLM version lacks Gemma 4 MTP support                                        | Upgrade vLLM; use `"method": "mtp"`.                                                                    |
| vLLM rejects `--speculative-model` or `--num-speculative-tokens`                            | Deprecated flags                                                              | Use `--speculative-config` JSON.                                                                        |
| llama.cpp rejects `--draft-max`, `--draft-min`                                              | Removed in current builds                                                     | Use `--spec-draft-n-max`, `--spec-draft-n-min` or `--spec-ngram-mod-n-max`.                             |
| SGLang errors with `--speculative-eagle-topk` above 1                                       | Overlap scheduler supports topk 1 only                                        | Set `--speculative-eagle-topk 1` explicitly or pass `--disable-overlap-schedule`.                       |
| SGLang NGRAM or STANDALONE fails with data-parallel attention                               | Not supported with `--attn-dp-size` above 1                                   | Use `--attn-dp-size 1` or another method.                                                               |
| SGLang NGRAM breadth above 1 errors with paged attention                                    | Needs flashinfer when `page_size` above 1                                     | `--attention-backend flashinfer`.                                                                       |
| TensorRT-LLM EAGLE (two-model), NGram or draft/target misbehaves with overlap scheduling on | Upstream examples disable the overlap scheduler for these paths               | `disable_overlap_scheduler: true`.                                                                      |
| OOM after enabling                                                                          | Drafter weights, draft tree, CUDA graphs                                      | See memory section.                                                                                     |
| Outputs differ from baseline at temperature 0                                               | Floating point or batch-size effects, or a lossy acceptance setting           | Check settings against the matrix; run the gate; compare baseline against baseline for the noise floor. |

## Benchmarking notes

- Use identical prompts, output lengths, concurrency and sampling for baseline and candidate. The `self-hosted-llms` skill's benchmarking reference describes a fixed protocol and `scripts/bench.sh`. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- llama.cpp ships a SPEED-Bench client under `tools/server/bench/speed-bench` that can compare a baseline run against a speculative run.
- vLLM's docs point to `examples/features/speculative_decoding/spec_decode_offline.py` and its benchmark CLI for reproducible measurements.
- Never use synthetic-acceptance switches for real measurements; they exist to benchmark scheduling, not quality.

## Sources

- https://docs.vllm.ai/en/latest/features/speculative_decoding/
- https://github.com/vllm-project/vllm/blob/v0.31.0/docs/features/speculative_decoding/acceptance_metrics.md
- https://docs.sglang.ai/advanced_features/speculative_decoding.html
- https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/speculative-decoding.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md
- https://github.com/theroyallab/tabbyAPI/blob/main/config_sample.yml
