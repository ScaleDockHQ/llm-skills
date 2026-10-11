---
name: exl3-quantization
description: Converts Hugging Face models to EXL3 with ExLlamaV3's convert.py (QTIP-style, fractional bits per weight) and measures the result. Use for EXL3 quants, exl3 bpw ladders, convert.py -b/-hb/-hq/-rcp/-cd, resume (-r), multi-GPU conversion, optimized recipes (sc_trace, sc_measure, sc_optimize), KLD checks, Hub branches. Serving is exllamav3; other formats are model-quantization.
license: MIT
compatibility: Linux or Windows with an NVIDIA GPU (AMD via ROCm builds), Python 3.10+, torch 2.6+ with CUDA 12.4+, curl and jq. Needs disk for the source, a full work-dir copy and the output. Installs, long conversions and uploads need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "1.0.0"
---

# EXL3 quantization with ExLlamaV3

Convert an unquantized Hugging Face checkpoint into an EXL3 model at a chosen average bitrate (any fractional value), check it against the original, and publish a bitrate ladder if asked.

**Scope:** producing EXL3 files with ExLlamaV3's converter and its eval tools. Installing the library and serving through TabbyAPI belong to `exllamav3`; choosing between EXL3, GGUF, AWQ, FP8 and NVFP4 belongs to `model-quantization`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Inspect the live system before changing anything. Every command is read-only and never prints secrets.

```bash
nvidia-smi --query-gpu=index,name,compute_cap,memory.total,memory.used --format=csv
python3 -c "import torch;print(torch.__version__, torch.version.cuda)" 2>&1 | tail -1
python3 -c "import exllamav3;print(exllamav3.__version__)" 2>&1 | tail -1
ls ~/src/exllamav3/convert.py 2>&1                          # the repo checkout holds convert.py and util/
jq '{architectures,torch_dtype,dtype,quantization_config,num_hidden_layers}' ~/models/<model>/config.json
ls ~/models/<model> | head -30                              # needs config.json, tokenizer.json, *.safetensors
du -sh ~/models/<model>; df -h ~/models ~/scratch 2>/dev/null; free -g 2>/dev/null | sed -n 2p
uname -m                                                    # aarch64 means a source build of the extension
```

## Decision flow

1. **Is EXL3 the target?** It serves on NVIDIA/AMD GPUs through ExLlamaV3/TabbyAPI, not vLLM, SGLang, llama.cpp or Apple Silicon. Otherwise stop and use `model-quantization`.
2. **Source ok?** It must be unquantized HF format (BF16/FP16 `.safetensors`, `config.json`, `tokenizer.json`) and its architecture must be in the upstream README table (`references/convert.md`). Anything else: stop or wait for upstream.
3. **Is a quant already published?** Check the Hub (`exl3` tag, per-bitrate branches) before spending hours; reuse it if the bitrate fits.
4. **Pick bitrates** from the memory budget: `params x bpw / 8` bytes plus KV cache (`references/bitrates-and-calibration.md`). Start with a ladder such as 3.0, 4.0, 5.0, 6.0.
5. **Pick options:** `-hq` for MoE, `-hb` for small models, `-vb`/`-mb`/`-eb` for vision, MTP and embeddings, `-d` for multiple GPUs (`references/convert.md`).
6. **Need the best quality at a small size?** The experimental recipe pipeline measures per-tensor sensitivity and calibrates on the model's own traces (`references/optimized-recipes.md`); not tested on sparse models upstream.
7. **Convert, then evaluate** against the original (`references/evaluation.md`), then smoke-test through `exllamav3`.
8. **Publish** only on request: one branch per bitrate (`references/publishing.md`).
9. **Failure or interrupted job?** `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, multi-hour jobs on the user's GPUs, and uploads need approval; check no server is holding the GPU (`nvidia-smi`).
- **Secrets never touch output.** `HF_TOKEN` comes from the environment or a `0600` file; do not paste it on command lines.
- **Work dir needs room.** `-w` must hold a full copy of the output; put it on fast disk and delete it only after the output is checked.
- **Resuming is explicit.** Re-running without `-r` starts over, and `-o` is overwritten if it exists. Use a fresh output directory per bitrate.
- **One job per GPU set.** A converter run uses device 0 by default; set `-d` or `CUDA_VISIBLE_DEVICES` deliberately.
- **Pin and record.** Note the exllamav3 version (tag or commit), exact command, bitrate, `-hb`, `-hq`, recipe and calibration data in the model card.
- **Verify upstream.** Flags come from `python convert.py -h` of the version you run; trust it over these references.

## Workflows

- [ ] Prepare environment: library and a checkout for `convert.py` -> `references/convert.md`, install details in the `exllamav3` skill
- [ ] Choose bitrate, head bits and special-tensor bits -> `references/bitrates-and-calibration.md`
- [ ] Convert, resume, multi-GPU -> `references/convert.md`, `scripts/convert-ladder.sh`
- [ ] Optional: optimized recipe plus in-domain calibration -> `references/optimized-recipes.md`
- [ ] Evaluate: perplexity, KLD against the original, then a serving smoke test -> `references/evaluation.md`
- [ ] Post-processing: recompile, embedding bits, vision tower, quantization_config.json -> `references/post-processing.md`
- [ ] Publish a bitrate ladder to the Hub -> `references/publishing.md`
- [ ] Update the library and decide what to redo -> `references/updating.md`
- [ ] Verify: the output loads in ExLlamaV3/TabbyAPI, answers a prompt, and the card states version, command, bitrate and metrics.

## Quick path

```bash
cd ~/src/exllamav3
python convert.py -i ~/models/<model> -o ~/models/<model>-exl3-4.0bpw -w ~/scratch/exl3-work -b 4.0
python convert.py -w ~/scratch/exl3-work -r                  # resume after an interruption
```

## Reference index

- `references/convert.md`: every `convert.py` argument, resume, multi-GPU, architecture support, memory and time.
- `references/bitrates-and-calibration.md`: sizing math, ladders, head/embedding/vision/MTP bits, `-hq`, calibration data.
- `references/optimized-recipes.md`: the sc_trace, sc_rfn_probe, sc_measure, sc_optimize, convert `-rcp -cd` pipeline.
- `references/evaluation.md`: `eval/ppl.py`, `eval/model_diff.py`, qbench, serving smoke test, gates.
- `references/post-processing.md`: `util/` tools: recompile, quantization config, vision conversion and transplant.
- `references/publishing.md`: naming, per-bitrate branches, model card, `hf` commands.
- `references/updating.md`: new ExLlamaV3 releases and when to requantize.
- `references/troubleshooting.md`: symptom to fix table.
- `references/combos/convert-then-serve-tabbyapi.md`: convert, check, then serve with TabbyAPI.
- `scripts/convert-ladder.sh`: convert several bitrates in sequence with resume.

## Companion skills

- `exllamav3`: install the library and serve EXL3 models with TabbyAPI. Install: `npx skills add ScaleDockHQ/llms-skills --skill exllamav3`.
- `model-quantization`: choose a format and method. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `choosing-hardware`: size VRAM and bandwidth. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `gguf-quantization`: the llama.cpp equivalent. Install: `npx skills add ScaleDockHQ/llms-skills --skill gguf-quantization`.
