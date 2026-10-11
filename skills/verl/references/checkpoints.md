# Checkpoints and merging in verl

> Verified against verl-project/verl v0.9.1 (docs/advance/checkpoint.rst, verl/model_merger, docs/start/quickstart.rst), 2026-10-11

## Where checkpoints go

`checkpoints/${trainer.project_name}/${trainer.experiment_name}/global_step_<N>/actor` (and `critic`), with `latest_checkpointed_iteration.txt` at the experiment root. Override with `trainer.default_local_dir`. Frequency: `trainer.save_freq`.

FSDP layout in `actor/`: `huggingface/` (config and tokenizer, plus weights if `hf_model` is saved), `fsdp_config.json` (world size, FSDP version), and per-rank `model_*`, `optim_*`, `extra_state_*` `.pt` shards. Shards are tied to the world size.

## What to save

`checkpoint.save_contents` / `checkpoint.load_contents` take any of `model`, `optimizer`, `extra`, `hf_model`. For FSDP keep `model`, `optimizer` and `extra` together; `hf_model` writes a full HF-format model. Megatron needs an mbridge bridge for `hf_model`. LoRA: `checkpoint.save_lora_only=True` saves only adapter keys (a 27B example shrinks from ~54 GiB to ~150 MiB).

## Resume

`trainer.resume_mode=auto` (default) resumes from the latest checkpoint in the experiment dir; `disable` starts fresh; `resume_path` with `trainer.resume_from_path=<dir>`.

## Merge to a Hugging Face model

```bash
python3 -m verl.model_merger merge --backend fsdp \
  --local_dir checkpoints/<project>/<experiment>/global_step_<N>/actor \
  --target_dir <out>/huggingface

# Megatron
python3 -m verl.model_merger merge --backend megatron --tie-word-embedding \
  --local_dir .../global_step_<N>/actor --target_dir <out>
# very large Megatron models: distributed merge
torchrun --nproc_per_node 1 --nnodes <N> --node_rank $RANK -m verl.model_merger merge \
  --backend megatron --local_dir .../actor --target_dir <out>
```

Run `python3 -m verl.model_merger merge --help` for the flags of your tag. Check the output: safetensors shards, `config.json`, tokenizer files; then `vllm serve <out>` (skill `vllm`).

## Callbacks

Set `trainer.checkpoint_callback_class=<pkg.Class>` (a subclass of `verl.trainer.ppo.checkpoint_callback.CheckpointCallback`, v1 trainer with `trainer.use_v1=true`) to run `on_save(trainer, global_step, checkpoint_dir, async_save=False, **kwargs)` after each save, for example to upload to object storage. It runs only on the driver, and exceptions abort training: wrap best-effort uploads in try/except. With Megatron async saves the checkpoint may not be durable yet when it fires.
