# Merging adapters and exporting from Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/cli.qmd, docs/export.qmd, docs/getting-started.qmd on main), 2026-10-11

## Keep the adapter or merge?

Keep the adapter (`adapter_model.safetensors` + `adapter_config.json` in `output_dir`) for multi-LoRA serving and easy rollback (vLLM `--lora-modules`; skill `vllm`). Merge for single-model deploys, Ollama/LM Studio, or before quantizing.

## merge-lora

```bash
axolotl merge-lora cfg.yml                                        # uses output_dir, writes <output_dir>/merged
axolotl merge-lora cfg.yml --lora-model-dir ./outputs/lora-run/checkpoint-100
CUDA_VISIBLE_DEVICES="" axolotl merge-lora cfg.yml                # merge on CPU when out of GPU memory
axolotl merge-lora cfg.yml --dequant                              # quantized base -> bf16 checkpoint
```

- For a quantized base the default merge is format-preserving (delta folded in, re-quantized to the same format). `--dequant` writes bf16 instead; it is rejected for merge-aware NVFP4 adapters (`--override-quantizer` can proceed past a quantizer-identity mismatch; see https://docs.axolotl.ai/docs/nvfp4_lora.html).
- Use `axolotl merge-lora`, not hand-written scripts: Axolotl expands embeddings if the tokenizer has more tokens than the model, and your script will hit "size mismatch" errors.
- Config keys: `gpu_memory_limit`, `lora_on_cpu` (merging huge models).
- Verify the merged directory has weights, tokenizer files and the chat template, then compare a few outputs with the adapter run. Run merges memory-capped on shared machines.

## GGUF export

`axolotl export` shells out to a built llama.cpp checkout (not a Python dependency):

```bash
git clone https://github.com/ggml-org/llama.cpp
export LLAMA_CPP_DIR=$PWD/llama.cpp
cmake -S $LLAMA_CPP_DIR -B $LLAMA_CPP_DIR/build && cmake --build $LLAMA_CPP_DIR/build --config Release -j
axolotl merge-lora cfg.yml
axolotl export cfg.yml --quantize Q4_K_M,Q8_0
```

Building is only required to request quantized outputs; `llama-quantize` is looked up in `$LLAMA_CPP_DIR/build/bin/`, `$LLAMA_CPP_DIR/`, then `$PATH`. Config block:

```yaml
export:
  format: gguf
  outtype: f16 # f32, f16, bf16, q8_0, tq1_0, tq2_0, auto
  quantize: [Q4_K_M]
  outfile: # default {output_dir}/gguf/{run}-{ftype}.gguf
  llama_cpp_dir: # default $LLAMA_CPP_DIR
```

CLI overrides: `--outtype`, `--quantize`, `--outfile`, `--llama-cpp-dir`; `--model-dir` exports an arbitrary checkpoint. Each quant type becomes its own file next to the unquantized conversion.

Preflight failures to expect: adapter-only directory (merge first); pre-quantized checkpoint (torchao fp8/nvfp4, bitsandbytes: re-merge with `--dequant`); vocab mismatch between `tokenizer.json` and `config.json` (tokens added without resizing embeddings); multi-token-prediction layers (`num_nextn_predict_layers`) that llama.cpp cannot load; a missing chat template (warning only, but the runtime then falls back to a default and undoes your fine-tune).

Not supported yet by `axolotl export`: imatrix calibration, `gguf-split`, multimodal `mmproj`, exporting a LoRA adapter as standalone GGUF, pushing to the Hub. For those, use llama.cpp directly (skills `llama-cpp`, `model-quantization`).

Do **not** `pip install -r llama.cpp/requirements/...` into the Axolotl venv: they pin an older `transformers` and CPU-only `torch`. The converter runs under Axolotl's interpreter and loads `gguf-py` from the checkout.

For vLLM, SGLang or TGI, serve the merged safetensors directly (optionally quantized with torchao or LLM Compressor); vLLM's GGUF loader is experimental and slower (upstream note). See `references/combos/merge-llm-compressor-fp8-vllm.md`.

## Quantizing without GGUF

`axolotl quantize cfg.yml` applies torchao quantization; see https://docs.axolotl.ai/docs/quantize.html. QAT recipes are in `examples/llama-3/3b-qat-*.yaml`.
