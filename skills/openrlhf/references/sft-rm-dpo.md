# SFT, reward model and DPO with OpenRLHF

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md, examples/scripts/train_sft.sh, train_rm.sh, train_dpo_llama.sh, openrlhf/cli/*.py), 2026-10-11

These entrypoints run through DeepSpeed: `deepspeed --module openrlhf.cli.train_sft|train_rm|train_dpo <flags>`. Model path flag is **`--model.model_name_or_path`** in these CLIs (checked in `train_sft.py`, `train_rm.py`, `train_dpo.py`); the README's SFT snippet still shows `--actor.model_name_or_path`, which is the RL CLI's name. Run `--help` on the installed version.

## SFT (from examples/scripts/train_sft.sh)

```bash
deepspeed --module openrlhf.cli.train_sft \
  --data.max_len 2048 --data.dataset Open-Orca/OpenOrca \
  --data.input_key question --data.output_key response \
  --train.batch_size 256 --train.micro_batch_size 2 --data.max_samples 500000 \
  --model.model_name_or_path meta-llama/Meta-Llama-3-8B \
  --ckpt.output_dir ./checkpoint/llama3-8b-sft --ckpt.save_steps -1 \
  --logger.logging_steps 1 --eval.steps -1 \
  --ds.zero_stage 2 --train.max_epochs 1 --ds.param_dtype bf16 \
  --ds.attn_implementation flash_attention_2 --adam.lr 5e-6 \
  --ds.packing_samples --model.gradient_checkpointing_enable
```

Options: `--data.apply_chat_template` (HF chat template) or `--data.input_template`, `--data.multiturn` (multi-turn loss), `--model.pretrain_mode_enable` (continued pre-training), `--ds.ring_attn_size 2` (needs `ring_flash_attn`), `--ckpt.load_enable` (resume), LoRA `--ds.lora.rank <r>` (and `--ds.load_in_4bit` for QLoRA; see `train_sft_mixtral_lora.sh`).

## Reward model

```bash
deepspeed --module openrlhf.cli.train_rm \
  --ckpt.output_dir ./checkpoint/llama3-8b-rm --ckpt.save_steps -1 \
  --train.batch_size 256 --train.micro_batch_size 1 \
  --model.model_name_or_path OpenRLHF/Llama-3-8b-sft-mixture \
  --ds.param_dtype bf16 --train.max_epochs 1 --data.max_len 8192 --ds.zero_stage 3 \
  --adam.lr 9e-6 --data.dataset OpenRLHF/preference_dataset_mixture2_and_safe_pku \
  --data.apply_chat_template --data.chosen_key chosen --data.rejected_key rejected \
  --ds.packing_samples --model.gradient_checkpointing_enable
```

Data keys come from the dataset class (`openrlhf/datasets/reward_dataset.py`). The README recommends the reward head name `score` so the model loads with `AutoModelForSequenceClassification`.

## DPO (from examples/scripts/train_dpo_llama.sh)

```bash
deepspeed --module openrlhf.cli.train_dpo \
  --ckpt.output_dir ./checkpoint/llama3-8b-dpo --ckpt.save_steps -1 \
  --train.batch_size 256 --train.micro_batch_size 1 \
  --model.model_name_or_path OpenRLHF/Llama-3-8b-sft-mixture \
  --ds.param_dtype bf16 --train.max_epochs 1 --data.max_len 8192 --ds.zero_stage 3 \
  --adam.lr 5e-7 --model.beta 0.1 \
  --data.dataset OpenRLHF/preference_dataset_mixture2_and_safe_pku \
  --data.apply_chat_template --data.chosen_key chosen --data.rejected_key rejected \
  --ds.attn_implementation flash_attention_2 --ds.packing_samples \
  --model.gradient_checkpointing_enable
```

Variants: `--model.ipo_enable` (IPO), `--model.label_smoothing 0.1` (cDPO), `--ref.offload`, `--model.nll_loss_coef`. `--ref.model_name_or_path` defaults to the policy path.

## Data keys

`--data.input_key`, `--data.output_key`, `--data.chosen_key`, `--data.rejected_key`, `--data.label_key`, `--data.dataset` / `--data.prompt_dataset`, `--data.dataset_probs` and `--data.prompt_probs` to mix datasets (for example `0.1,0.4,0.5`), `--eval.dataset`. Dataset field names: see `openrlhf/datasets/` (`sft_dataset.py`, `reward_dataset.py`, `prompts_dataset.py`).

## Discovery

```bash
python3 -m openrlhf.cli.train_sft --help | grep -E '^\s+--(model|data|ds|train)\.' | head -40
ls examples/scripts/
```
