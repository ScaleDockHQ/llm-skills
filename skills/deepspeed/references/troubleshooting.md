# Troubleshooting DeepSpeed

> Verified against DeepSpeed v0.19.7, 2026-10-11

Start with `ds_report`, the exact config and the full traceback. Entries marked (inferred) come from reading docs, not from reproducing the error.

| Symptom                                                                         | Cause and fix                                                                                                                                                        |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Installed CUDA version X does not match the version torch was compiled with Y` | System nvcc differs from PyTorch's CUDA. Install matching toolkit or torch build, or `DS_SKIP_CUDA_CHECK=1` at your own risk (`install.md`).                         |
| `CUDA_HOME` not set or nvcc not found when building ops                         | Install the CUDA toolkit and export `CUDA_HOME` and `PATH`; see `install.md`.                                                                                        |
| `no kernel image is available for execution on the device`                      | Ops built for other GPU architectures. Rebuild with `TORCH_CUDA_ARCH_LIST="<cc>"`.                                                                                   |
| Wrong ops picked up across environments                                         | Shared `~/.cache/torch_extensions`; set `TORCH_EXTENSIONS_DIR` per environment.                                                                                      |
| `ds_report` shows an op incompatible                                            | Missing system package or compiler for that feature; see its notes. Only pre-build ops marked compatible.                                                            |
| Batch size mismatch assertion                                                   | `train_batch_size` must equal micro batch x accumulation x GPUs (`zero-config.md`). With HF trainers use `"auto"`.                                                   |
| Config value silently ignored or training differs from args                     | Hand-set values disagree with TrainingArguments; use `"auto"` (`integrations.md`).                                                                                   |
| ZeRO-3 gives no memory saving with HF                                           | Model loaded before `TrainingArguments`/DeepSpeed config existed, so it is not sharded at init. Create `TrainingArguments` first (`zero-config.md`).                 |
| `save_checkpoint` hangs                                                         | Only rank 0 called it. All ranks must call it.                                                                                                                       |
| Cannot load a Trainer checkpoint with `from_pretrained`                         | It is sharded. Use `trainer.save_model` with the gather option or `zero_to_fp32.py` (`checkpoints.md`).                                                              |
| Error saving with `save_only_model=True` under ZeRO-3                           | Set `stage3_gather_16bit_weights_on_model_save: true` or save full checkpoints.                                                                                      |
| OOM on host RAM or pinned-memory errors with offload                            | `pin_memory` now defaults to true and uses non-swappable RAM; raise `ulimit -l` or set `"pin_memory": false`; reduce offloaded state (`zero-config.md`).             |
| OOM on GPU with ZeRO-2                                                          | Move to ZeRO-3, add offload, lower micro batch, enable activation checkpointing.                                                                                     |
| Slow steps with ZeRO-3/offload                                                  | Expected communication/transfer cost. Lower stage if the model fits, increase micro batch, tune bucket and prefetch sizes.                                           |
| NaN loss with fp16                                                              | Loss scale issues; prefer bf16 where supported or inspect loss-scale settings (inferred; Transformers debugging guide covers overflow detection).                    |
| Hang at job start on multiple nodes                                             | SSH, firewall, `--master_port`, `NCCL_SOCKET_IFNAME` or NIC selection (inferred). Test one node, then two; use `--no_ssh` in containers (`launch-and-multinode.md`). |
| `--include` selects wrong GPUs on older versions                                | A fix to filter `--include` against real slots appears in the v0.19.x release notes; upgrade before relying on complex include strings.                              |
| Muon optimizer disabled at ZeRO stage 0/3 init                                  | Fixes for Muon at stage 0 and under ZeRO-3 `zero.Init` appear in v0.19.7 notes; upgrade before using Muon.                                                           |
| LoRA with ZeRO-3 conversion includes frozen weights                             | Use `zero_to_fp32.py --exclude_frozen_parameters` if you only need trained parameters.                                                                               |

Report bugs at https://github.com/deepspeedai/DeepSpeed/issues with `ds_report`, the config and versions.
