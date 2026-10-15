# Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0, 2026-10-11

## How it plugs into this stack

Axolotl is this skill's default trainer: one YAML describes model, data, adapter and trainer, and `axolotl` preprocesses, trains, merges and exports.

- **In:** HF model id or local dir (`base_model`) and train/eval JSONL from `data-prep.md`. The `axolotl` skill ships a commented starter, `templates/lora-sft.yaml`.
- **Check masks first:** `axolotl preprocess cfg.yaml --debug` before any long run.
- **Out:** adapter in `output_dir` for vLLM `--lora-modules` and `convert_lora_to_gguf.py` (`serving-adapters.md`), or merged weights via `axolotl merge-lora cfg.yaml` (QLoRA: `--dequant`) for `evaluate-and-merge.md`.
- **Run it** in `tmux` and a memory-capped scope (`hardware.md`).

Depth: install the axolotl skill (npx skills add ScaleDockHQ/llm-skills --skill axolotl)
