# TRL trainers

> Verified against huggingface/trl v1.15.0 (docs: sft_trainer, grpo_trainer, vllm_integration, dataset_formats), 2026-10-11

## Stable vs experimental

Stable at the top level: `SFTTrainer`, `DPOTrainer`, `GRPOTrainer`, `RLOOTrainer`, `RewardTrainer`, `KTOTrainer`. Methods under `trl.experimental.*` (for example `trl.experimental.online_dpo.OnlineDPOTrainer`) can change without notice; ORPO is experimental at v1.15.0. Pin TRL when you depend on one.

## Dataset formats

- SFT: language modeling (`text`), conversational (`messages`), prompt-completion (standard or conversational).
- DPO and reward: preference rows with `prompt`, `chosen`, `rejected`; implicit-prompt rows (only `chosen`/`rejected` containing the prompt) also work. Conversational datasets get the chat template applied automatically.
- GRPO / RLOO: `prompt` column; extra columns are passed to reward functions as keyword arguments.
- KTO: unpaired preference data (CLI example `trl-lib/kto-mix-14k`).

## SFT

```python
from datasets import load_dataset
from peft import LoraConfig
from trl import SFTConfig, SFTTrainer

ds = load_dataset("trl-lib/Capybara", split="train")
trainer = SFTTrainer(
    model="Qwen/Qwen3-0.6B",
    train_dataset=ds,
    peft_config=LoraConfig(),
    args=SFTConfig(output_dir="out", learning_rate=1e-4, assistant_only_loss=True),
)
trainer.train()
```

- LoRA wants a higher learning rate (about 1e-4 per upstream) than full fine-tuning (SFTConfig default 2e-5).
- `assistant_only_loss=True` needs a chat template with `{% generation %}` / `{% endgeneration %}` markers; TRL patches known families (for example Qwen3). Otherwise check the template yourself.
- Prompt-completion datasets compute loss on the completion only by default (`completion_only_loss=True`).
- Base models without a template: `clone_chat_template()` or `chat_template_path`; for Qwen base models align the EOS token with the template, for example `eos_token="<|im_end|>"` for `Qwen/Qwen2.5-1.5B`.
- Continue an adapter: load `AutoPeftModelForCausalLM.from_pretrained(path, is_trainable=True)` and pass it as `model` without `peft_config`.
- Local JSONL: `load_dataset("json", data_files={"train": "train.jsonl"})`.
- Packing and memory options: `peft-and-memory.md`.

## DPO

```python
from datasets import load_dataset
from trl import DPOConfig, DPOTrainer

ds = load_dataset("trl-lib/ultrafeedback_binarized", split="train")
trainer = DPOTrainer(model="<sft-model>", args=DPOConfig(output_dir="dpo-out"), train_dataset=ds)
trainer.train()
```

DPOConfig defaults to `learning_rate=1e-6`. Start from your SFT model. With `peft_config`, the frozen base serves as reference. `padding_free=True` currently warns and falls back to normal padding in `DPOTrainer`.

## GRPO and reward functions

```python
from datasets import load_dataset
from trl import GRPOConfig, GRPOTrainer
from trl.rewards import accuracy_reward

def length_reward(completion_ids, **kwargs):
    return [float(len(ids)) for ids in completion_ids]

ds = load_dataset("trl-lib/DeepMath-103K", split="train")
trainer = GRPOTrainer(
    model="Qwen/Qwen2.5-0.5B-Instruct",
    reward_funcs=[accuracy_reward, length_reward],
    args=GRPOConfig(output_dir="grpo-out", use_vllm=True),
    train_dataset=ds,
)
trainer.train()
```

Reward function contract (upstream): keyword arguments `prompts`, `completions`, `completion_ids`, `trainer_state`, `log_extra`, `log_metric`, and every dataset column except `prompt` (use `**kwargs`); return a `list[float]`, one per completion. Standard-format data gives strings, conversational data gives message dicts. Async `async def` rewards run concurrently. Several functions are summed, or weighted with `reward_weights` in `GRPOConfig`.

GRPOConfig defaults at v1.15.0: `num_generations=8`, `max_completion_length=512`, `learning_rate=1e-6`, `beta=0.0`, `loss_type="dapo"`. (From the config source; recheck after upgrades.)

## RLOO, KTO, reward models

`RLOOTrainer` and `RLOOConfig` mirror the GRPO setup (`reward_funcs`, `use_vllm`, `vllm_mode`). `trl reward` trains a reward model from `trl-lib/ultrafeedback_binarized`-style preference data. See the matching `*_trainer` docs for method-specific fields.
