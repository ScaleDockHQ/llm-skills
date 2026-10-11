# TRL (Transformer Reinforcement Learning)

> Verified against huggingface/trl v1.15.0 and huggingface/peft v0.21.2, 2026-10-11

## What it is and when to choose it

[TRL](https://github.com/huggingface/trl) is Hugging Face's post-training library: `SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `KTOTrainer`, `RewardTrainer`, `RLOOTrainer`, plus experimental trainers (ORPO, CPO/SimPO, Online DPO, GKD, ...) under `trl.experimental`. Axolotl and Unsloth both build on it.

Choose TRL directly when you need **custom Python** (reward functions, custom collators, research losses), the newest method before Axolotl wraps it, or a small script without a framework. For config-only runs prefer Axolotl.

## Install

```bash
uv venv && source .venv/bin/activate
uv pip install trl peft          # add bitsandbytes for QLoRA, vllm for GRPO generation
trl env                          # prints versions of trl/transformers/torch/accelerate etc.
```

Same on x86_64 and arm64 as long as a CUDA PyTorch wheel exists for the platform (on DGX Spark, NVIDIA's PyTorch container `nvcr.io/nvidia/pytorch` is a common base; matching wheels for optional extras such as bitsandbytes/vllm on aarch64 are (unverified) per version).

## Minimal working config/command

**CLI** (`trl sft|dpo|grpo|kto|reward|rloo`, args mirror the trainer config fields; `--config file.yaml` accepted):

```bash
trl sft \
  --model_name_or_path <org>/<model> \
  --dataset_name <org>/<dataset> \
  --use_peft --lora_r 16 --lora_alpha 32 --lora_dropout 0.05 \
  --output_dir ./outputs/sft-lora
```

QLoRA: add `--load_in_4bit`. DoRA: `--use_dora`. YAML equivalent: put the same keys in `sft_config.yaml` and run `trl sft --config sft_config.yaml`. Multi-GPU: the CLI launches through Accelerate (`--accelerate_config` profiles; see TRL CLI docs).

**Python SFT + LoRA** (local JSONL with `messages` rows):

```python
from datasets import load_dataset
from peft import LoraConfig
from trl import SFTConfig, SFTTrainer

ds = load_dataset("json", data_files={"train": "data/train.jsonl", "eval": "data/eval.jsonl"})
trainer = SFTTrainer(
    model="<org>/<model>",
    train_dataset=ds["train"],
    eval_dataset=ds["eval"],
    args=SFTConfig(output_dir="outputs/sft-lora", learning_rate=2e-4, num_train_epochs=2),
    peft_config=LoraConfig(r=16, lora_alpha=32, lora_dropout=0.05, target_modules="all-linear"),
)
trainer.train()
trainer.save_model()
```

**DPO** (preference rows `prompt`/`chosen`/`rejected`):

```python
from trl import DPOConfig, DPOTrainer
trainer = DPOTrainer(model="<sft-model-dir>", train_dataset=pref_ds, args=DPOConfig(output_dir="outputs/dpo"))
trainer.train()
```

**GRPO** (prompt-only rows + reward function):

```python
from trl import GRPOTrainer
from trl.rewards import accuracy_reward
trainer = GRPOTrainer(model="<sft-model-dir>", reward_funcs=accuracy_reward, train_dataset=prompts_ds)
trainer.train()
```

Experimental trainers import from `trl.experimental.<name>`, e.g. `from trl.experimental.orpo import ORPOConfig, ORPOTrainer`.

## How it plugs into the stack

- **In:** HF model id/dir; `datasets` objects in TRL's formats (language modeling, prompt-only, prompt-completion, preference, unpaired preference; standard or conversational — see `data-prep.md`).
- **Out:** `output_dir` with a PEFT adapter (when `peft_config` is set) or full weights. Adapters load in vLLM (`--lora-modules`) or convert to GGUF with llama.cpp's `convert_lora_to_gguf.py`.
- **GRPO generation:** uses vLLM (colocated or server mode). `trl vllm-serve` is deprecated in favor of `vllm serve` directly (TRL vLLM integration docs).

## Operating

- Run inside `tmux` or a `systemd-run --user --scope` with memory caps (see `hardware.md`).
- Checkpoints: `save_steps`, `save_total_limit` in the config; resume with `trainer.train(resume_from_checkpoint=True)` or a path.
- Logging: `report_to` (e.g. `trackio`, `wandb`, `tensorboard`, `none`).
- `trl env` output is the first thing to paste into a bug report.

## Tuning knobs worth knowing

- `SFTConfig`: `max_length`, `packing`, `assistant_only_loss` / `completion_only_loss`, `learning_rate`, `per_device_train_batch_size`, `gradient_accumulation_steps`, `gradient_checkpointing`, `bf16`.
- `DPOConfig`: `beta`, `loss_type`.
- `GRPOConfig`: `num_generations`, `max_completion_length`, `use_vllm`, `vllm_mode`.
- `LoraConfig`: `r`, `lora_alpha`, `lora_dropout`, `target_modules` (`"all-linear"`), `use_dora`, `use_rslora`.

Field names change between TRL releases; check the trainer page for your installed version before relying on a knob.

## Known pitfalls

- TRL moves trainers between stable and `trl.experimental`; imports from old tutorials break (ORPO is experimental in 1.x).
- Base (non-instruct) models may lack a chat template; conversational datasets then fail or render wrongly. Set a template or use an instruct model.
- Running DPO with the SFT adapter still attached vs merged changes the reference model; read the DPO docs' PEFT section for your version.
- Pinned old TRL inside third-party containers (e.g. vendor DGX Spark Dockerfiles) won't match current docs.

## Official links

- Repo: https://github.com/huggingface/trl
- Docs: https://huggingface.co/docs/trl
- CLI: https://huggingface.co/docs/trl/clis
- Dataset formats: https://huggingface.co/docs/trl/dataset_formats
- PEFT integration: https://huggingface.co/docs/trl/peft_integration
- vLLM integration: https://huggingface.co/docs/trl/vllm_integration
- PEFT: https://github.com/huggingface/peft
