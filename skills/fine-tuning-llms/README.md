# Fine-Tuning LLMs Skill

An agent skill for fine-tuning open-weight LLMs on a local GPU, an NVIDIA DGX Spark, or rented cloud GPUs: deciding whether fine-tuning beats prompting or retrieval, preparing chat and preference datasets, choosing LoRA, QLoRA or full fine-tuning with SFT, DPO, KTO, ORPO or GRPO, training with [Axolotl](https://github.com/axolotl-ai-cloud/axolotl), [Unsloth](https://github.com/unslothai/unsloth) or [TRL](https://github.com/huggingface/trl), evaluating against the base model, merging with [PEFT](https://github.com/huggingface/peft), exporting to GGUF with [llama.cpp](https://github.com/ggml-org/llama.cpp), and serving adapters with [vLLM](https://github.com/vllm-project/vllm) or llama-server. It also covers model and dataset license checks.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms
```

## Rules

- **Try prompting and retrieval first.** Fine-tune only after a measured eval shows prompting and RAG fall short.
- **Data quality beats data quantity.** Clean, consistent, deduplicated data with correct masks matters more than volume.
- **Hold out an eval set before training.** Split by source first and keep it away from the trainer.
- **Start with LoRA.** Cheap, fast, easy to serve and roll back; QLoRA for memory, full fine-tuning last.
- **Check the license before you train or ship.** Base model, data and teacher outputs each carry terms, including naming and research-only limits.
- **Cap memory; checkpoint often.** Memory-capped scopes for training, merges and conversions; regular checkpoints; stop co-located servers on unified memory.
- **Train and serve with the same chat template.** A template mismatch silently erases the fine-tune.
- **Measure against the base model, not the loss curve.** Same held-out prompts, task metric, side-by-side reads.

## References

- [`references/when-to-fine-tune.md`](references/when-to-fine-tune.md) — prompting vs RAG vs fine-tuning, good and bad fits.
- [`references/data-prep.md`](references/data-prep.md) — chat templates, Axolotl and TRL dataset formats, dedup, PII scrubbing.
- [`references/methods.md`](references/methods.md) — full, LoRA, QLoRA, DoRA; SFT, DPO, KTO, ORPO, GRPO; tool support matrix.
- [`references/axolotl.md`](references/axolotl.md) — Axolotl install, CLI, config knobs, Docker and arm64.
- [`references/unsloth.md`](references/unsloth.md) — Unsloth install incl. DGX Spark, short Python script, exports.
- [`references/trl.md`](references/trl.md) — TRL CLI and SFT/DPO/GRPO trainer snippets.
- [`references/hardware.md`](references/hardware.md) — memory estimates, DGX Spark, consumer and cloud GPUs, memory caps, hf-xet.
- [`references/evaluate-and-merge.md`](references/evaluate-and-merge.md) — compare vs base, merge adapters, GGUF export.
- [`references/serving-adapters.md`](references/serving-adapters.md) — vLLM multi-LoRA, llama-server LoRA, Ollama status, gateway wiring.
- [`references/licenses.md`](references/licenses.md) — Llama, Gemma, Qwen, Mistral and dataset license checks.
- [`templates/axolotl-lora.yaml`](templates/axolotl-lora.yaml) — commented Axolotl LoRA SFT config.

## Companion skills

- `llm-evals` — eval sets and quality gates for base vs fine-tune (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`)
- `model-quantization` — quantize merged models, GGUF types (install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`)
- `cloud-llms` — rent cloud GPUs for bigger runs (install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`)
- `self-hosted-llms` — serve the result with vLLM / llama.cpp behind llama-swap and LiteLLM (install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`)
- `local-llms` — run the result on a laptop or desktop (install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`)
- `llm-gateway` — expose adapters as model names in LiteLLM (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`)
- `choosing-llm-hosting` — decide where the model should run (install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`)
- `llm-observability` — monitor per-adapter traffic and errors (install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`)

## License

MIT
