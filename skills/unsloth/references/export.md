# Exporting from Unsloth: adapter, merged, GGUF

> Verified against unslothai/unsloth library 2026.10.3 (docs: saving-to-gguf, saving-to-ollama, Studio export; unsloth/save.py on main), llama.cpp (build instructions from docs), 2026-10-11

## Options

| Goal              | Call                                                                                                                             | Notes                                                                   |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| LoRA adapter only | `model.save_pretrained(dir)` + `tokenizer.save_pretrained(dir)`; or `save_pretrained_merged(dir, tokenizer, save_method="lora")` | PEFT format; vLLM `--lora-modules`, llama.cpp `convert_lora_to_gguf.py` |
| Merged 16-bit     | `model.save_pretrained_merged("merged_model", tokenizer, save_method="merged_16bit")`                                            | Use for vLLM, and before any re-quantization                            |
| Merged 4-bit      | `save_method="merged_4bit"`                                                                                                      | Lossy; do not re-quantize or train further from it                      |
| GGUF              | `model.save_pretrained_gguf("dir", tokenizer, quantization_method="q4_k_m")`                                                     | Builds llama.cpp as needed                                              |
| Push to Hub       | `model.push_to_hub_gguf("user/repo", tokenizer, quantization_method="q4_k_m")`, `push_to_hub_merged`                             | Needs a Hugging Face write token from the environment                   |

`quantization_method` accepts one value or a list (`["q4_k_m", "q8_0", "q5_k_m"]` per `save_to_gguf` in the source). Upstream-documented values: `not_quantized`, `fast_quantized`, `quantized`, `f32`, `bf16`, `f16`, `q8_0`, `q6_k`, `q5_k_m`, `q5_k_s`, `q5_0`, `q5_1`, `q4_k_m`, `q4_k_s`, `q4_0`, `q4_1`, `q3_k_l`, `q3_k_m`, `q3_k_s`, `q3_k_xs`, `q2_k`, `q2_k_l` (aliases `q4_k` = `q4_k_m`, `q5_k` = `q5_k_m`). IQ quants (`iq1_s` ... `iq4_xs`) need an importance matrix: pass `imatrix_file=True` or a path (source on main; not in the docs page). Quant choice and imatrix practice: skill `model-quantization`.

On main, `save_pretrained_merged(..., save_method=...)` also accepts compressed-tensors exports for vLLM (`fp8`, `fp8_dynamic`, `fp8_block`, `w4a16`, `nvfp4`, `mxfp4`, ...; calibration needed only for `fp8_static` and `nvfp4`), implemented via LLM Compressor. This appears in `unsloth/save.py` but not in the docs pages read, so treat it as **unverified** for 2026.10.3 and prefer skill `llm-compressor` for a documented FP8 path.

## Memory and speed

- Saving can OOM. Lower the GPU peak with `maximum_memory_usage` (the docs say default 0.75; the source `unsloth_save_model` default is 0.9, an upstream inconsistency): for example `model.save_pretrained_merged(..., maximum_memory_usage=0.5)`.
- GGUF export builds llama.cpp and needs RAM; on unified-memory machines stop model servers first and run capped.
- Conversion to `q4_k_m` can take minutes (the Ollama tutorial says 5-10 minutes in Colab).

## Manual GGUF (upstream recipe)

```python
model.save_pretrained_merged("merged_model", tokenizer, save_method="merged_16bit")
```

```bash
git clone https://github.com/ggml-org/llama.cpp
cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON -DLLAMA_CURL=ON
cmake --build llama.cpp/build --config Release -j --clean-first \
  --target llama-cli llama-mtmd-cli llama-server llama-gguf-split
python llama.cpp/convert_hf_to_gguf.py merged_model --outfile model-F16.gguf --outtype f16 --split-max-size 50G
```

`--outtype` also takes `bf16` and `q8_0`. The upstream recipe uses `apt-get install pciutils build-essential cmake curl libcurl4-openssl-dev` (Debian/Ubuntu); drop `-DGGML_CUDA=ON` for CPU builds. Install the converter's Python requirements in a separate venv, not the training one (skill `llama-cpp`).

## Studio export

Studio's export page picks a training run and checkpoint, then exports Merged Model (16-bit), LoRA Only, or GGUF / llama.cpp, saved locally or pushed to the Hub (`references/studio.md`). The repo also has `unsloth export` with `--format`, `--quantization`, `--push-to-hub`, `--repo-id`, `--private`, `--max-seq-length`; those options come from `unsloth_cli/commands/export.py` and are **unverified** against docs.

## After export

1. Load the result in the target engine, not Unsloth, and compare outputs on the same held-out prompts.
2. Check the chat template and EOS token match training (`references/troubleshooting.md`).
3. Ollama: `references/combos/gguf-ollama.md`. vLLM: serve merged 16-bit or the adapter (skill `vllm`).
