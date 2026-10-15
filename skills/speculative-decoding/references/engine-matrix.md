# Speculative Decoding: Per-Engine Flag Matrix

> Verified against vLLM v0.31.0 (features/speculative_decoding docs), SGLang v0.5.21 (speculative decoding and server arguments docs), TensorRT-LLM v1.2.1 (features/speculative-decoding), llama.cpp master docs/speculative.md and tools/server/README.md (release v0.6.0), TensorFold v1.0.7 (README, RUNBOOK), Ollama modelfile docs (release v0.40.3), TabbyAPI config_sample.yml with ExLlamaV3 v1.6.1, 2026-10-11

Every row comes from the upstream pages in the Sources list at the end. Anything not confirmed is marked "(unverified)". Flags change between releases: run the installed engine's `--help` before applying one.

Numerics: exact verification is designed to be lossless up to floating point, but outputs can still differ. Gate every row with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`) using the procedure in `SKILL.md`. Rows marked **lossy** change the acceptance rule.

## vLLM v0.31.0

Single JSON flag: `--speculative-config '<json>'` (or a nested mapping in a YAML config file; `LLM(..., speculative_config={...})` in Python). The older `--speculative-model` and `--num-speculative-tokens` flags are deprecated.

| Method (`method`) | Needs                                      | Example JSON                                                                                                              | Notes                                                                                                                                                                                                                     |
| ----------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `eagle3`          | EAGLE-3 drafter for this target in `model` | `{"method":"eagle3","model":"RedHatAI/Llama-3.1-8B-Instruct-speculator.eagle3","num_speculative_tokens":2}`               | Docs example also sets `draft_tensor_parallel_size`.                                                                                                                                                                      |
| `eagle`           | EAGLE-1 style drafter                      | `{"method":"eagle","model":"yuhuili/EAGLE-LLaMA3-Instruct-8B","num_speculative_tokens":2,"draft_tensor_parallel_size":1}` | Hub collections: `RedHatAI/speculator-models`, `yuhuili`.                                                                                                                                                                 |
| `mtp`             | Target with native MTP support             | `{"method":"mtp","num_speculative_tokens":1}`                                                                             | Start at `1`. Only model families with MTP support in vLLM. Gemma 4: pass the assistant checkpoint in `model` with `method: mtp`; if logs show `method='draft_model'` for it, the vLLM version lacks Gemma 4 MTP support. |
| `draft_model`     | Smaller model, same vocabulary             | `{"method":"draft_model","model":"Qwen/Qwen3-0.6B","num_speculative_tokens":5}`                                           | Not supported in `vllm<=0.10.0`. `use_heterogeneous_vocab: true` allows a different tokenizer (token-level intersection); it needs greedy draft sampling and `method=draft_model` only.                                   |
| `mlp_speculator`  | IBM MLP accelerator                        | `{"method":"mlp_speculator","model":"ibm-ai-platform/llama3-8b-accelerator","draft_tensor_parallel_size":1}`              | Docs list a known issue with `llama3-70b-accelerator` (`MLPSpeculatorConfig` has no `num_attention_heads`).                                                                                                               |
| `ngram`           | none                                       | `{"method":"ngram","num_speculative_tokens":4,"prompt_lookup_min":2,"prompt_lookup_max":5}`                               | `prompt_lookup_min` and `prompt_lookup_max` default to `5` if both omitted; otherwise each mirrors the other.                                                                                                             |
| `suffix`          | none                                       | `{"method":"suffix","num_speculative_tokens":8}`                                                                          | Keys and defaults: `suffix_decoding_max_tree_depth` 24, `suffix_decoding_max_cached_requests` 10000 (`0` disables the global cache), `suffix_decoding_max_spec_factor` 1.0, `suffix_decoding_min_token_prob` 0.1.         |
| `dflash`          | DFlash drafter                             | listed as a `method` value                                                                                                | Details not read in the docs pages used here (unverified).                                                                                                                                                                |
| `custom_class`    | your proposer class                        | `method=custom_class`, `model="your_module.YourClass"`                                                                    | Experimental; class takes a `VllmConfig` and implements `propose`.                                                                                                                                                        |

Other `speculative_config` keys (docs table): `num_speculative_tokens` (integer greater than 0, default `None`), `draft_tensor_parallel_size`, `max_model_len` (draft), `parallel_drafting` (default `false`; EAGLE and draft-model only), `rejection_sample_method` (`standard` default, `synthetic`, `block`), `synthetic_acceptance_rates`, `synthetic_acceptance_length`. `tensor_parallel_size` is not a valid key: use `draft_tensor_parallel_size`. `temperature` and `top_p` are sampling parameters, not config fields.

- **Lossy / benchmark-only:** `rejection_sample_method: synthetic` replaces real acceptance (benchmark only; output is not valid). `block` is a different verification method: gate it (effect not described in the pages used here (unverified)).
- **Incompatibilities:** pipeline parallelism is not composable with speculative decoding as of `vllm<=0.15.0` (status in newer releases not stated in the docs read (unverified)). Probabilistic draft sampling is not yet supported with `use_heterogeneous_vocab`.
- **Metrics:** Prometheus `vllm:spec_decode_num_drafts_total`, `vllm:spec_decode_num_draft_tokens_total`, `vllm:spec_decode_num_accepted_tokens_total`. Per-request: `--per-request-spec-decode-metrics none|summary|detailed` (default `none`, experimental) returns `metrics.speculative_decoding` with `mean_acceptance_length` and `draft_acceptance_rate`; only for single-sequence requests (`n == 1`).
- **Guidance from docs:** best at medium-to-low QPS and memory-bound workloads; EAGLE and MTP give the best latency; n-gram and suffix give modest gains without extra load at peak.

## SGLang v0.5.21

Launch with `python3 -m sglang.launch_server` (or `sglang serve`).

| Algorithm (`--speculative-algorithm`) | Extra flags                                                                                                                                             | Constraints                                                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EAGLE3`                              | `--speculative-draft-model-path`, `--speculative-num-steps`, `--speculative-eagle-topk`, `--speculative-num-draft-tokens`                               | Docs recommend it for best speed and quality. `--speculative-token-map` is ignored for EAGLE-3.                                                                               |
| `EAGLE` (EAGLE-2)                     | same, plus optional `--speculative-token-map` (FR-Spec), `--enable-torch-compile`, `--torch-compile-max-bs`                                             | Broad compatibility.                                                                                                                                                          |
| `NEXTN`                               | alias of `EAGLE`                                                                                                                                        | Used for MTP-enabled models; the draft path may be omitted for some MTP models.                                                                                               |
| MTP                                   | `--speculative-algorithm EAGLE` with small `--speculative-num-steps 1 --speculative-eagle-topk 1 --speculative-num-draft-tokens 2` (MiMo-7B-RL example) | DeepSeek MTP: see the DeepSeek cookbook linked from the docs.                                                                                                                 |
| `STANDALONE`                          | `--speculative-draft-model-path` (small draft LLM)                                                                                                      | No DP attention (`--attn-dp-size` > 1). Auto defaults: steps 3, topk 1, draft tokens 4.                                                                                       |
| `NGRAM`                               | `--speculative-num-draft-tokens` and `--speculative-ngram-*`                                                                                            | CUDA only; no DP attention; disables the overlap scheduler and mixed chunked prefill.                                                                                         |
| `DFLASH`                              | `--speculative-draft-model-path`, `--speculative-num-draft-tokens` (alias `--speculative-dflash-block-size`), `--speculative-draft-window-size`         | No DP attention; `pp_size == 1`; disables overlap scheduler and mixed chunked prefill.                                                                                        |
| `UNO`                                 | `--uno-lora-path`                                                                                                                                       | CUDA with FA3, `--tp 1` and PP 1 (validated on Qwen3-8B); no grammar decoding, returned logprobs or hidden states, penalties, `min_p`, logit bias or deterministic inference. |

