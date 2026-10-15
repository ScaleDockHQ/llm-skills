# GGUF quantization

Agent skill for producing GGUF quants with llama.cpp: convert a Hugging Face checkpoint to a 16-bit GGUF (plus `mmproj` for vision models), build an importance matrix, quantize with `llama-quantize` (K-quants, I-quants, per-tensor recipes), measure KL divergence against the 16-bit reference with `llama-perplexity`, split with `llama-gguf-split` and publish to the Hugging Face Hub.

Verified against llama.cpp v0.6.0 and master b11556 on 2026-10-11.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill gguf-quantization
```

## Rules

- **Ask before changing the system.** Builds, big downloads and uploads need approval.
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a `0600` file.
- **Always quantize from the 16-bit GGUF**, never from another quant.
- **Pin the llama.cpp tag** and record commands, imatrix source and KLD results in the model card.

## References

- [`references/install.md`](references/install.md): build llama.cpp per backend and set up the converter.
- [`references/convert.md`](references/convert.md): `convert_hf_to_gguf.py` options, mmproj, MTP, splitting.
- [`references/quant-types.md`](references/quant-types.md): every quant type, options, `--tensor-type` recipes.
- [`references/imatrix.md`](references/imatrix.md): `llama-imatrix`, calibration data, merging.
- [`references/quality-checks.md`](references/quality-checks.md): KLD and perplexity workflow and smoke test.
- [`references/publishing.md`](references/publishing.md): splitting, metadata, upload, model card.
- [`references/updating.md`](references/updating.md): new llama.cpp builds and requantizing.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/combos/imatrix-batch-and-publish.md`](references/combos/imatrix-batch-and-publish.md): one imatrix, many quants.
- [`scripts/make-quants.sh`](scripts/make-quants.sh): batch quantizer.

## Companion skills

- `llama-cpp`: serve the GGUF files.
- `model-quantization`: choose a format and method.
- `choosing-hardware`: size memory.
- `exl3-quantization`: the EXL3 equivalent.

## License

MIT
