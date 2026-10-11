---
name: fine-tuning-llms
description: Fine-tune open-weight LLMs locally (NVIDIA DGX Spark unified memory, consumer RTX GPUs) or on rented cloud GPUs. Covers deciding whether to fine-tune vs prompting or RAG, dataset prep (chat templates, messages JSONL, ShareGPT/Alpaca, preference pairs, dedup, PII scrubbing, held-out eval split), choosing LoRA, QLoRA, DoRA or full fine-tuning, SFT, DPO, KTO, ORPO and GRPO, training with Axolotl YAML configs, Unsloth or Hugging Face TRL (SFTTrainer, DPOTrainer, GRPOTrainer, trl sft), memory planning and memory-capped runs, evaluating against the base model, merging adapters (axolotl merge-lora, PEFT merge_and_unload), exporting to GGUF (convert_lora_to_gguf.py, convert_hf_to_gguf.py), serving LoRA adapters with vLLM (--enable-lora, --lora-modules, /v1/load_lora_adapter) or llama.cpp llama-server (--lora, /lora-adapters), and checking model and dataset licenses (Llama, Gemma, Qwen, Mistral). Use when a user says fine-tune, LoRA, QLoRA, SFT, DPO, GRPO, train an adapter, axolotl, unsloth, trl, or serve a LoRA.
license: MIT
metadata:
  author: ScaleDockHQ
  version: "1.2.0"
compatibility: Linux with an NVIDIA GPU (x86_64 or arm64, incl. DGX Spark) for training; Docker optional. Uses Python CLIs (axolotl, trl, llama.cpp converters) via shell, plus curl, jq and optionally systemd-run for memory caps.
---

# Fine-Tuning LLMs

Fine-tune open-weight models with parameter-efficient (LoRA/QLoRA) or full training, using SFT, preference tuning (DPO/KTO/ORPO) or RL (GRPO), on a local GPU, a DGX Spark, or rented cloud GPUs. Covers the decision to fine-tune, data prep, method and hardware choice, training with Axolotl (default), Unsloth or TRL, evaluation against the base, merging, GGUF export, and serving adapters.

Out of scope, use companion skills: quantization types and GGUF quantizing (`model-quantization`), building task evals and quality gates (`llm-evals`), renting cloud GPUs (`cloud-llms`), running the serving stack (`self-hosted-llms`, `local-llms`), gateway routing (`llm-gateway`).

## Discover first

Run these read-only commands before recommending anything:

```bash
# GPU, memory, architecture
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv
free -h 2>/dev/null || sysctl hw.memsize
uname -m
# Disk for models, checkpoints, merged weights
df -h ~ ~/.cache/huggingface 2>/dev/null
# Tools
for t in axolotl trl accelerate hf vllm llama-server llama-quantize docker systemd-run tmux; do command -v "$t" >/dev/null && echo "found $t" || echo "missing $t"; done
python3 -c 'import torch, sys; print(torch.__version__, torch.cuda.is_available())' 2>/dev/null || echo "no torch in this python"
# Cached models
hf cache ls 2>/dev/null || du -sh ~/.cache/huggingface/hub/* 2>/dev/null
# Things already using memory (servers, containers)
ss -ltnp 2>/dev/null || lsof -nP -iTCP -sTCP:LISTEN
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null
systemctl --user list-units --type=service --state=running 2>/dev/null
# Token present (never print it)
test -n "$HF_TOKEN" && echo "HF_TOKEN set" || echo "HF_TOKEN not set"
```

Ask only what can't be discovered:

- What behavior should change, and what does a good output look like (5-10 examples)?
- What data exists (source, size, format, contains PII?), and may it be used for training?
- Which base model (or constraints: size, language, license, commercial use)?
- Where will the result run (vLLM with adapters, llama.cpp/Ollama GGUF, cloud endpoint)?
- May running model servers on this machine be stopped during training?

## Decision flow

- Missing knowledge -> retrieval, not fine-tuning. Inconsistent format/style or a narrow repeated task -> fine-tune after prompting fails (`references/when-to-fine-tune.md`).
- Input/output examples -> SFT. Chosen/rejected pairs -> SFT then DPO (or ORPO). Good/bad labels -> KTO. Programmatic reward -> GRPO (`references/methods.md`).
- Fits in bf16 with headroom -> LoRA. Doesn't fit -> QLoRA. Proven data, lots of GPU -> full FT (`references/hardware.md`).
- Config-only, reproducible, multi-GPU -> Axolotl. Single GPU, memory-tight, notebooks -> Unsloth. Custom Python / newest trainers -> TRL.
- Many fine-tunes on one base or vLLM serving -> keep adapters. Ollama/LM Studio or quantizing -> merge then GGUF.

## Rules

