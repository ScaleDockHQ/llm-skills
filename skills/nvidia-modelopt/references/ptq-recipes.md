# Post-training quantization with hf_ptq.py

> Verified against NVIDIA Model Optimizer 0.47.0 (examples/hf_ptq/README.md, examples/hf_ptq/hf_ptq.py argparse, examples/hf_ptq/scripts/parser.sh and huggingface_example.sh, modelopt_recipes/ directory listings, modelopt/torch/utils/dataset_utils.py, CHANGELOG.rst), TensorRT-LLM v1.2.1 (docs/source/features/quantization.md), 2026-10-11

`examples/hf_ptq/hf_ptq.py` loads a Hugging Face model, calibrates quantizers on a small dataset (typically 128 to 512 samples per upstream) and exports a unified Hugging Face checkpoint. Run it from a clone checked out at the installed tag (`install.md`).

## Minimal commands

```bash
cd ~/src/Model-Optimizer/examples/hf_ptq

# NVFP4 (Blackwell). KV cache defaults to fp8_cast.
python hf_ptq.py --pyt_ckpt_path ~/models/<model> --qformat nvfp4 --export_path ~/models/<model>-NVFP4

# NVFP4, accuracy-first: MLP/experts only, attention stays higher precision
python hf_ptq.py --pyt_ckpt_path ~/models/<model> --qformat nvfp4_mlp_only --export_path ~/models/<model>-NVFP4-mlp

# FP8 (Hopper, Ada, Blackwell)
python hf_ptq.py --pyt_ckpt_path ~/models/<model> --qformat fp8 --kv_cache_qformat fp8_cast --export_path ~/models/<model>-FP8

# Recipe instead of --qformat (a recipe takes precedence over --qformat)
python hf_ptq.py --pyt_ckpt_path <hub-id> --recipe general/ptq/nvfp4_default-kv_fp8_cast --export_path ~/models/<model>-NVFP4
```

Add `--trust_remote_code` only for models that need custom code (default off). Put the command in a memory-capped scope on shared or unified-memory machines (`model-quantization` skill, memory-safety).

Upstream's wrapper `scripts/huggingface_example.sh --model <path> --quant <qformat> [--tp N]` also works, but by default (`--tasks quant`) it finishes with `python run_tensorrt_llm.py`, which needs TensorRT-LLM, and it writes `saved_models_<name>` under the repo directory unless `ROOT_SAVE_PATH` is set. For NVFP4 it skips the deploy step when the GPU's compute capability major is below 10 and prints a message to deploy on a Blackwell GPU. Its defaults are `--calib 512` and `--calib_seq 512`.

## hf_ptq.py arguments (0.47.0)