Defaults (docs table): `--speculative-num-steps`, `--speculative-eagle-topk` and `--speculative-num-draft-tokens` are auto-chosen when omitted (steps 5, topk 4, draft tokens 8 for Llama and Grok; 3, 1 and 4 for many other models; with topk 1 draft tokens become steps + 1). Leave all three unset to auto-tune, or set all three. `--speculative-draft-model-quantization` defaults to the target's (`unquant` forces none). `--speculative-attention-mode` default `prefill`.

NGRAM defaults: `--speculative-ngram-min-bfs-breadth` 1, `--speculative-ngram-max-bfs-breadth` 10, `--speculative-ngram-match-type` `BFS` (or `PROB`), `--speculative-ngram-max-trie-depth` 18, `--speculative-ngram-capacity` 10,000,000, draft tokens 12 by default. With breadth above 1 and `page_size` above 1 use `--attention-backend flashinfer`.

- **Overlap scheduler (V2 workers):** on by default with speculative decoding; it supports only `--speculative-eagle-topk 1`. Set it explicitly, because auto-tuning can pick topk above 1 for some models (for example Llama). `--disable-overlap-schedule` falls back.
- **Lossy:** `--speculative-accept-threshold-single` and `--speculative-accept-threshold-acc` default `1.0`; lower values accept more aggressively. `SGLANG_NGRAM_FORCE_GREEDY_VERIFY=True` forces greedy verification. Block verification (`--speculative-use-block-verification`, needs `--speculative-eagle-topk 1`; `--speculative-use-rejection-sampling` for token-wise) changes the verification path: gate it.
- **OOM recipe:** lower `--mem-fraction-static` (for example 0.5), `--cuda-graph-max-bs-decode`, the draft tree size, and `--max-running-requests`.
- **KV dtype interaction:** the SM100 native NVFP4 KV path supports top-k-1 EAGLE/EAGLE3/NEXTN and breadth-1 NGRAM only; other speculative algorithms are not supported there.