- **Try prompting and retrieval first.** Fine-tuning is slow to iterate and can't keep facts fresh. Show that a prompted base model and RAG fall short on a measured eval before training.
- **Data quality beats data quantity.** A smaller set of clean, consistent, deduplicated examples beats a big noisy dump. Inspect rendered prompts and loss masks before any long run.
- **Hold out an eval set before training.** Split by source before dedup or augmentation, check for train/eval overlap, and never let the trainer see it.
- **Start with LoRA.** It is cheap, fast, easy to serve and roll back. Move to QLoRA for memory, full fine-tuning only after LoRA has proven the data.
- **Check the license before you train or ship.** Base model, datasets, and teacher-model outputs each carry terms; some impose naming, attribution or research-only limits.
- **Cap memory; checkpoint often.** Run training, merges and conversions in memory-capped scopes, save checkpoints regularly, and stop co-located servers on unified-memory machines.
- **Train and serve with the same chat template.** A template mismatch silently erases the fine-tune; verify the served template matches the training one.
- **Measure against the base model, not the loss curve.** Compare base and fine-tuned outputs on the same held-out prompts with a task metric before you merge or deploy.

## Workflows

### 1. Decide whether to fine-tune

- [ ] Write 10 inputs with expected outputs; state what must change (`references/when-to-fine-tune.md`).
- [ ] Score the base model and a well-prompted base model on a held-out set (eval design via `llm-evals`).
- [ ] Try retrieval/tools if the gap is knowledge; try a larger or specialized base if the gap is capability.
- [ ] Check base model and data licenses for your use and distribution (`references/licenses.md`).
- [ ] Go/no-go: fine-tune only if the gap is format, style, task behavior, or reward-checkable skill.

### 2. Prepare data

- [ ] Convert to chat `messages` JSONL (or the preference/prompt-only shape your method needs) (`references/data-prep.md`).
- [ ] Split train/eval by source before anything else; save `data/eval.jsonl` and don't touch it.
- [ ] Dedup, scrub PII and secrets, fix roles, ensure the last turn is the assistant turn.
- [ ] Check token-length distribution against the planned `sequence_len`.
- [ ] Render with the target model's chat template and inspect masks: `axolotl preprocess cfg.yaml --debug` (`references/axolotl.md`).

### 3. Choose method and hardware

- [ ] Pick objective (SFT first; DPO/KTO/ORPO/GRPO later) and update method (LoRA default) (`references/methods.md`).
- [ ] Estimate memory for model size, method and context; pick local GPU, DGX Spark, or cloud (`references/hardware.md`; renting via `cloud-llms`).
- [ ] Pick the tool: Axolotl (`references/axolotl.md`), Unsloth (`references/unsloth.md`), or TRL (`references/trl.md`).
- [ ] Pre-download the base model with a memory cap and the hf-xet settings from `references/hardware.md`.

### 4. Train

- [ ] Axolotl: install the `axolotl` skill and copy its `templates/lora-sft.yaml`; set `base_model`, data paths, `sequence_len`, `lora_r`, output dirs (`references/axolotl.md`).
- [ ] On shared or unified-memory machines, stop model servers or budget memory explicitly (`references/hardware.md`).
- [ ] Launch inside `tmux` and a memory-capped scope: `systemd-run --user --scope -p MemoryMax=<cap> -p MemorySwapMax=0 -- axolotl train cfg.yaml`.
- [ ] Watch train and eval loss; stop if eval loss rises steadily (overfitting) or loss is NaN.
- [ ] Alternatives: Unsloth script for single-GPU memory-tight runs (`references/unsloth.md`); `trl sft --use_peft ...` or a TRL script for custom code or GRPO rewards (`references/trl.md`).
- [ ] Resume interrupted runs from the last checkpoint (`--resume-from-checkpoint`).

### 5. Evaluate against the base

- [ ] Generate on the held-out set with base and with each candidate checkpoint, same decoding (`references/evaluate-and-merge.md`).
- [ ] Score with the task metric and a small regression set; gates and harnesses via `llm-evals`.
- [ ] Read 20-50 outputs side by side: template leakage, missing stop, memorized rows.
- [ ] Record base revision, data hash, config, scores next to the adapter.

### 6. Merge or keep the adapter

- [ ] Keep the adapter for multi-LoRA vLLM/llama-server serving and easy rollback (`references/evaluate-and-merge.md`).
- [ ] Merge for single-model deploys, Ollama, or before quantizing: `axolotl merge-lora cfg.yaml` (QLoRA: `--dequant`) or PEFT `merge_and_unload` into a bf16 base.
- [ ] Run merges memory-capped; verify tokenizer files and chat template in the merged dir.
- [ ] Spot-check that merged outputs match the adapter's outputs.

### 7. Export