| Argument                                                         | Default          | Meaning                                                                                |
| ---------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------- |
| `--pyt_ckpt_path` / `--model`                                    | required         | Local path or Hub id                                                                   |
| `--export_path`                                                  | `exported_model` | Output directory                                                                       |
| `--qformat`                                                      | `fp8`            | Preset basename under `modelopt_recipes/configs/ptq/presets/model/`                    |
| `--recipe`                                                       | none             | PTQ or AutoQuantize recipe name (no suffix) or YAML path; overrides `--qformat`        |
| `--kv_cache_qformat`                                             | `fp8_cast`       | KV cache format or `none` (ignored by PTQ recipes, see KV cache below)                 |
| `--calib_size`                                                   | `1024`           | Samples, or a comma-separated list, one per dataset                                    |
| `--calib_seq`                                                    | `512`            | Max calibration sequence length                                                        |
| `--batch_size`                                                   | `0`              | Calibration batch size; 0 computes the max batch size on the fly                       |
| `--dataset`                                                      | none             | Dataset name or comma list; none means the `cnn_nemotron_v2_mix` combo                 |
| `--device`                                                       | `cuda`           |                                                                                        |
| `--trust_remote_code`                                            | off              | For custom-code models and tokenizers                                                  |
| `--inference_tensor_parallel` / `--inference_pipeline_parallel`  | `1` / `1`        | TP and PP sizes baked into the export                                                  |
| `--awq_block_size`                                               | `0`              | AWQ block size                                                                         |
| `--low_memory_mode`                                              | off              | Compress weights before calibration (experimental; FP8 and NVFP4 with max calibration) |
| `--use_seq_device_map`, `--gpu_max_mem_percentage`               | off, `0.8`       | Sequential device map, fraction of GPU memory to use                                   |
| `--offload_folder`, `--max_cpu_memory_gb`, `--max_gpu_memory_gb` | none             | Disk-offload mode with RAM and per-GPU budgets                                         |
| `--use_fsdp2`, `--cpu_offload`                                   | off              | Multi-GPU or multi-node calibration under `torchrun`                                   |
| `--moe_calib_experts_ratio`                                      | none             | Fraction of experts calibrated per forward pass (MoE only, `(0.0, 1.0]`)               |
| `--auto_quantize_checkpoint`                                     | none             | Save or restore AutoQuantize search state                                              |
| `--cast_mxfp4_to_nvfp4`                                          | off              | Bit-exact MXFP4 to NVFP4 for gpt-oss style checkpoints                                 |
| `--calib_with_images`                                            | off              | Image-text calibration for VLMs                                                        |
| `--skip_generate`                                                | off              | Skip pre and post generation previews (calibration still runs)                         |
| `--attn_implementation`                                          | none             | Passed to HF model loading                                                             |
| `--vllm_fakequant_export`                                        | off              | Fake-quant export for vLLM research flows (see upstream `examples/vllm_serve`)         |
| `--export_fmt`                                                   | `hf`             | Deprecated, do not use                                                                 |

Run `python hf_ptq.py --help` in your tag before relying on a flag.

## Choosing a format

`--qformat` accepts any preset basename in `modelopt_recipes/configs/ptq/presets/model/` at 0.47.0:

`fp8`, `fp8_2d_blockwise_weight_only`, `fp8_per_channel_per_token`, `int4_awq`, `int4_blockwise_weight_only`, `int8`, `int8_smoothquant`, `int8_weight_only`, `mxfp4`, `mxfp4_mlp_weight_only`, `mxfp6`, `mxfp8`, `mxint8`, `nvfp4`, `nvfp4_awq_clip`, `nvfp4_awq_full`, `nvfp4_awq_lite`, `nvfp4_experts_only`, `nvfp4_four_over_six`, `nvfp4_fp8_mha`, `nvfp4_mlp_only`, `nvfp4_mlp_weight_only`, `nvfp4_omlp_only`, `nvfp4_svdquant`, `nvfp4_w4a4_weight_local_hessian`, `nvfp4_w4a4_weight_mse_fp8_sweep`, `w4a16_nvfp4`, `w4a8_awq_beta`, `w4a8_mxfp4_fp8`, `w4a8_nvfp4_fp8`, plus `mamba_moe_*` presets for Mamba/MoE hybrids. Old short names (`int8_sq`, `int8_wo`, `w4a8_awq`, `nvfp4_awq`, `nvfp4_mse`, `nvfp4_local_hessian`, `fp8_pb_wo`, `fp8_pc_pt`) were removed in 0.47.0 (changelog).

| GPU         | Start with                                                                     | Notes                                                                                     |
| ----------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| Blackwell   | `nvfp4_mlp_only`, `nvfp4_experts_only` (MoE), `nvfp4`; `fp8` for safer quality | Upstream: NVFP4 inference requires Blackwell (TensorRT-LLM v1.2 or later for TRT-LLM)     |
| Hopper, Ada | `fp8`                                                                          | TRT-LLM matrix: FP8 per tensor on Hopper and Ada; FP8 block scaling and rowwise on Hopper |
| Ampere      | `int4_awq`                                                                     | TRT-LLM matrix lists W4A16 AWQ and W4A16 GPTQ on Ampere, not FP8 or NVFP4                 |