## TensorRT-LLM v1.2.1

Configure with `speculative_config` in the LLM API, or in a YAML passed with `--config config.yaml` to `trtllm-serve` and `trtllm-bench` (an alias of the config flag exists; check `--help`). `decoding_type` values in v1.2.1: `MTP`, `Eagle` (for EAGLE 3), `NGram`, `DraftTarget`.

| Method       | Config class and keys                                                                                                          | Constraints                                                                                                                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| EAGLE 3      | `EagleDecodingConfig(max_draft_len, speculative_model, eagle3_one_model)`                                                      | Chain of draft tokens only (no tree). One-model path: Llama 4 Maverick. Two-model: Llama 4 Maverick, Llama 3.1 8B, Llama 3.3 70B. Needs `disable_overlap_scheduler=True` unless `eagle3_one_model`. |
| MTP          | `MTPDecodingConfig(max_draft_len, num_nextn_predict_layers, use_relaxed_acceptance_for_thinking, relaxed_topk, relaxed_delta)` | DeepSeek V3/R1 in the v1.2.1 table. `num_nextn_predict_layers` must match `max_draft_len`.                                                                                                          |
| Draft/target | `DraftTargetDecodingConfig(max_draft_len, speculative_model)`                                                                  | Same tokenizer required. Needs `disable_overlap_scheduler=True`.                                                                                                                                    |
| NGram        | `NGramDecodingConfig(max_draft_len, max_matching_ngram_size, is_public_pool, is_keep_all, is_use_oldest)`                      | Needs `disable_overlap_scheduler=True`.                                                                                                                                                             |

YAML example (v1.2.1 docs):

```yaml
disable_overlap_scheduler: true
speculative_config:
  decoding_type: Eagle
  max_draft_len: 4
  speculative_model: /path/to/draft/model # alias: speculative_model_dir
```

