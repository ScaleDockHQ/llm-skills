---
name: deepspeed
description: DeepSpeed is Microsoft's training library for large models with ZeRO stages 1-3, CPU/NVMe offload, the deepspeed launcher, ds_config.json, ds_report and zero_to_fp32. Use to install it (JIT ops, nvcc, DS_BUILD_OPS), write a ZeRO config for Hugging Face Trainer, TRL, Accelerate or LLaMA-Factory, run multi-GPU or multi-node jobs with a hostfile, offload to CPU or NVMe, convert ZeRO checkpoints to fp32 weights, or fix errors such as CUDA_HOME not found, batch-size mismatch, ZeRO-3 save problems and OOM. Not for DeepSpeed-MII inference (deepspeed-mii) or method choice (fine-tuning-llms).
license: MIT
compatibility: Linux with NVIDIA (also AMD ROCm, Intel XPU/Gaudi, Ascend NPU) accelerators, PyTorch installed first, Python 3.x, a CUDA toolkit with nvcc for JIT ops, ninja. Uses deepspeed, ds_report, curl and jq via shell. Installs, jobs and checkpoint conversions need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# DeepSpeed

Train and fine-tune models that do not fit one GPU by sharding optimizer state, gradients and parameters (ZeRO) and optionally offloading to CPU or NVMe, driven by one JSON config.

**Scope:** this one library: install, ZeRO config, launch, multi-node, offload, checkpoints, update, troubleshoot. It is usually reached through a trainer; the trainer's own skill covers its flags. Whether to fine-tune and method choice belong to `fine-tuning-llms`. DeepSpeed-MII inference is a separate product (`deepspeed-mii`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print tokens.

```bash
python3 -c 'import deepspeed, torch; print("deepspeed", deepspeed.__version__, "torch", torch.__version__, "cuda", torch.cuda.is_available())' 2>/dev/null
command -v deepspeed ds_report ninja nvcc; nvcc --version 2>/dev/null | tail -1
echo "CUDA_HOME=${CUDA_HOME:-unset}"
ds_report 2>/dev/null | head -60
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
pip list 2>/dev/null | grep -iE '^(deepspeed|torch|transformers|accelerate|peft|trl|llamafactory) '
free -h 2>/dev/null | head -2; ulimit -l; df -h . 2>/dev/null
ls hostfile ~/.deepspeed_env 2>/dev/null; ls ds_config*.json 2>/dev/null
```

## Decision flow

1. Not installed -> PyTorch first, then `pip install deepspeed` (`references/install.md`).
2. Model plus optimizer states do not fit -> pick a ZeRO stage (`references/zero-config.md`): try 2 before 3.
3. Still no fit -> CPU offload, then NVMe (`references/zero-config.md`).
4. Using Trainer, TRL, Accelerate or LLaMA-Factory -> pass a config with `"auto"` values (`references/integrations.md`).
5. 2+ nodes -> hostfile and launcher (`references/launch-and-multinode.md`).
6. Need a normal checkpoint from ZeRO shards -> `zero_to_fp32` (`references/checkpoints.md`).
7. Error text -> `references/troubleshooting.md`.

## Rules

- **Ask before changing the system.** Installs, compiler/CUDA changes, jobs and multi-node launches need approval and an undo path.
- **Install PyTorch before DeepSpeed.** Ops are JIT-compiled with nvcc and ninja; the system CUDA toolkit must match what PyTorch was built with (`references/install.md`).
- **Start at the lowest stage that fits.** Each stage and offload level saves memory and costs communication; the HF docs advise ZeRO-2 unless the model does not fit.
- **Use `"auto"` with Hugging Face trainers.** Hand-set batch size, accumulation or precision that disagree with the trainer's arguments can train silently with wrong values.
- **All ranks must call `save_checkpoint`.** Calling it on rank 0 only hangs.
- **Multi-node means SSH and open ports.** Keep hostfiles, rendezvous ports and NCCL traffic on a private network; never expose them publicly.
- **Pinned memory is real RAM.** `pin_memory` now defaults to true for offload; on hosts with a low `ulimit -l` set it to `false` if you hit OOM.
- **Record the version.** Run `ds_report` and keep its output with the run.
- **Secrets never touch output.** `HF_TOKEN` and `WANDB_API_KEY` come from the environment or `0600` files; `.deepspeed_env` forwards variables to workers, so keep secrets out of it.

## Workflows

### 1. Install and check

- [ ] Install PyTorch, then `pip install deepspeed` (`references/install.md`).
- [ ] Verify: `ds_report` lists ops as compatible/installed; `import deepspeed` works.

### 2. Write a ZeRO config

- [ ] `cp templates/ds_zero2.json ds_config.json` (or `ds_zero3.json`, `ds_zero3_offload.json`) (`references/zero-config.md`).
- [ ] Keep batch, accumulation, clipping and precision as `"auto"` when a trainer fills them.

### 3. Launch

- [ ] Trainer or script: `deepspeed --num_gpus N train.py --deepspeed ds_config.json`, `torchrun`, or `accelerate launch` (`references/launch-and-multinode.md`).
- [ ] Verify: all ranks progress; peak GPU memory is below capacity; step time is acceptable.

### 4. Offload when needed

- [ ] Add `offload_optimizer` (stages 1-3) and then `offload_param` (stage 3 only) (`references/zero-config.md`).
- [ ] NVMe needs libaio and the `aio` section; check `ds_report`.

### 5. Multi-node

- [ ] Hostfile with `slots=`, passwordless SSH or `--no_ssh`, identical environments (`references/launch-and-multinode.md`).

### 6. Save and convert

- [ ] ZeRO-3 with `stage3_gather_16bit_weights_on_model_save: true`, or convert shards with `zero_to_fp32.py` (`references/checkpoints.md`).
- [ ] Verify: load the converted weights without DeepSpeed and generate.

### 7. Update

- [ ] Read release notes, new venv, run a smoke job (`references/updating.md`).

## Reference index

- `references/install.md`: PyPI, JIT vs prebuilt ops, `DS_BUILD_*`, CUDA toolkit matching, `ds_report`.
- `references/zero-config.md`: ZeRO stages, key fields, offload, precision, batch-size rule, `templates/`.
- `references/integrations.md`: Trainer, Accelerate, TRL, PEFT, LLaMA-Factory, plain `deepspeed.initialize`.
- `references/launch-and-multinode.md`: `deepspeed` launcher flags, hostfile, no-SSH mode, `.deepspeed_env`.
- `references/checkpoints.md`: `save_checkpoint`, `zero_to_fp32`, 16-bit saves, universal checkpointing.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: cadence, pins, upgrade routine.
- `templates/ds_zero2.json`, `templates/ds_zero3.json`, `templates/ds_zero3_offload.json`, `templates/hostfile.example`: starters.

## Companion skills

Install with `npx skills add ScaleDockHQ/llm-skills --skill <name>`:

- `fine-tuning-llms`: decide, prepare data, choose method and hardware.
- `trl`, `llama-factory`, `axolotl`, `peft`: trainers and adapters that call DeepSpeed.
- `deepspeed-mii`: DeepSpeed inference. `vllm`: serving.
