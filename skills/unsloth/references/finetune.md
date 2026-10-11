# Fine-tuning with Unsloth Core

> Verified against unslothai/unsloth library 2026.10.3 (README, unsloth.ai/docs fine-tuning guide, multi-GPU and DDP pages) and huggingface/trl v1.15.0, 2026-10-11

Unsloth patches model loaders and kernels; trainers are TRL's (`SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, with `SFTConfig`, `DPOConfig`, `GRPOConfig`). Upstream reports 2x faster training with 70% less VRAM for LoRA on many models; treat numbers as vendor claims.

## Pick the method

- Start with an instruct model and QLoRA or LoRA; full fine-tuning (`full_finetuning=True`) only after LoRA proves the data. Only one of `load_in_4bit`, `load_in_8bit`, `load_in_16bit`, `full_finetuning` is `True` at a time.
- Upstream advice: train and serve in the same precision (serve in 4-bit -> train in 4-bit).
- Model names ending `unsloth-bnb-4bit` are Unsloth dynamic 4-bit quants (slightly more VRAM than plain bitsandbytes 4-bit, higher accuracy); `bnb-4bit` without "unsloth" is standard bitsandbytes; no suffix = original 16/8-bit, often with Unsloth chat-template or tokenizer fixes.
- Notebooks per model family (Colab, Kaggle, local): https://unsloth.ai/docs/get-started/unsloth-notebooks. Convert a notebook to a script and run it under `tmux`.

## SFT script (LoRA / QLoRA)

```python
from unsloth import FastLanguageModel          # import before transformers/trl
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer

model, tokenizer = FastLanguageModel.from_pretrained(
    "<org>/<model>", max_seq_length=2048,
    load_in_4bit=True,                          # QLoRA; set False and load_in_16bit=True for 16-bit LoRA
)
model = FastLanguageModel.get_peft_model(
    model, r=16, lora_alpha=32, lora_dropout=0.0,
    use_gradient_checkpointing="unsloth",
)
ds = load_dataset("json", data_files="data/train.jsonl", split="train")
trainer = SFTTrainer(
    model=model, processing_class=tokenizer, train_dataset=ds,
    args=SFTConfig(output_dir="outputs/unsloth-lora", num_train_epochs=2,
                   per_device_train_batch_size=2, gradient_accumulation_steps=4,
                   learning_rate=2e-4),
)
trainer.train()
model.save_pretrained("outputs/unsloth-lora/adapter")        # adapter only
tokenizer.save_pretrained("outputs/unsloth-lora/adapter")
```

The `processing_class=` argument is the TRL 1.x name; older notebooks use `tokenizer=`. Rendering chat rows into the training text depends on the model: copy the chat-template helper and formatting step from the notebook for your model family, and train on the same template you serve.

Upstream defaults worth knowing (fine-tuning guide): `max_seq_length=2048` for testing, `per_device_train_batch_size=2`, `gradient_accumulation_steps=4`, `max_steps=60` for a smoke test or `num_train_epochs=1-3` for real runs, `learning_rate=2e-4` (try `1e-4`, `5e-5`, `2e-5` for gentler tuning). Training loss around 0.5-1.0 is typical; loss going to 0 suggests overfitting, so evaluate on held-out data. Call `FastLanguageModel.for_inference(model)` before in-process generation for the faster inference path.

Parameters: `from_pretrained`: `max_seq_length`, `dtype`, `load_in_4bit`, `load_in_8bit`, `load_in_16bit`, `full_finetuning`, `device_map`. `get_peft_model`: `r`, `lora_alpha`, `lora_dropout`, `target_modules`, `use_gradient_checkpointing="unsloth"`, `use_rslora`, `random_state` (full list in the docs hyperparameters guide).

## RL and preference tuning

Unsloth documents GRPO, GSPO, DPO, ORPO, KTO and FP8 RL, with notebooks (for example Qwen3 advanced GRPO, gpt-oss GRPO). Guides: https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide and the preference page `.../preference-dpo-orpo-and-kto`. Reward function signatures and trainer options are TRL's (skill `trl`). On DGX Spark an RL notebook (`gpt_oss_20B_RL_2048_Game_DGX_Spark`) exists upstream.

## Multi-GPU

README states support for multi-GPU setups. Per the docs: Unsloth works with Accelerate and DeepSpeed (FSDP, DDP) and the setup is still manual:

```bash
accelerate launch train.py                      # or
torchrun --nproc_per_node N_GPUS train.py
```

Pipeline-style splitting of one model that does not fit a single GPU: `FastLanguageModel.from_pretrained("<model>", load_in_4bit=True, device_map="balanced")`. DDP guide: https://unsloth.ai/docs/basics/multi-gpu-training-with-unsloth/ddp (it drives the `unsloth-cli.py` script; the repo also has an `unsloth train --config <file> [--dry-run]` command, present in `unsloth_cli/commands/train.py` but its full flag set is **unverified** here). The multi-GPU page itself says official support is still being announced.

## Memory notes

- `use_gradient_checkpointing="unsloth"` is Unsloth's offloaded checkpointing; shorten `max_seq_length`, lower batch size, raise accumulation first when OOM.
- On unified-memory machines stop model servers first and run inside a memory-capped scope.
- Run notebooks as scripts in `tmux` for long jobs; checkpoint regularly (`save_steps` in `SFTConfig`).