- **Limits:** a single draft sequence of length `max_draft_len` is built for every request and speculation cannot be disabled dynamically, so gains show only at low batch sizes. Reuse across requests works with all speculative models.
- **Lossy:** MTP `use_relaxed_acceptance_for_thinking` accepts drafts in a top-k candidate set during the thinking phase. Gate it hard.
- **Newer than v1.2.1 (main-branch docs read on 2026-10-11, not in the v1.2.1 page):** `Eagle3DecodingConfig` with dynamic tree mode (`use_dynamic_tree`, `dynamic_tree_max_topK`, `max_total_draft_tokens`; not for sliding-window or MLA models), `PARDDecodingConfig`, `DFlashDecodingConfig`, Suffix Automaton (`use_sa_spec`, `sa_spec_threshold` default 4, `SADecodingConfig`). Check the installed version before using them.
- **Legacy TensorRT-engine backend:** Medusa, ReDrafter and Lookahead are documented for the older engine-build flow (Medusa: Vicuna only, `medusa_temperature=0`, no beam search). Their status on the PyTorch backend was not verified (unverified).

## llama.cpp (docs from master; latest release tag v0.6.0)

Flag: `--spec-type TYPE[,TYPE...]` (env `LLAMA_ARG_SPEC_TYPE`), default `none`. Types: `draft-simple`, `draft-eagle3`, `draft-dflash`, `draft-dspark`, `draft-mtp`, `ngram-cache`, `ngram-simple`, `ngram-map-k`, `ngram-map-k4v` (experimental), `ngram-mod`. `--spec-default` enables the default config (`ngram-mod`). A draft-model type can be mixed with a draftless one; the draftless one takes precedence.

| Goal            | Flags                                                                                                                                                                                                                                                                   |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Draft model     | `--spec-type draft-simple -md DRAFT.gguf` (`--spec-draft-model`, `-hfd`/`--spec-draft-hf` to download)                                                                                                                                                                  |
| EAGLE-3         | convert with `convert_hf_to_gguf.py <eagle3-repo> --target-model-dir <target> --outtype bf16`, then `-md eagle3.gguf --spec-type draft-eagle3`                                                                                                                          |
| DFlash / DSpark | convert the draft the same way; `--spec-type draft-dflash` or `draft-dspark`, `--spec-draft-n-max 15` (DFlash) or `7` (DSpark example), `-fa on --jinja`. `--spec-draft-n-max` is clamped to the trained block size. DSpark supports Qwen3 backbones only at read time. |
| MTP             | `--spec-type draft-mtp` (heads from the main model)                                                                                                                                                                                                                     |
| n-gram          | `--spec-type ngram-simple --spec-draft-n-max 64`; `ngram-mod` with `--spec-ngram-mod-n-match 24 --spec-ngram-mod-n-min 48 --spec-ngram-mod-n-max 64`                                                                                                                    |

Defaults: `--spec-draft-n-max` 3, `--spec-draft-n-min` 0, `--spec-draft-p-min` 0.00, `--spec-draft-p-split` 0.10, `--spec-draft-ngl` auto, `--spec-draft-sampling greedy` (or `probabilistic`, where the target verifies by rejection sampling), ngram-simple and ngram-map size N 12, size M 48, min hits 1. Draft KV types: `--spec-draft-type-k` and `--spec-draft-type-v` (allowed `f32, f16, bf16, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1`; default `f16`).

- **Removed flags:** `--draft`, `--draft-max`, `--draft-min`, `--spec-ngram-size-n`, `--spec-ngram-size-m`, `--spec-ngram-min-hits`. Use the `--spec-draft-*` and per-type `--spec-ngram-*` names. Older tutorials with `--draft-max` fail on current builds.
- **Benchmark-only:** `--spec-synth-len` and `--spec-synth-rates`: output is not valid model output.
- **Sampling:** exact output matching needs greedy sampling; backend sampling (`--backend-sampling`) can pick different tokens under stochastic sampling. Tensor split mode does not support backend sampling.
- **Stats:** the server prints `draft acceptance rate = ... (N accepted / M generated)` and per-implementation counters.

## TensorFold v1.0.7

Native Zig binary (`tensorfold` via Homebrew, `tensorfold-native` in archives). Speculation is built into qualified models; there is no method selector.

