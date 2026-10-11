# Using DeepSpeed through other tools

> Verified against DeepSpeed v0.19.7, 2026-10-11

## Hugging Face Trainer

Pass the JSON path: `TrainingArguments(deepspeed="ds_config.json", ...)`. `"auto"` values are filled from the arguments:

| DeepSpeed key                    | TrainingArguments             |
| -------------------------------- | ----------------------------- |
| `train_micro_batch_size_per_gpu` | `per_device_train_batch_size` |
| `gradient_accumulation_steps`    | `gradient_accumulation_steps` |
| `optimizer.params.lr`            | `learning_rate`               |
| `fp16.enabled` / `bf16.enabled`  | `fp16` / `bf16`               |

Values set by hand must equal the trainer's, or training continues with the wrong values. Launch with `deepspeed --num_gpus 4 train.py`, `torchrun --nproc_per_node 4 train.py` or `accelerate launch --num_processes 4 train.py`. Install with `pip install deepspeed` or `pip install transformers[deepspeed]`.

## Accelerate

`accelerate config` (or write it) with `distributed_type: DEEPSPEED` and either inline options or `deepspeed_config_file: ds_config.json`. Accelerate ignores the `deepspeed` argument in `TrainingArguments` when its own config is used. A ZeRO-3 LoRA example lives in the `peft` skill's `templates/accelerate-deepspeed-zero3.yaml`. Keep `gradient_accumulation_steps` identical between the Accelerate config and the script.

## TRL

TRL's CLI and trainers use Accelerate; select DeepSpeed through an Accelerate config or `--accelerate_config` per the TRL docs (skill `trl`). GRPO with vLLM needs its generation engine on separate GPUs or colocated; combine with ZeRO-3 only after reading TRL's notes.

## PEFT

PEFT docs report ZeRO-1, 2 and 3 as compatible; ZeRO-3 with QLoRA has a dedicated recipe (skill `peft`). With ZeRO-3 the stage3 gather option is needed to save a consolidated adapter or model.

## LLaMA-Factory

Add `deepspeed: examples/deepspeed/ds_z3_config.json` to the training YAML and launch with `FORCE_TORCHRUN=1 llamafactory-cli train ...`. LLaMA-Factory's `requirements/deepspeed.txt` pins `deepspeed<=0.18.4` at v0.9.5, older than the 0.19.7 release; use the pinned range inside its environment (skill `llama-factory`).

## Plain PyTorch

```python
import deepspeed
model_engine, optimizer, _, _ = deepspeed.initialize(args=cmd_args, model=model, model_parameters=params)
for batch in data_loader:
    loss = model_engine(batch)
    model_engine.backward(loss)   # not loss.backward()
    model_engine.step()           # optimizer + scheduler + zero grad
```

Replace `torch.distributed.init_process_group(...)` with `deepspeed.init_distributed()` if you need distributed before `initialize` (NCCL by default). The config path is given as `--deepspeed --deepspeed_config ds_config.json`. DeepSpeed steps a scheduler it manages every `step()`; do not also step it yourself.

For ZeRO-3 model construction larger than one GPU use `deepspeed.zero.Init(...)` and `deepspeed.zero.GatheredParameters(...)` for parameter access (ZeRO tutorial, readthedocs `zero3`).
