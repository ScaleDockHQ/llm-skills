# DeepSpeed

An agent skill for [DeepSpeed](https://github.com/deepspeedai/DeepSpeed), the large-model training library: ZeRO stages 1-3, CPU and NVMe offload, the `deepspeed` launcher, `ds_report` and `zero_to_fp32`. It covers installing, writing ZeRO configs for Hugging Face Trainer, TRL, Accelerate and LLaMA-Factory, multi-GPU and multi-node launches, checkpoint conversion, updating and troubleshooting.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill deepspeed
```

## Rules

- **Ask before changing the system.** Installs, CUDA changes, jobs and multi-node launches need approval.
- **Install PyTorch first; match the CUDA toolkit.**
- **Start at ZeRO-2; move to ZeRO-3 or offload only when needed.**
- **Use `"auto"` values with Hugging Face trainers.**
- **All ranks must call `save_checkpoint`.**
- **Keep hostfiles and rendezvous ports on a private network.**
- **Secrets never touch output.**

## References

- [`references/install.md`](references/install.md): install, ops, CUDA matching.
- [`references/zero-config.md`](references/zero-config.md): ZeRO stages, offload, precision.
- [`references/integrations.md`](references/integrations.md): Trainer, Accelerate, TRL, PEFT, LLaMA-Factory.
- [`references/launch-and-multinode.md`](references/launch-and-multinode.md): launcher, hostfile, no-SSH mode.
- [`references/checkpoints.md`](references/checkpoints.md): save, convert, universal checkpoints.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptoms and fixes.
- [`references/updating.md`](references/updating.md): cadence and upgrade routine.
- [`templates/`](templates): `ds_zero2.json`, `ds_zero3.json`, `ds_zero3_offload.json`, `hostfile.example`.

## Companion skills

- `fine-tuning-llms`: decide, prepare data, choose method and hardware (install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`)
- `trl`, `llama-factory`, `axolotl`, `peft`: trainers and adapters that use DeepSpeed
- `deepspeed-mii`: DeepSpeed inference
- `vllm`: serving (install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`)

## License

MIT
