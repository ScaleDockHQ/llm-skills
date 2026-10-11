# Troubleshooting LLM Compressor

> Verified against llm-compressor 0.14.0 (docs/faq/faq.md, docs/guides/memory.md, docs/guides/big_models_and_distributed/_, docs/guides/entrypoints/_, examples/disk_offloading/qwen3_example.py, release notes 0.13.0 and 0.14.0), vLLM v0.31.0 (docs/features/quantization), 2026-10-11

Entries marked "(advice)" are practical guidance not stated verbatim upstream. Everything else is from the cited upstream docs. Exact error strings change between releases: match on the cause, and read the traceback.

## Quantized model is not faster

Cause (upstream FAQ 1): the model was run through plain `transformers`, which decompresses it, so there is no inference benefit. Serve it with vLLM (`vllm-integration.md`). Also check the scheme against the GPU: NVFP4 below Blackwell and FP8 below compute capability 8.9 run weight-only.

## Import or install errors

- `No module named llmcompressor`: you are in the wrong venv; activate the one from `install.md`.
- `transformers` or `torch` version errors: 0.14.0 requires `transformers>=5.15.0,<=5.17.0`, `torch>=2.10.0,<=2.14.0`, `compressed-tensors==0.19.0`. Reinstall into a clean venv rather than mixing with vLLM (upstream says the two can mismatch).
- Saving a disk-offloaded model fails on `transformers==5.14`: upstream's example says to use `transformers>=5.15` or install from source.

## Out of memory

- CPU RAM: the BF16 model is about `2 x parameters` bytes. Load with `load_context()` + `device_map="auto_offload"` + `offload_folder` (`big-models.md`).
- GPU during calibration: use the `sequential` pipeline (default for calibrated recipes), set `sequential_targets="Linear"` for smaller onloaded units (slower), lower `max_seq_length` or `batch_size`, or move activations with `sequential_offload_device`.
- GPTQ needs a Hessian per onloaded layer, about double RTN's per-layer GPU memory. Switch to RTN or AWQ if the GPU is tiny (advice).
- Vision-language models: the vision tower loads to the GPU all at once and may be larger than a text layer.
- Unified-memory machines: stop serving first and cap the process memory (advice; see the `model-quantization` skill, memory-safety reference).

## Calibration runs but accuracy dropped

1. Run the base and the quant through the same smoke prompts and a perplexity or eval check (`model-quantization`, `llm-evals`).
2. Calibrate on workload-like, chat-formatted data and raise `num_calibration_samples` or `max_seq_length` (`calibration-data.md`).
3. Move to a stronger algorithm: RTN to AWQ or GPTQ; for NVFP4, GPTQ/AWQ or a more careful scheme. Upstream's 0.14.0 notes say the new expanded MSE observer outperforms GPTQ for NVFP4 on average in their benchmarks; check the observer docs (`docs/guides/observers.md`) before relying on it.
4. Keep sensitive layers unquantized: `lm_head`, MoE routers (`re:.*mlp.gate$`), and anything the model card of an upstream checkpoint excludes.
5. Use FP8 or W8A8 instead of 4-bit if memory allows.

## MoE model quantizes badly or some experts look empty

Keep `moe_calibrate_all_experts=True` (default), use enough samples (`min_tokens_per_module` warns when a module gets too few tokens), ignore the router, and load inside `load_context()`. New architectures may need MoE support code upstream (`docs/developer-tutorials/add-moe-support.md`). 0.14.0 added `patch_moe_mappings()` and `repack_moe()` helpers (release notes).

## `oneshot` fails for a new model architecture

Try `model_free_ptq` for data-free schemes (upstream: use it when the model has no transformers definition or when `oneshot` fails). Otherwise check upstream issues for the architecture and try the main branch: `pip install git+https://github.com/vllm-project/llm-compressor.git` in a scratch venv.

## Multimodal and audio models

The non-text tower is not quantized. See `examples/multimodal_vision` and `examples/multimodal_audio`; calibrate with `flickr` or `peoples_speech` style data (`calibration-data.md`).

## vLLM does not load or hangs

- Version skew: a checkpoint from a newer compressed-tensors may need a newer vLLM. Compare versions (`vllm-integration.md`).
- Hang with no error on FP8: try `VLLM_USE_DEEP_GEMM=0` or `--linear-backend cutlass` (vLLM FP8 docs).
- Wrong or slow kernel: read the `Selected <kernel> for <module>` line at startup.
- Missing tokenizer files: you forgot `tokenizer.save_pretrained(SAVE_DIR)`.
- `trust_remote_code` models need the flag on loading and on `vllm serve --trust-remote-code` (advice).

## DDP problems

Call `init_dist()` before `load_context()`, load the model with `device_map="auto_offload"`, give each rank its own data slice, call `save_pretrained` on all ranks and `destroy_process_group()` at the end. Run under `torchrun` (`big-models.md`).

## Sparse (2:4) recipes

No longer supported by LLM Compressor (upstream compression-schemes doc).

## Still stuck

Open or search issues at https://github.com/vllm-project/llm-compressor/issues; upstream suggests the `#llm-compressor` and `#sig-quantization` channels in the vLLM Slack. Include `pip freeze` for the four key packages, the script, the GPU and the full traceback, with tokens removed.
