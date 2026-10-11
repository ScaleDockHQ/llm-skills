# Troubleshooting NVIDIA Model Optimizer

> Verified against NVIDIA Model Optimizer 0.47.0 (CHANGELOG.rst, examples/hf_ptq/README.md, hf_ptq.py argparse help text, docs/source/getting_started), vLLM v0.31.0 (docs/features/quantization/modelopt.md), TensorRT-LLM v1.2.1 (docs/source/features/quantization.md), 2026-10-11

Entries marked "(advice)" are practical guidance not stated verbatim upstream. Match on the cause; exact messages vary by release.

## Paths and flags from old tutorials do not exist

- `examples/llm_ptq` or `examples/vlm_ptq` missing: removed in 0.47.0. Use `examples/hf_ptq`, and `--vlm` for vision-language models. TensorRT-LLM's and vLLM's quantization pages still show `examples/llm_ptq` and the `TensorRT-Model-Optimizer` repo name.
- Unknown `--qformat` such as `int8_sq`, `w4a8_awq`, `nvfp4_awq`, `nvfp4_mse`, `nvfp4_local_hessian`, `fp8_pb_wo`, `fp8_pc_pt`: removed in 0.47.0. Use `int8_smoothquant`, `w4a8_awq_beta`, `nvfp4_awq_lite`, `nvfp4_w4a4_weight_mse_fp8_sweep`, `nvfp4_w4a4_weight_local_hessian`, `fp8_2d_blockwise_weight_only`, `fp8_per_channel_per_token`.
- `--auto_quantize_bits` and the other `--auto_quantize_*` flags: removed. Use an AutoQuantize `--recipe` (`ptq-recipes.md`).
- `--export_fmt`: deprecated, do not use.
- A saved `--recipe` path for a checkpoint-mirror recipe fails: those moved to `models/<org>/<model_id>/ptq/` in 0.47.0.
- `--quant_cfg`-style in-trainer quantization and `layerwise` legacy config keys: removed in 0.47.0 (changelog); use `--recipe` and the nested `layerwise: {enable: true, checkpoint_dir: ...}` form.

## Import and install

- `No module named modelopt`: wrong venv, or the package is `nvidia-modelopt` (not `modelopt`). `pip show nvidia-modelopt`.
- Python 3.15 or older than 3.10: unsupported (`>=3.10,<3.15`).
- `hf_ptq.py` not found: it lives in the cloned repo, not the wheel (`install.md`). Check out the tag matching `pip show nvidia-modelopt`.
- `flash-attn` build trouble from `examples/hf_ptq/requirements.txt`: install the other requirements first and see if your model needs it (advice).
- First PTQ call is slow: fast quantization kernels compile on first use; pre-compile with `python -c "import modelopt.torch.quantization.extensions as ext; ext.precompile()"` (upstream tip).

## Calibration out of memory

1. Stop other model servers on the GPU (and on unified-memory machines cap memory; `model-quantization` skill).
2. `--use_seq_device_map` (with `--gpu_max_mem_percentage`, default 0.8) when `device_map=auto` loads unevenly across GPUs.
3. `--low_memory_mode` for FP8 and NVFP4 with max calibration (experimental).
4. `--offload_folder` with `--max_cpu_memory_gb` and `--max_gpu_memory_gb` for disk offload; expect very long runs.
5. Smaller `--batch_size` (default 0 probes the max, which can itself be heavy); pair `--skip_generate` with `--batch_size 1` for very large models (help text).
6. Multi-GPU "Expected all tensors to be on the same device": set `CUDA_VISIBLE_DEVICES` to fewer GPUs.
7. Multi-node: `--use_fsdp2` under `torchrun` (`ptq-recipes.md`).

## Export or quantization-state errors

- `activation scaling factor 0.0 not positive` on export: fixed in 0.47.0; a dynamic-block quantizer whose layer or expert never fired now exports a fallback scale with a warning. If you see the warning, check whether that layer is expected to be inactive and consider a larger `--calib_size` (changelog).
- `mtq.quantize` raises because no weight-quantizer pattern matches the model: 0.47.0 guards against silently exporting an unquantized checkpoint (`quant_algo: null`). Use the model-type recipe under `modelopt_recipes/huggingface/<model_type>/`, or fix the patterns. `MODELOPT_SKIP_WEIGHT_QUANT_CHECK=1` disables the check process-wide, for example for a pipeline-parallel rank with none of the targeted modules (changelog).
- AutoQuantize checkpoint rejected with "Use a different checkpoint path": delete or repoint `--auto_quantize_checkpoint`; search state from earlier releases is incompatible for VL models (changelog).
- Checkpoints containing quantized `TEGroupedLinear` (Megatron path) saved before 0.47 are not compatible with 0.47: re-run PTQ.
- Qwen3.5/3.6 MoE exported through Megatron-Core could not be loaded by vLLM (`Layer ... has no parameter 'w2_weight_weight_scale_2'`): fixed in 0.47.0, re-export with that release.

## Accuracy dropped

1. Compare the quant with its base on the same smoke prompts and evals (`model-quantization`, `llm-evals`).
2. NVFP4: switch from `nvfp4` to `nvfp4_mlp_only`, `nvfp4_experts_only` or `nvfp4_omlp_only` (keeps attention QKV in higher precision), or to `fp8`.
3. Disable KV cache quantization: `--kv_cache_qformat none` (upstream suggestion), or use `fp8` (data-driven) instead of `fp8_cast`.
4. More calibration data or longer sequences: `--calib_size`, `--calib_seq`; use workload-like data.
5. Try AutoQuantize at a higher effective-bits target, or QAT (upstream suggests QAT when PTQ is not enough).
6. Smaller base models usually lose more accuracy after PTQ (upstream).

## Engine does not load or is slow

- NVFP4 runs weight-only on non-Blackwell GPUs (Marlin fallback in vLLM and SGLang), so memory shrinks but compute does not speed up.
- NVFP4 on DGX Spark (compute capability 12.1): TensorRT-LLM's matrix names sm120 and sm100/103; native FP4 GEMM on sm121 in a particular build is (unverified). Read the log line for the selected GEMM backend.
- vLLM reports an unsupported `quant_algo`: compare the checkpoint's `hf_quant_config.json` with the list in `export-and-deploy.md` and update vLLM.
- Old engine version: stated minimums are TensorRT-LLM 1.2.0, vLLM 0.10.1, SGLang 0.4.10; newer model families need newer engines.
- `--quantization` mismatch: let vLLM auto-detect, or use `modelopt` (FP8) and `modelopt_fp4` (NVFP4); SGLang uses `modelopt_fp8` and `modelopt_fp4`.
- Evaluating with `lm_eval` through TensorRT-LLM: loglikelihood tasks need TensorRT-LLM 1.3.0rc11 or newer and `lm_eval_trtllm.py` (changelog note on 0.47.0).

## Still stuck

Search or file issues at https://github.com/NVIDIA/Model-Optimizer/issues (bug template in the README). Include `pip show nvidia-modelopt torch transformers`, the command, the GPU and the traceback with tokens removed.
