---
name: axolotl
description: Axolotl is a YAML-driven LLM fine-tuning framework (axolotl CLI) for LoRA, QLoRA, full fine-tuning, SFT, DPO, KTO and GRPO on Hugging Face models. Use to install it (uv, axolotlai/axolotl Docker, arm64), write and debug configs, run axolotl preprocess/train/merge-lora/export, go multi-GPU (FSDP2, DeepSpeed), or fix errors such as exitcode -9, "Could not find content start/end boundary", missing pad_token, vocab size mismatch. Not for choosing a tuning method (fine-tuning-llms) or Unsloth/TRL scripts (unsloth, trl).
license: MIT
compatibility: Linux with an NVIDIA (Ampere+ for bf16) or AMD GPU, Python 3.12+, uv or Docker. Uses axolotl, curl and jq via shell. Installs, training runs, merges and GGUF builds need the user's approval; model servers may need stopping first.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Axolotl

Run reproducible fine-tuning from one YAML config with the `axolotl` CLI: preprocess the data, train, evaluate, merge adapters and export to GGUF, then hand the result to a serving engine.

**Scope:** this one product: install, configure, train, scale out, merge/export, update, troubleshoot. Whether to fine-tune, data prep and method choice belong to `fine-tuning-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
command -v axolotl && axolotl --help | head -20
python3 -c 'import torch; print("torch", torch.__version__, "cuda", torch.cuda.is_available())' 2>/dev/null
python3 --version; command -v uv docker
nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap --format=csv 2>/dev/null
uname -m; free -h 2>/dev/null | head -2; df -h . ~/.cache/huggingface 2>/dev/null
docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i axolotl
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
ls *.yml *.yaml 2>/dev/null
```

## Decision flow

1. No `axolotl` and Python < 3.12 or no uv, or an arm64 box -> Docker `axolotlai/axolotl` (`references/install.md`). Otherwise uv.
2. Blackwell GPU (B100/B200/B300/RTX 50) -> CUDA 13.0 builds, PyTorch >= 2.11 (`references/install.md`).
3. One GPU, SFT on messages JSONL -> copy `templates/lora-sft.yaml` (`references/config.md`). Not enough VRAM -> QLoRA (`load_in_4bit: true`, `adapter: qlora`).
4. Preference pairs or RL -> `rl: dpo|kto|orpo|grpo` (`references/rl-and-grpo.md`).
5. 2+ GPUs -> FSDP2 (recommended) or DeepSpeed ZeRO (`references/multi-gpu.md`).
6. Result for vLLM/SGLang -> `axolotl merge-lora`, serve `<output_dir>/merged`. Result for Ollama/llama.cpp -> merge, then `axolotl export` (`references/export-merge.md`).
7. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, Docker pulls, long training runs and anything that stops a model server need approval and an undo path.
- **Inspect masks before a long run.** `axolotl preprocess cfg.yml --debug --debug-num-examples 3`; a wrong template or EOS silently wastes the run.
- **Hold out eval data.** Use `test_datasets` (pre-split) or `val_set_size`, never both.
- **Pin the version.** Record `pip show axolotl`, the Docker tag and PyTorch; `main-latest` moves.
- **Never pip-install llama.cpp requirements into the Axolotl venv.** They pin an older `transformers` and CPU torch.
- **Secrets never touch output.** `HF_TOKEN`, `WANDB_API_KEY` come from the environment or a `0600` file.
- **Cap memory and use `tmux`.** Run under `systemd-run --user --scope -p MemoryMax=<cap> -p MemorySwapMax=0` on shared or unified-memory machines.
- **Verify upstream.** Config keys change between releases; check the config reference for the installed version.

## Workflows

### 1. Install

- [ ] Choose uv or Docker, pin the version (`references/install.md`).
- [ ] `axolotl --help` works; `axolotl fetch examples` downloads example configs.
- [ ] Verify: `python -c 'import torch; print(torch.cuda.is_available())'` prints `True`.

### 2. Train a LoRA SFT

- [ ] `cp templates/lora-sft.yaml my-run.yml`; set `base_model`, dataset paths, `sequence_len`, `output_dir` (`references/config.md`).
- [ ] `axolotl preprocess my-run.yml --debug --debug-num-examples 3`; check that only assistant tokens have labels.
- [ ] `axolotl train my-run.yml`, in `tmux`; add `--resume-from-checkpoint <dir>` to resume.
- [ ] `axolotl inference my-run.yml --lora-model-dir <output_dir> --chat` for a smoke test.
- [ ] Verify: eval loss falls and `adapter_model.safetensors` exists in `output_dir`.

### 3. Preference tuning or GRPO

- [ ] Set `rl:` and the matching dataset `type:` (`references/rl-and-grpo.md`).
- [ ] GRPO: start vLLM with `axolotl vllm-serve cfg.yml` on separate GPUs, or use colocate mode on one GPU.
- [ ] Verify: reward and loss metrics logged; vLLM serves the same `base_model`.

### 4. Scale out

- [ ] Add `fsdp_version: 2` + `fsdp_config`, or `deepspeed: deepspeed_configs/zero2.json` (`references/multi-gpu.md`).
- [ ] Launch: `axolotl train cfg.yml --launcher torchrun -- --nproc_per_node=<N>`.
- [ ] Verify: all ranks progress; no NCCL timeout.

### 5. Merge and export

- [ ] `axolotl merge-lora cfg.yml` (QLoRA: `--dequant`); output in `<output_dir>/merged` (`references/export-merge.md`).
- [ ] Optional GGUF: `axolotl export cfg.yml --quantize Q4_K_M` with `$LLAMA_CPP_DIR` set.
- [ ] Verify: merged dir has weights, tokenizer files and the chat template.
- [ ] Optional FP8 for vLLM: `references/combos/merge-llm-compressor-fp8-vllm.md`.

### 6. Update

- [ ] Read the release notes, re-run the install command with the new pin (`references/updating.md`).
- [ ] Verify: `axolotl preprocess` on an existing config still passes.

## Reference index

- `references/install.md`: uv, Docker images and tags, Blackwell/arm64 notes, cloud images.
- `references/config.md`: config keys, dataset types, chat-template masking, CLI overrides, `templates/`.
- `references/rl-and-grpo.md`: DPO/KTO/ORPO/GRPO config, vLLM server vs colocate, LoRA sync.
- `references/multi-gpu.md`: FSDP2, DeepSpeed, context parallelism, launchers, sweeps, cloud launchers.
- `references/export-merge.md`: merge-lora, `--dequant`, GGUF export, preflight checks.
- `references/troubleshooting.md`: error strings and fixes.
- `references/updating.md`: upgrading, breaking changes seen in 0.x, pinning.
- `references/combos/merge-llm-compressor-fp8-vllm.md`: merged adapter to FP8 checkpoint to `vllm serve`.
- `templates/lora-sft.yaml`: commented LoRA SFT config with held-out eval. `templates/grpo-colocate.yaml`: single-GPU GRPO starter.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `fine-tuning-llms`: decide whether to fine-tune, prepare data, pick method and hardware, evaluate.
- `unsloth`: single-GPU memory-tight alternative. `trl`: custom Python trainers and rewards.
- `llm-compressor`: quantize the merged model (FP8, W4A16, NVFP4). `model-quantization`: GGUF types and imatrix.
- `vllm`: serve the merged model or adapters. `llama-cpp` and `ollama`: run the GGUF.
- `llm-evals`: compare the fine-tune with the base model.
