# Unsloth

> Verified against unslothai/unsloth library 2026.10.3 (PyPI) and GitHub release v0.1.905-beta (Unsloth Studio), 2026-10-11

## How it plugs into this stack

Choose Unsloth for single-GPU or single-DGX-Spark runs where memory is the constraint, or for one-call merged and GGUF export.

- **In:** HF model ids (including Unsloth's pre-quantized `unsloth/*-bnb-4bit` repos) and datasets in TRL formats from `data-prep.md`.
- **Out:** adapter via `model.save_pretrained(dir)` (PEFT format, works with vLLM `--lora-modules` and `convert_lora_to_gguf.py`, see `serving-adapters.md`), merged 16-bit weights, or GGUF for Ollama (`evaluate-and-merge.md`).
- **Run it** as a script in `tmux` under a memory cap, not in a notebook (`hardware.md`). On DGX Spark the GGUF export and image builds can use a lot of RAM; stop servers first.

Depth: install the unsloth skill (npx skills add ScaleDockHQ/llm-skills --skill unsloth)