| Flag                  | Meaning                                                                                                                                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--drafter DRAFTER`   | Qwen3.8-27B's DFlash2 drafter (directory or Hugging Face cache repo id, for example `z-lab/Qwen3.8-27B-DFlash2`). Without it the 27B decodes plain. Qualified on Metal (M5 Max, M3 Ultra) in the README. |
| `--drafter-bits 0\|4` | Drafter weights in 4 bits (default) or bf16 with `0`.                                                                                                                                                    |
| `--no-drafts`         | Serve the plain reference through the same engine: the baseline for the quality gate.                                                                                                                    |

- Nemotron 3.5 Lightning checkpoints include an MTP head; for NVIDIA's NVFP4 checkpoint the bf16 MTP head is quantized to 4-bit at load for drafts.
- Upstream states every accepted draft must equal the token the same engine would produce with `"draft": false` (exact decoding) for a fixed checkpoint, backend, settings and runtime. Still gate: different backends and quantizations can differ.
- The 27B drafter drafts for one stream at a time. Run `tensorfold-native capabilities --json` for the flag list of the installed build.
- Community DGX Spark recipes pin their own TensorFold versions and overrides; treat their settings as upstream-owned.

## Ollama v0.40.3

Modelfile directives from the Modelfile reference:

```text
FROM target-model
DRAFT draft-model
PARAMETER draft_num_predict 4
```

- `draft_num_predict`: maximum draft tokens per step when a draft model is available. Separate draft models default to `4`. Embedded MTP tensors require setting it explicitly. `0` disables speculative drafting.
- MLX runner: Gemma 4 MTP speculative decoding and a `DRAFT` command were added in PR #15980; the draft-quantization flag name differs between the PR text and a PR comment (`--quantize-draft` vs `--draft-quantize`), so read `ollama create --help` (unverified). Whether the llama.cpp-based runner honors `DRAFT` for GGUF models was not verified (unverified).
- Draft tokens are chosen by a controller that backs off to plain decode when drafting does not pay (PR #16791, MLX runner).

## ExLlamaV3 v1.6.1 via TabbyAPI

ExLlamaV3 is a library; its README lists speculative decoding. The server is TabbyAPI. `config.yml` section `draft_model:` (comment: uses more VRAM):

| Key                | Default             | Meaning                                                                                               |
| ------------------ | ------------------- | ----------------------------------------------------------------------------------------------------- |
| `draft_mode`       | `model`             | `model`, `disabled`, `mtp`, `ngram`. In `model` mode drafting is off if no `draft_model_name` is set. |
| `draft_model_dir`  | `models`            | Where draft models live.                                                                              |
| `draft_model_name` | empty               | Draft model to load.                                                                                  |
| `draft_rope_scale` | `1.0`               | Same as `compress_pos_emb`, for long-context drafters.                                                |
| `draft_cache_mode` | `FP16`              | Draft KV cache mode (see `kv-cache-quantization`).                                                    |
| `draft_gpu_split`  | `[]`                | GB per GPU; autosplit if empty.                                                                       |
| `draft_num_tokens` | draft model default | Tokens drafted per iteration.                                                                         |
| `dynamic_draft`    | off                 | Adjust the number of draft tokens from observed acceptance; the ceiling is `draft_num_tokens`.        |
| `ngram_match_min`  | `2`                 | Minimum match length for `ngram` mode.                                                                |

## Sources

- vLLM: https://docs.vllm.ai/en/latest/features/speculative_decoding/ and the v0.31.0 pages https://github.com/vllm-project/vllm/tree/v0.31.0/docs/features/speculative_decoding (mtp, eagle, draft_model, mlp, n_gram, suffix, acceptance_metrics)
- SGLang: https://docs.sglang.ai/advanced_features/speculative_decoding.html and https://docs.sglang.ai/advanced_features/server_arguments.html
- TensorRT-LLM: https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/speculative-decoding.md and https://nvidia.github.io/TensorRT-LLM/advanced/speculative-decoding.html
- llama.cpp: https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md and https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- TensorFold: https://github.com/ashhart/TensorFold (README, RUNBOOK.md)
- Ollama: https://docs.ollama.com/modelfile, https://github.com/ollama/ollama/pull/15980, https://github.com/ollama/ollama/pull/16791
- ExLlamaV3 and TabbyAPI: https://github.com/turboderp-org/exllamav3 and https://github.com/theroyallab/tabbyAPI/blob/main/config_sample.yml
