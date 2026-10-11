# Fine-Tuning Methods

> Verified against Axolotl v0.20.0 (docs/choosing_method.qmd, docs/rlhf.qmd, config reference), TRL v1.15.0 (docs/source/*_trainer.md, clis.md), PEFT v0.21.2 (LoraConfig) and Unsloth 2026.10.3, 2026-10-11

Two independent choices: **how weights are updated** (full, LoRA, QLoRA, DoRA) and **what objective is trained** (SFT, DPO, KTO, ORPO, GRPO, reward modeling).

## How weights are updated

| Method             | What trains                                  | Memory                                                           | When                                                                                       |
| ------------------ | -------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **LoRA**           | Small low-rank matrices on frozen bf16 base  | Base weights + small adapter/optimizer state                     | Default first choice                                                                       |
| **QLoRA**          | LoRA on a 4-bit (NF4) quantized base         | Roughly a quarter of bf16 base weights + adapter                 | Model doesn't fit in bf16; fast experiments. Slower per step (dequant overhead)            |
| **DoRA**           | LoRA variant decomposing magnitude/direction | Slightly above LoRA                                              | Try if LoRA plateaus; PEFT `use_dora`, Axolotl `peft_use_dora: true`, TRL CLI `--use_dora` |
| **rsLoRA**         | LoRA with rank-stabilized scaling            | Same as LoRA                                                     | Higher ranks; PEFT `use_rslora`, Axolotl `peft_use_rslora: true`                           |
| **Full fine-tune** | All parameters                               | Weights + gradients + optimizer states (AdamW ~2x weights extra) | Large distribution shift, lots of GPU; after LoRA proved the data                          |

Key LoRA knobs: rank `r` (8-64 typical), `alpha` (often r or 2r), dropout (0-0.1), target modules (all linear layers is the common default: Axolotl `lora_target_linear: true`), learning rate (~1e-4 to 2e-4 for LoRA; full FT usually ~10x lower). Keep `r` within what your server allows (vLLM `--max-lora-rank`).

## What objective is trained

| Objective           | Data                                            | Notes                                                                                                          |
| ------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **SFT**             | Chats or prompt/completion pairs                | Start here. Teaches format, style, task                                                                        |
| **DPO**             | Prompt + chosen + rejected                      | Contrastive, no reward model; usually after SFT. IPO is a DPO loss variant                                     |
| **KTO**             | Prompt + completion + good/bad label (unpaired) | When you only have thumbs up/down                                                                              |
| **ORPO**            | Preference pairs                                | Combines SFT + preference in one stage, no reference model                                                     |
| **SimPO**           | Preference pairs                                | Reference-free preference variant (Axolotl `rl: simpo`)                                                        |
| **GRPO**            | Prompts + reward function(s)                    | Online RL: model generates, rewards score, policy updates. Needs a generation engine (vLLM); much more compute |
| **Reward modeling** | Preference pairs                                | Train a scorer for later RL                                                                                    |

## Which tool supports which

|              | Axolotl (YAML)                                            | TRL (Python / `trl` CLI)                                                    | Unsloth (Python)                                                                       |
| ------------ | --------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| SFT          | default (no `rl:`)                                        | `SFTTrainer`, `trl sft`                                                     | via TRL `SFTTrainer`                                                                   |
| DPO / IPO    | `rl: dpo` (`rl: ipo` still accepted, being deprecated)    | `DPOTrainer`, `trl dpo`                                                     | via TRL `DPOTrainer`                                                                   |
| KTO          | `rl: kto`                                                 | `KTOTrainer`, `trl kto`                                                     | via TRL                                                                                |
| ORPO         | `rl: orpo`                                                | `trl.experimental.orpo.ORPOTrainer` (experimental)                          | via TRL                                                                                |
| SimPO        | `rl: simpo`                                               | `trl.experimental.cpo.CPOTrainer` with `loss_type="simpo"`, `cpo_alpha=0.0` | via TRL                                                                                |
| GRPO         | `rl: grpo` + `axolotl vllm-serve`                         | `GRPOTrainer`, `trl grpo`                                                   | via TRL `GRPOTrainer`; Unsloth publishes RL notebooks                                  |
| Reward model | `rl: reward_trainer`                                      | `RewardTrainer`, `trl reward`                                               | via TRL                                                                                |
| RLOO         | (not listed in Axolotl `rl:` values)                      | `RLOOTrainer`, `trl rloo`                                                   | via TRL                                                                                |
| LoRA / QLoRA | `adapter: lora` / `adapter: qlora` + `load_in_4bit: true` | `peft_config=LoraConfig(...)` or `--use_peft --load_in_4bit`                | `FastLanguageModel.get_peft_model`, `load_in_4bit=True`                                |
| DoRA         | `peft_use_dora: true`                                     | `LoraConfig(use_dora=True)` / `--use_dora`                                  | not a named `get_peft_model` argument (it has `use_rslora`); DoRA support (unverified) |
| Full FT      | omit `adapter`                                            | omit `peft_config`                                                          | `full_finetuning=True`                                                                 |

Axolotl implements its RLHF methods on top of TRL and marks RLHF as beta. Axolotl `rl:` values listed in the config reference: `dpo`, `ipo`, `kto`, `simpo`, `orpo`, `grpo`, `ebft` (plus `gdpo` and `reward_trainer` documented in the RLHF/reward docs).

## Recommended sequence

1. LoRA SFT on clean chat data, evaluate vs base.
2. If outputs are right-ish but some failure modes persist and you can collect chosen/rejected pairs: DPO on top of the SFT adapter (or merged SFT model).
3. If the task has a checkable answer (tests, math, schema validation): GRPO with a reward function, starting from the SFT model, with LoRA (Axolotl docs strongly recommend LoRA for GRPO because adapter weight sync to vLLM is cheaper).
4. Full fine-tune only when LoRA results plateau and the data is proven.

## Known pitfalls

- Running DPO/GRPO on a base model that can't yet do the task: learn the task with SFT first.
- DPO with chosen/rejected pairs that differ in irrelevant ways (length, formatting) teaches those differences.
- GRPO reward hacking: the model optimizes the reward function, not your intent. Inspect samples during training.
- QLoRA then merging into a 4-bit base: merge into the bf16 base instead (see `evaluate-and-merge.md`).

## Official links

- Axolotl choosing a method: https://docs.axolotl.ai/docs/choosing_method.html
- Axolotl RLHF: https://docs.axolotl.ai/docs/rlhf.html
- TRL trainers: https://huggingface.co/docs/trl
- PEFT LoRA reference: https://huggingface.co/docs/peft/package_reference/lora
- DoRA paper: https://arxiv.org/abs/2402.09353
