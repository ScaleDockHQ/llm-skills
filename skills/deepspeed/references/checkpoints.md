# Checkpoints and conversion

> Verified against DeepSpeed v0.19.7, 2026-10-11

## Engine checkpoints

```python
model_engine.save_checkpoint(save_dir, tag, client_state={"step": step})
_, client_sd = model_engine.load_checkpoint(load_dir, tag)
```

Every rank must call `save_checkpoint` (each saves its shard of master weights and optimizer state); calling it only on rank 0 hangs. These checkpoints are sharded and cannot be loaded with `from_pretrained`.

## Hugging Face Trainer

Trainer saves DeepSpeed checkpoints under `checkpoint-<step>/`. To get a normal Transformers model:

- Set `load_best_model_at_end=True`, then `trainer.save_model("./best-model")` after training.
- With ZeRO-3 set `stage3_gather_16bit_weights_on_model_save: true` so a consolidated 16-bit model can be written.
- `save_only_model=True` skips optimizer state, so you cannot resume or reload the best model; Transformers raises an error with ZeRO-3 unless the gather option is set.

## Convert shards to fp32 weights

DeepSpeed copies `zero_to_fp32.py` into the checkpoint folder:

```bash
cd outputs/checkpoint-1000            # contains global_step*/ and zero_to_fp32.py
python zero_to_fp32.py . ../fp32-out --safe_serialization
python zero_to_fp32.py . ../fp32-out -t global_step1000 --max_shard_size 5GB
```

Arguments: `checkpoint_dir`, `output_dir`, `--max_shard_size` (default `5GB`), `--safe_serialization`, `-t/--tag`, `--exclude_frozen_parameters` (useful when only LoRA parameters trained), `-d/--debug`. It works for ZeRO 1, 2 and 3 and needs no DeepSpeed afterward. The conversion loads full weights into CPU memory; check `free -h` first.

Python API (`deepspeed.utils.zero_to_fp32`): `get_fp32_state_dict_from_zero_checkpoint`, `load_state_dict_from_zero_checkpoint`, `convert_zero_checkpoint_to_fp32_state_dict`.

Stage 1/2 checkpoints saved with `torch.save` can be larger than expected because of tensor flattening; DeepSpeed provides `deepspeed.checkpoint.utils.clone_tensors_for_torch_save`.

## Changing world size or parallelism

Universal Checkpointing lets you resume on a different number of GPUs or parallelism layout: https://www.deepspeed.ai/tutorials/universal-checkpointing/. The config also has `checkpoint.tag_validation` (`Warn` default), `load_universal` and `use_node_local_storage`.

## After conversion

Load the result in Transformers/PEFT, generate on fixed prompts and compare with the pre-conversion run. Merge adapters per the `peft` skill; quantize or serve with `gguf-quantization` or `vllm`.
