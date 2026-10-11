# NeMo Framework repo map

> Verified against NVIDIA-NeMo org profile README, Automodel v0.6.0, Megatron-Bridge v0.6.2, RL v0.7.0, Export-Deploy v0.7.1, Run v0.11.1, 2026-10-11

NeMo Framework is NVIDIA's open-source (Apache-2.0) training framework, now split into focused repos under github.com/NVIDIA-NeMo. The original monolithic NeMo 2.x repo (github.com/NVIDIA/NeMo, last release v3.0.0 on 2026-08-07) now redirects to `NVIDIA-NeMo/Speech`: its LLM training code moved into the repos below. The org README says the framework is "in the process of restructuring".

## Which repo for which job

| Repo                                                                                          | Use for                                                                                                                                                                 | Training loop / backend                                                                                      | Container                                        |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| [Automodel](https://github.com/NVIDIA-NeMo/Automodel) (`nemo-automodel`, v0.6.0)              | Pretraining, SFT, LoRA/PEFT, distillation, speculative-decoding drafters for LLM, VLM, omni, diffusion and retrieval models; day-0 Hugging Face models; 1 to ~1000 GPUs | PyTorch-native loop, DTensor/FSDP2 (also DDP, Megatron-FSDP), MoE with expert parallelism                    | `nvcr.io/nvidia/nemo-automodel`                  |
| [Megatron-Bridge](https://github.com/NVIDIA-NeMo/Megatron-Bridge) (`megatron-bridge`, v0.6.2) | Pretraining, SFT, LoRA at the largest scale; HF <-> Megatron checkpoint conversion and verification                                                                     | PyTorch-native loop on Megatron-Core                                                                         | `nvcr.io/nvidia/nemo` (NeMo Framework container) |
| [RL](https://github.com/NVIDIA-NeMo/RL) (NeMo RL, v0.7.0)                                     | GRPO, PPO, DAPO, GSPO, CISPO, GDPO, DPO, reward models, SFT, on-policy and cross-tokenizer distillation, multi-turn RL                                                  | Ray; DTensor (via Automodel) or Megatron (via Megatron-Bridge) training; vLLM, SGLang or Megatron generation | `nvcr.io/nvidia/nemo-rl`                         |

Other repos (not covered in depth): Gym (RL environments, eval, sandboxing), Curator (data curation), Evaluator (model evaluation), Export-Deploy (export to vLLM, TensorRT, TensorRT-LLM, ONNX), Run (experiment launcher), Guardrails, DataDesigner, Safe-Synthesizer, Anonymizer, Emerging-Optimizers, Nemotron (asset hub), Skills (SDG and eval pipelines), Switchyard (routing), Speech.

The Megatron-Bridge support matrix lists: Megatron-Bridge pretrain, SFT, LoRA; AutoModel pretrain, SFT, LoRA; NeMo RL SFT, LoRA, RL, RL-LoRA (post-training with both Megatron and Automodel backends).

## Choosing

- Single node to a few hundred GPUs, HF-native models, YAML: Automodel.
- Need Megatron 6D parallelism or a Megatron checkpoint: Megatron-Bridge.
- Verifiable-reward RL or preference training at scale: NeMo RL.
- A small RL experiment on one GPU with Python scripts: consider `trl` or `unsloth`; for Ray + FSDP RL, `verl` or `openrlhf`.

## Agent skills shipped upstream

Automodel (`skills/`), RL (`skills/`) and Megatron-Bridge (`skills/`) each carry their own repo-specific agent skills (running recipes, model onboarding, development). Read them in the checkout when working on the repos' code.

## Discovery

```bash
for r in Automodel RL Megatron-Bridge Run Export-Deploy Gym; do
  gh api repos/NVIDIA-NeMo/$r/releases/latest --jq '"'$r' "+.tag_name+" "+.published_at'
done
for p in nemo-automodel megatron-bridge nemo-run nemo-export-deploy; do
  curl -s https://pypi.org/pypi/$p/json | jq -r '"'$p' "+.info.version+" py"+.info.requires_python'
done
```
