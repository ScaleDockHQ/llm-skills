# TRL (Transformer Reinforcement Learning)

> Verified against huggingface/trl v1.15.0 and huggingface/peft v0.21.2, 2026-10-11

## How it plugs into this stack

Choose TRL directly for custom Python (reward functions, collators), the newest methods, or a small script. Axolotl and Unsloth both build on it.

- **In:** HF model id or local dir, datasets from `data-prep.md` (`messages`, preference pairs, or prompts plus reward columns).
- **Out:** the same adapter and merged weights as the other trainers (`evaluate-and-merge.md`, `serving-adapters.md`).
- **Run it** in `tmux` under a memory cap (`hardware.md`). For GRPO, keep generation on separate GPUs or colocated per the skill.

Depth: install the trl skill (npx skills add ScaleDockHQ/llms-skills --skill trl)