Accuracy guidance from upstream: for NVFP4 use `nvfp4_mlp_only`, `nvfp4_experts_only` or `nvfp4_omlp_only`. `nvfp4_mlp_only` quantizes MLP and MoE layers and leaves attention unquantized; `nvfp4_experts_only` quantizes only expert layers (`*mlp.experts*`, `*block_sparse_moe*`); `nvfp4_omlp_only` also quantizes `o_proj`. All keep attention QKV projections in higher precision. If accuracy after PTQ is not enough, disable KV cache quantization or use QAT (upstream). The README's per-model support matrix (fp8, int8_smoothquant, int4_awq, w4a8_awq_beta, nvfp4 by model family) is in `examples/hf_ptq/README.md#support-matrix`; it is "a subset of the models supported".

## Recipes

A recipe is a YAML bundle of quantization config including KV cache. Names are resolved without the `.yaml` suffix.

- PTQ: `modelopt_recipes/general/ptq/` at 0.47.0 includes `fp8_default-kv_fp8`, `fp8_default-kv_fp8_cast`, `nvfp4_default-kv_fp8_cast`, `nvfp4_default-kv_fp8`, `nvfp4_default-kv_nvfp4_cast`, `nvfp4_mlp_only-kv_fp8_cast`, `nvfp4_mlp_only-kv_fp8`, `nvfp4_experts_only-kv_fp8_cast`, `nvfp4_experts_only-kv_fp8`, `nvfp4_omlp_only-kv_fp8_cast`, `nvfp4_omlp_only-kv_fp8`, `nvfp4_weight_only-kv_fp8_cast`, `nvfp4_default-kv_none-gptq` and variants (`*_mse`, `*_layerwise`, `*_layerwise_offload`).
- Model-type recipes: `modelopt_recipes/huggingface/<model_type>/ptq/` (for example Step-3.7 uses `huggingface/step3p7/ptq/nvfp4_experts_only-kv_fp8_cast`). Checkpoint-mirror recipes moved in 0.47.0 to top-level `models/<org>/<model_id>/ptq/`.
- A custom YAML path or directory also works. When `--recipe` is set, `--qformat` is ignored.

## KV cache

`--kv_cache_qformat` (default `fp8_cast`):

| Format                         | Meaning                                                 |
| ------------------------------ | ------------------------------------------------------- |
| `fp8_cast` (default)           | FP8 KV cache, amax set to the FP8 range, no calibration |
| `fp8`                          | FP8 with data-driven calibration                        |
| `fp8_affine`                   | FP8 with affine quantization                            |
| `nvfp4_cast`                   | NVFP4 KV cache without data-driven calibration          |
| `nvfp4`                        | NVFP4 with data-driven calibration                      |
| `nvfp4_affine`, `nvfp4_rotate` | NVFP4 affine / with rotation                            |
| `none`                         | No KV cache quantization                                |

A PTQ recipe bakes in its KV format and ignores `--kv_cache_qformat`; an AutoQuantize recipe uses `--kv_cache_qformat` unless it sets its own. TensorRT-LLM currently supports FP8 weight and activation quantization with an NVFP4 KV cache (`--quant fp8` with `--kv_cache_quant nvfp4`), per its quantization doc. SGLang's doc says the default `kv_cache_qformat` is `fp8`; the 0.47.0 script default is `fp8_cast`, so set it explicitly. Serve-time KV choices: `kv-cache-quantization` skill.

## AutoQuantize (mixed precision to a bit budget)

AutoQuantize searches a format per layer to hit an `effective_bits` target; sensitive layers stay in higher precision. In 0.47.0 it is driven by `--recipe` (the `--auto_quantize_*` flags were removed):

```bash
python hf_ptq.py --pyt_ckpt_path <model> \
  --recipe general/auto_quantize/nvfp4_fp8_at_5p4bits \
  --auto_quantize_checkpoint ./autoq_state.pth --export_path ~/models/<model>-mixed
```

