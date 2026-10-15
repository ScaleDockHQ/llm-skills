---
name: gguf-quantization
description: Converts Hugging Face models to GGUF and quantizes them with llama.cpp (convert_hf_to_gguf.py, llama-imatrix, llama-quantize, llama-perplexity KLD, gguf-split, mmproj). Use for GGUF quants, Q4_K_M, IQ4_XS, IQ2, imatrix, --tensor-type recipes, KL divergence checks, splitting, publishing to Hugging Face. Not for serving (llama-cpp) or other formats (model-quantization).
license: MIT
compatibility: Linux or macOS, git, cmake, a C++ toolchain, Python 3.10+, curl and jq. Optional CUDA or Metal for imatrix speed. Large disk (source + 16-bit GGUF + every quant) and RAM about the 16-bit model size. Builds, downloads and uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# GGUF quantization with llama.cpp

Turn a Hugging Face checkpoint into a 16-bit GGUF, optionally compute an importance matrix, produce one or more quant types, check quality against the 16-bit reference with KL divergence, and (if asked) publish.

**Scope:** producing GGUF files: convert, imatrix, quantize, verify, split, publish. Running them belongs to `llama-cpp` (llama-server, Metal/CUDA tuning); choosing GGUF over EXL3, AWQ, FP8 or NVFP4 belongs to `model-quantization`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
# llama.cpp tools and source tree
for t in llama-quantize llama-imatrix llama-perplexity llama-gguf-split llama-server; do command -v $t || echo "missing $t"; done
ls ~/src/llama.cpp/build/bin/llama-quantize ~/src/llama.cpp/convert_hf_to_gguf.py 2>&1
git -C ~/src/llama.cpp describe --tags 2>&1 | tail -1      # pinned build
python3 --version; python3 -c "import torch,transformers;print(torch.__version__,transformers.__version__)" 2>&1 | tail -1
# source model: dtype, architecture, size
jq '{architectures,torch_dtype,dtype,num_hidden_layers,quantization_config}' ~/models/<model>/config.json
du -sh ~/models/<model>; df -h ~/models | tail -1; free -g 2>/dev/null | sed -n 2p
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv 2>/dev/null
python3 ~/src/llama.cpp/convert_hf_to_gguf.py --print-supported-models 2>&1 | grep -i "<arch>"
```

## Decision flow

1. **Already quantized upstream?** `quantization_config` present in `config.json` (GPTQ, AWQ, FP8...) means the source is not 16-bit. The converter has an `--fp8-as-q8` option for FP8 sources (otherwise it stores BF16/F16). Do not use GPTQ or AWQ checkpoints as a base ((unverified) whether the converter handles them); start from the original BF16 repo.
2. **Architecture supported?** `--print-supported-models` must list it. If not, update llama.cpp and `transformers` (`references/install.md`) or stop; never hand-edit tensors.
3. **Target bit width** (`references/quant-types.md`): Q8_0 near-lossless, Q6_K, Q5_K_M, Q4_K_M the default sweet spot, IQ4_XS smaller, below 4 bpw use I-quants with an imatrix. Size the result with `llama-quantize --dry-run` before spending time.
4. **imatrix?** Strongly recommended for anything at or below about 4 bpw and for all I-quants; optional above (`references/imatrix.md`). Calibrate on text like the workload.
5. **Multimodal?** Export `mmproj` separately and keep it BF16 or Q8_0 (`references/convert.md`).
6. **MoE or special tensors?** Use `--tensor-type` recipes (`references/quant-types.md`), always measured against KLD.
7. **Verify** with KL divergence versus the 16-bit GGUF (`references/quality-checks.md`), then split and publish only if asked (`references/publishing.md`).
8. **Failure?** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Building llama.cpp, installing Python packages, filling disks with 16-bit files and uploading to a hub need approval; use a venv and a memory-capped scope on shared boxes.
- **Secrets never touch output.** Read `HF_TOKEN` from the environment or a `0600` file; never print it or put it on a command line.
- **Always quantize from 16-bit.** Every quant comes from the BF16/F16 GGUF, never from another quant. `--allow-requantize` is for experiments only.
- **Pin and record.** Note the llama.cpp tag or commit, exact commands, imatrix dataset and its size in the model card.
- **No calibration on evaluation text.** Do not measure perplexity or KLD on the text the imatrix was built from.
- **Keep the 16-bit GGUF** until every quant is produced and checked.
- **Verify upstream.** Types, flags and defaults change; run `--help` of the binaries you built and trust it over these references.

## Workflows

- [ ] Build llama.cpp and the Python converter env, pinned -> `references/install.md`
- [ ] Convert HF to 16-bit GGUF, plus `mmproj` if vision/audio -> `references/convert.md`
- [ ] Build an importance matrix -> `references/imatrix.md`
- [ ] Choose types, size with `--dry-run`, quantize, custom recipes -> `references/quant-types.md`
- [ ] Measure KLD/perplexity vs the 16-bit reference, smoke-test with `llama-server` -> `references/quality-checks.md`
- [ ] Split large files, write the model card, upload -> `references/publishing.md`
- [ ] Batch several quants from one imatrix -> `scripts/make-quants.sh`, `references/combos/imatrix-batch-and-publish.md`
- [ ] Update llama.cpp and redo old quants -> `references/updating.md`
- [ ] Verify: the quant loads in `llama-server`, answers a prompt with the right chat template, KLD is recorded, and the card lists tag, commands and imatrix source.

## Quick path

```bash
cd ~/src/llama.cpp
python convert_hf_to_gguf.py ~/models/<model> --outtype bf16 --outfile ~/models/gguf/<model>-BF16.gguf
./build/bin/llama-imatrix -m ~/models/gguf/<model>-BF16.gguf -f calibration.txt -o ~/models/gguf/<model>.imatrix.gguf -ngl 99
./build/bin/llama-quantize --dry-run ~/models/gguf/<model>-BF16.gguf Q4_K_M            # size only
./build/bin/llama-quantize --imatrix ~/models/gguf/<model>.imatrix.gguf \
  ~/models/gguf/<model>-BF16.gguf ~/models/gguf/<model>-Q4_K_M.gguf Q4_K_M
```

## Reference index

- `references/install.md`: build llama.cpp per backend, converter venv, pinning, memory caps.
- `references/convert.md`: `convert_hf_to_gguf.py` options, outtypes, remote mode, mmproj, MTP drafts, splitting at convert time.
- `references/quant-types.md`: every `llama-quantize` type, options, `--tensor-type` recipes, pruning, sizing.
- `references/imatrix.md`: `llama-imatrix` flags, calibration data, merging, statistics, formats.
- `references/quality-checks.md`: KLD and perplexity workflow, interpreting metrics, smoke test.
- `references/publishing.md`: `llama-gguf-split`, Hub upload, naming, model card, metadata editing.
- `references/updating.md`: new llama.cpp releases, when to requantize.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/imatrix-batch-and-publish.md`: one imatrix, many quants, KLD table, upload.
- `scripts/make-quants.sh`: batch quantizer driven by environment variables.

## Companion skills

- `llama-cpp`: serve the result. Install: `npx skills add ScaleDockHQ/llm-skills --skill llama-cpp`.
- `model-quantization`: pick a format and method. Install: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`.
- `choosing-hardware`: size RAM and VRAM. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `exl3-quantization`: the EXL3 equivalent for NVIDIA GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill exl3-quantization`.
