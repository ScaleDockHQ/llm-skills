# KV Cache Quantization: Per-Engine Flag Matrix

> Verified against vLLM v0.31.0 (quantized_kvcache docs, vllm/config/cache.py), SGLang v0.5.21 (quantized KV cache docs), TensorRT-LLM v1.2.1 (features/quantization), llama.cpp master tools/server/README.md and issue #24485, Ollama docs FAQ, TabbyAPI config_sample.yml with ExLlamaV3, TensorFold v1.0.7 (self-hosted-llms engine-tensorfold reference), 2026-10-11

Every row comes from the upstream pages in the Sources list. Anything not confirmed is marked "(unverified)". Flags change between releases: run the installed engine's `--help` before applying one.

Numerics: every non-default KV dtype changes outputs. Gate each change with the `llm-evals` skill (install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`) using the procedure in `SKILL.md`: baseline against candidate on the user's eval set at the longest context served, a user-chosen acceptance threshold, and a rollback to the baseline launch command.

## Quick comparison

| Engine               | Flag                    | Default              | Common values                                            | Calibrated scales                         |
| -------------------- | ----------------------- | -------------------- | -------------------------------------------------------- | ----------------------------------------- |
| vLLM                 | `--kv-cache-dtype`      | `auto`               | `fp8`, `fp8_e4m3`, `fp8_e5m2`, `nvfp4`                   | llm-compressor (recommended)              |
| SGLang               | `--kv-cache-dtype`      | model dtype (`auto`) | `fp8_e4m3`, `fp8_e5m2`, `nvfp4`, `fp4_mx_block16`        | checkpoint or `--quantization-param-path` |
| TensorRT-LLM         | `kv_cache_config.dtype` | checkpoint-defined   | `fp8`, `nvfp4`                                           | ModelOpt checkpoint                       |
| llama.cpp            | `-ctk` / `-ctv`         | `f16`                | `q8_0`, `q5_1`, `q5_0`, `q4_1`, `q4_0`, `iq4_nl`, `bf16` | none (block-wise)                         |
| Ollama               | `OLLAMA_KV_CACHE_TYPE`  | `f16`                | `q8_0`, `q4_0`                                           | none                                      |
| ExLlamaV3 / TabbyAPI | `cache_mode`            | `FP16`               | `8,8`, `6,6`, `4,4` and any `k_bits,v_bits` 2-8          | none                                      |
| TensorFold           | recipe `KV_DTYPE`       | recipe-owned         | see `capabilities --json`                                | (unverified)                              |

## vLLM v0.31.0

Flag: `--kv-cache-dtype <dtype>` (Python `kv_cache_dtype=`). Default `auto` (model dtype).

Allowed values in v0.31.0 (`CacheDType`): `auto`, `float16`, `bfloat16`, `fp8`, `fp8_e4m3`, `fp8_e5m2`, `fp8_inc`, `fp8_ds_mla`, `nvfp4_ds_mla`, `turboquant_k8v4`, `turboquant_4bit_nc`, `turboquant_k3v4_nc`, `turboquant_3bit_nc`, `int4_per_token_head`, `int8_per_token_head`, `fp8_per_token_head`, `nvfp4`, `nvfp4_4over6`.

| Value                        | Notes                                                                                                                                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fp8`                        | Same as `fp8_e4m3`. CUDA 11.8+ and ROCm. Default scales are `1.0` unless the checkpoint carries calibrated scales; vLLM logs that accuracy may drop without a proper scaling factor. |
| `fp8_e4m3`                   | CUDA 11.8+ and ROCm (AMD).                                                                                                                                                           |
| `fp8_e5m2`                   | CUDA 11.8+.                                                                                                                                                                          |
| `fp8_inc`                    | Intel Gaudi (HPU).                                                                                                                                                                   |
| `nvfp4`, `nvfp4_4over6`      | `nvfp4_4over6` uses the NVFP4 layout and picks `max/6` or `max/4` scales per 16 values by minimum squared error. Hardware and backend support: (unverified).                         |
| `fp8_ds_mla`, `nvfp4_ds_mla` | DeepSeek MLA-specific formats. Details (unverified).                                                                                                                                 |
| `*_per_token_head`           | Dynamic per-token-head scales computed at runtime (from the engine's log message). Hardware and model support: (unverified).                                                         |
| `turboquant_*`               | Present in the v0.31.0 enum; semantics and quality profile (unverified). Do not use without a thorough gate.                                                                         |

Scales and quality:

- `fp8` with no calibration sets every scale to `1.0`. Upstream recommends calibrating with `llm-compressor` (`kv_cache_scheme` in the recipe), which writes `k_scale`/`v_scale` into the checkpoint.
- Per-attention-head FP8 scales exist only with the Flash Attention backend and need llm-compressor calibration.
- With the Flash Attention 3 backend and FP8 KV cache, attention itself runs in FP8: queries are quantized as well as keys and values. Treat that as an additional numerics change.
- `--kv-cache-dtype-skip-layers <names or indices>`: leave those layers at model dtype. Accepts `sliding_window` or layer indices, for example `--kv-cache-dtype-skip-layers sliding_window` or `0 1 23`. Upstream notes sliding-window layers are more sensitive.
- DeepSeek V3.2 defaults to FP8 KV; set `bfloat16` to override. `bfloat16` is invalid for models that do not default to FP8.

Capacity: `kv_cache_memory_bytes` (when set) overrides `--gpu-memory-utilization` (default `0.92`). The engine reports KV capacity in tokens in its startup log.

## SGLang v0.5.21

Flag: `--kv-cache-dtype <dtype>`. Values: `auto`, `fp8_e5m2`, `fp8_e4m3`, `bf16`/`bfloat16`, `nvfp4`, `fp4_mx_block16`. Default is the model dtype.

| Value            | Notes                                                                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `fp8_e4m3`       | Upstream recommends it for accuracy. Range up to 240.                                                                                          |
| `fp8_e5m2`       | Larger dynamic range (up to 57344), lower precision.                                                                                           |
| `nvfp4`          | Experimental. 16-value blocks, E4M3 block scales, per-tensor global scale. Capacity multiplier `2 / 0.5625 = 3.56x` versus BF16 (theoretical). |
| `fp4_mx_block16` | Experimental. E2M1 block-16 compatibility recipe, not standard OCP MXFP4 (block 32).                                                           |

Constraints and options:

- Not every attention backend supports quantized KV. Without a fused kernel, upstream warns throughput can degrade extremely. Check the attention-backend support table in the SGLang docs before choosing.
- FP8 needs scaling factors: loaded from the checkpoint (`k_scale`, `v_scale` from ModelOpt-style checkpoints) or supplied with `--quantization-param-path <json>`. Format is `{"kv_cache": {"dtype": "float8_e4m3fn", "scaling_factor": {"<tp_rank>": {"<layer>": <float>}}}}`. Only per-tensor scalars. With none, scales default to `1.0` and accuracy may suffer. FP4 scales are computed on the fly.
- SM100 native NVFP4: add `--prefill-kv-cache-dequant-dtype nvfp4|fp8_e4m3|auto` (`auto` = native NVFP4 on SM100, FP8 E4M3 dequant on SM120) and `--page-size 16`. Native prefill needs SM100, a page size divisible by 4 and head dimension divisible by 64. Supported with top-k-1 EAGLE/EAGLE3/NEXTN and breadth-1 NGRAM (`--speculative-ngram-max-bfs-breadth=1`). Not supported on that path: other speculative algorithms, PD disaggregation, hierarchical KV cache, LMCache.
- Upstream accuracy examples are in `sizing-and-quality.md`.

## TensorRT-LLM v1.2.1

Config: `kv_cache_config` with `dtype`. Python: `LLM(model=..., kv_cache_config=KvCacheConfig(dtype='fp8'))`. For `trtllm-serve` use the `kv_cache_config: dtype:` key in the YAML passed with `--config` (key name per the LLM API; (unverified) for the exact CLI file name in your version).

- `dtype='fp8'`: can be enabled manually even for checkpoints that do not enable it by default. Marked supported on Blackwell (sm120 and sm100/103), Hopper, Ada and Ampere in the upstream hardware table. Model coverage is listed per architecture in the upstream "Model Supported Matrix" (most listed models support it).
- `dtype='nvfp4'`: needs offline quantization with ModelOpt (`--quant fp8 --kv_cache_quant nvfp4`; only FP8 weight/activation quantization is supported together with NVFP4 KV cache). Hardware: Blackwell sm100/103 only in the upstream table (not sm120, Hopper, Ada, Ampere). Models marked in the table at v1.2.1: LLaMA-v2, LLaMA 3, Qwen-3.
- The PyTorch backend (default) supports FP4 and FP8 quantization on the latest Blackwell and Hopper GPUs.

## llama.cpp (master docs, release v0.6.0)

Flags (server and CLI): `-ctk, --cache-type-k TYPE` and `-ctv, --cache-type-v TYPE`. Env `LLAMA_ARG_CACHE_TYPE_K`, `LLAMA_ARG_CACHE_TYPE_V`. Allowed: `f32`, `f16`, `bf16`, `q8_0`, `q4_0`, `q4_1`, `iq4_nl`, `q5_0`, `q5_1`. Default `f16`. Draft model equivalents: `-ctkd`/`--spec-draft-type-k` and `-ctvd`/`--spec-draft-type-v`.

- Flash attention: `-fa, --flash-attn [on|off|auto]`, default `auto` (env `LLAMA_ARG_FLASH_ATTN`). Quantized V cache needs flash attention (the "V cache quantization requires flash_attn" error wording is from memory of past builds, (unverified) for current master). Use `-fa on` to make it explicit.
- CUDA builds: when quantized K/V types are used with `-fa on` and the binary was built without `-DGGML_CUDA_FA_ALL_QUANTS=ON`, attention can silently fall back to CPU, reported as 25-45x slower prefill with 0% GPU use (issue #24485, closed as stale; a follow-up PR to warn about the fallback and one to allow mixed K/V types are referenced there; their merge status is (unverified)). Check GPU utilization during prefill after changing types, and rebuild with that flag if needed.
- Mixed K/V types such as `q8_0` K with `q4_0` V are accepted by the flag parser; kernel support depends on the build (see above). Keep K at higher precision than V when you must trade off (community practice; (unverified) upstream).
- `--swa-full` (default false) uses a full-size SWA cache and changes memory use for sliding-window models. `-kvu/--kv-unified` shares one KV buffer across slots (default on when slots are auto); `--kv-unified-per-slot N` sets the per-slot context limit.
- Offload of KV to CPU is a different knob (`-nkvo`); see the `kv-cache-offloading` skill.

## Ollama (docs FAQ, release v0.40.3)

- `OLLAMA_KV_CACHE_TYPE`: `f16` (default), `q8_0` (about 1/2 the memory of `f16`, "very small loss"), `q4_0` (about 1/4 the memory, "small-medium loss, may be more noticeable at higher context sizes").
- Requires Flash Attention. Ollama uses it automatically when the backend and devices support it; force with `OLLAMA_FLASH_ATTENTION=1`.
- Global setting: every model runs with the same type. Set it in the server environment (systemd `Environment=`, `launchctl setenv`, or Windows environment variables) and restart Ollama.
- Upstream warns models with a high GQA count (for example Qwen2) may see a larger precision impact.
- Memory also scales with `OLLAMA_NUM_PARALLEL x OLLAMA_CONTEXT_LENGTH` (default context 4096). Confirm placement with `ollama ps` (`100% GPU` versus a CPU/GPU split).
- Per-model KV type: none documented.

## ExLlamaV3 via TabbyAPI (config_sample.yml, ExLlamaV3 v1.6.1)

- `model.cache_mode`: default `FP16`. Pair `k_bits,v_bits`, each an integer 2-8, for example `8,8`. Legacy `FP16`, `Q8`, `Q6`, `Q4` still accepted.
- `model.cache_size`: KV cache size in tokens, default 4096, must be a multiple of 256. Increasing it is where the saved memory is spent.
- `draft_cache_mode` sets the draft model cache the same way.
- `use_as_default: ['cache_mode']` makes API loads reuse the configured value.
- Per-axis tradeoff and quality profiles per bit pair: (unverified upstream; run your gate).

## TensorFold v1.0.7

Upstream docs reviewed here document no KV dtype flag on the command line. The recipe layer carries a `KV_DTYPE` and `KV_POOL_GB` knob (per the `self-hosted-llms` skill's TensorFold reference, which treats them as recipe-owned). Allowed values and quality profile: (unverified). Run `tensorfold capabilities --json` on the installed version and read the recipe before changing anything; do not edit recipe defaults without approval, and gate the change.

## Sources

- https://docs.vllm.ai/en/latest/features/quantization/quantized_kvcache/
- https://github.com/vllm-project/vllm/blob/v0.31.0/docs/features/quantization/quantized_kvcache.md
- https://github.com/vllm-project/vllm/blob/v0.31.0/vllm/config/cache.py
- https://docs.sglang.ai/advanced_features/quantized_kv_cache.html
- https://github.com/NVIDIA/TensorRT-LLM/blob/v1.2.1/docs/source/features/quantization.md
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/ggml-org/llama.cpp/issues/24485
- https://docs.ollama.com/faq
- https://github.com/theroyallab/tabbyAPI/blob/main/config_sample.yml
- https://github.com/turboderp-org/exllamav3
- https://github.com/ashhart/TensorFold