Shipped recipes in `modelopt_recipes/general/auto_quantize/`: `nvfp4_fp8_at_5p4bits`, `nvfp4_fp8_kl_div_at_5p4bits`, `nvfp4_mse_fp8_at_6p0bits`, `w4a16_nvfp4_fp8_at_6p0bits-active_moe`, `w4a8_awq_beta_fp8_at_6p0bits`. The README's example also passes `--calib_batch_size 4` through the wrapper script. Copy a shipped recipe to adjust `candidate_formats`, `constraints.effective_bits`, `auto_quantize_method` (`gradient` or `kl_div`), `disabled_layers` and `cost_excluded_layers`. An old `--auto_quantize_checkpoint` from an earlier release can be rejected ("Use a different checkpoint path"): delete or repoint it.

## Memory

- `--low_memory_mode`: compress weights before calibration; experimental, FP8 and NVFP4 with max calibration only, not combined with disk offload.
- `--use_seq_device_map` (+ `--gpu_max_mem_percentage`, default 0.8): sequential device map when `device_map=auto` loads unevenly and OOMs.
- `--offload_folder` + `--max_cpu_memory_gb` + `--max_gpu_memory_gb`: stream weights from disk during calibration and export; upstream notes insufficient GPU memory "may cause weight offloading, resulting in extremely long quantization time" (SGLang's ModelOpt doc), and recommends Hopper or newer.
- Multi-node: `torchrun --nnodes N ... hf_ptq.py ... --use_fsdp2` (Slurm example in `examples/hf_ptq/slurm/multinode_fsdp2_ptq.slurm`). v1 supports standard causal-LM only (not VLM, speculative, AutoQuantize, sparsity). FSDP2 can make calibration and export slower than a single node, so maximize the batch size.
- Mismatched tensor placement on multi-GPU: set `CUDA_VISIBLE_DEVICES` to fewer GPUs.
- Python API for compressed-weight init: `init_quantized_weights(mtq.NVFP4_DEFAULT_CFG)` around `from_pretrained`, then `mtq.calibrate(model, algorithm="max", forward_loop=...)` (upstream "Real Quant").

## Calibration

By default `hf_ptq.py` mixes `cnn_dailymail` and `nemotron-post-training-dataset-v2` (the `cnn_nemotron_v2_mix` combo). `--dataset` takes names from `get_supported_datasets()`; at 0.47.0 the registry includes `cnn_dailymail`, `pile`, `pg19`, `wikipedia`, `c4`, `wikitext`, `magpie`, several `nemotron-*` datasets, `open_code_reasoning` and `open_math_reasoning`. Upstream says PTQ accuracy "is typically robust across different choices of calibration data". For reasoning or long-context models raise `--calib_seq` and `--calib_size` (costs time). Calibration pads on the left by default; the exported tokenizer restores the default padding side. Record dataset, size and sequence length in the model card.

## MoE, VLM, gpt-oss, DeepSeek, Kimi

- MoE: use `nvfp4_experts_only`; `--moe_calib_experts_ratio` calibrates only a fraction of experts per pass to save time (advice: keep 1.0 or default for the first run).
- VLM: pass `--vlm` to the wrapper script; only the language model is quantized and the vision encoder stays high precision. `--calib_with_images` uses `nvidia/nemotron_vlm_dataset_v2` and is beta, tested on Nemotron Nano 12B v2 VL. In 0.47.0 image-text calibration forwards multimodal batches through the complete VLM for all VLM families, which can change activation ranges versus earlier releases (changelog).
- gpt-oss ships MXFP4 weights: `--qformat nvfp4_mlp_only --cast_mxfp4_to_nvfp4` produces a closed-form NVFP4 export without recalibrating weights; requires an NVFP4-family qformat and is incompatible with AutoQuantize recipes.
- DeepSeek and Kimi K3 have dedicated READMEs (`examples/deepseek`, `examples/kimi`). Kimi K3 uses a calibration-free streaming converter, not `hf_ptq.py`.

## After the run

`scripts/inspect-checkpoint.sh <export_path>` should show `quant_algo` (for example `NVFP4`), the KV algo and `exclude_modules`. A quant_algo of null means nothing was quantized: 0.47.0 `mtq.quantize` now raises when a config asks for weight quantization but no pattern matches (escape hatch `MODELOPT_SKIP_WEIGHT_QUANT_CHECK=1`), so use the model-type recipe instead. Then deploy (`export-and-deploy.md`).