- [ ] Merged model to GGUF: `convert_hf_to_gguf.py` (or `axolotl export`), then quantize via `model-quantization` (`references/evaluate-and-merge.md`).
- [ ] Adapter to GGUF LoRA for llama-server: `convert_lora_to_gguf.py <adapter-dir> --base <base-hf-dir> --outtype f16`.
- [ ] Use a separate venv for llama.cpp converter dependencies.
- [ ] Publish with a model card: base model, license, required naming/attribution (`references/licenses.md`).

### 8. Serve

- [ ] vLLM: `--enable-lora`, `--lora-modules name=path`, `--max-lora-rank` >= adapter rank, `--max-loras` for concurrency (`references/serving-adapters.md`).
- [ ] Dynamic adapters only in trusted setups: `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True` and `/v1/load_lora_adapter` / `/v1/unload_lora_adapter`.
- [ ] llama.cpp: `llama-server -m base.gguf --lora adapter.gguf` (or `--lora-scaled`); manage scales via `/lora-adapters`.
- [ ] Ollama: current releases don't accept adapters; serve a merged GGUF via `FROM` instead.
- [ ] Expose adapters as model names through LiteLLM / llama-swap (`llm-gateway`, `self-hosted-llms`); smoke test base vs adapter.

### 9. Troubleshoot

- [ ] OOM: shorten `sequence_len`, micro-batch 1 + more accumulation, gradient checkpointing, 8-bit optimizer, QLoRA, smaller model (`references/hardware.md`).
- [ ] Node froze or other services died: no memory cap, co-located server, or hf-xet download inside the job (`references/hardware.md`).
- [ ] Loss flat or NaN: learning rate, masks all `-100`, wrong template, fp16 on a GPU without bf16 (`references/data-prep.md`, `references/axolotl.md`).
- [ ] Model never stops: EOS not trained (`train_on_eos`), wrong EOT token (`references/data-prep.md`).
- [ ] Fine-tune "disappears" when served: template mismatch, adapter on wrong base, or adapter not selected by `model` name (`references/serving-adapters.md`).
- [ ] Adapter rejected by vLLM: rank above `--max-lora-rank` or LoRA not enabled (`references/serving-adapters.md`).
- [ ] GGUF conversion fails: adapter-only dir passed to export, vocab mismatch, quantized checkpoint (`references/evaluate-and-merge.md`).

## Reference index

- `references/when-to-fine-tune.md` — prompting vs RAG vs fine-tuning ladder, good and bad fits, pre-flight questions.
- `references/data-prep.md` — chat templates, Axolotl and TRL dataset formats, splitting, dedup, PII scrubbing, mask inspection.
- `references/methods.md` — full, LoRA, QLoRA, DoRA; SFT, DPO, KTO, ORPO, SimPO, GRPO; which tool supports which.
- `references/axolotl.md` — how Axolotl plugs into this stack; depth in the `axolotl` skill.
- `references/unsloth.md` — how Unsloth plugs into this stack; depth in the `unsloth` skill.
- `references/trl.md` — how TRL plugs into this stack; depth in the `trl` skill.
- `references/hardware.md` — memory rules of thumb, DGX Spark unified memory, consumer and cloud GPUs, memory-capped scopes, hf-xet env vars, checkpointing.
- `references/evaluate-and-merge.md` — compare vs base, merge vs keep, merge recipes, GGUF export routes.
- `references/serving-adapters.md` — vLLM multi-LoRA and dynamic loading, llama-server LoRA, Ollama status, LiteLLM/llama-swap wiring.
- `references/licenses.md` — Llama, Gemma, Qwen, Mistral license checks, dataset and teacher-output terms, ship checklist.

## Companion skills

Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`:

- `axolotl` — config-driven training, multi-GPU, merge and export, the default trainer.
- `unsloth` — memory-tight single-GPU training, Studio, merged and GGUF export.
- `trl` — custom Python trainers, reward functions, GRPO with vLLM.
- `llama-factory` — web UI and YAML-driven training across many models.
- `peft` — LoRA and other adapters on Transformers.
- `deepspeed` — ZeRO sharding and offload for multi-GPU training.
- `verl` — RL post-training (GRPO, PPO) at scale.
- `openrlhf` — Ray and vLLM based RLHF.
- `nvidia-nemo` — NeMo AutoModel, Megatron-Bridge and NeMo RL.
- `llm-evals` — build the eval set, metrics and quality gates used to compare base vs fine-tune.
- `model-quantization` — quantize merged models (GGUF types, imatrix, AWQ/GPTQ/FP8).
- `cloud-llms` — rent cloud GPUs when local memory isn't enough.
- `self-hosted-llms` — run vLLM / llama.cpp behind llama-swap and LiteLLM on your servers, DGX Spark included.
- `local-llms` — run the result on a laptop/desktop (Ollama, LM Studio, llama.cpp).
- `llm-gateway` — expose adapters as model names, keys and routing in LiteLLM.
- `choosing-llm-hosting` — decide where the fine-tuned model should run.
- `llm-observability` — monitor per-adapter traffic, latency and errors.
