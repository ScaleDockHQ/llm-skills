# Unsloth

> Verified against unslothai/unsloth library 2026.10.3 (PyPI) and GitHub release v0.1.905-beta (Unsloth Studio), 2026-10-11

## What it is and when to choose it

[Unsloth](https://github.com/unslothai/unsloth) provides patched model loaders and kernels for faster, lower-memory LoRA/QLoRA/full fine-tuning and RL on a single GPU, on top of TRL trainers. It ships as two things:

- **Unsloth Core** — the Python library (`pip install unsloth`, versioned by date, e.g. `2026.10.x`).
- **Unsloth Studio / Desktop** — a GUI app (GitHub releases `v0.1.x-beta`, `.deb` for Linux ARM64 among others).

Choose it for **single-GPU or single DGX Spark** runs where memory is the constraint, for its notebooks (many models, RL examples), or for one-call GGUF/merged export. For multi-GPU or config-only reproducibility prefer Axolotl.

## Install

**Linux / WSL (x86_64), Core library:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv venv unsloth_env --python 3.13
source unsloth_env/bin/activate
uv pip install unsloth --torch-backend=auto
```

**Docker (amd64 and arm64):** `unsloth/unsloth` (tags `latest`, `studio`, `core`, dated `nightly-*`; Docker Hub manifests list `amd64` and `arm64`). Notebooks-only image: `unsloth/unsloth:core`. AMD: `unsloth/unsloth-rocm`.

**DGX Spark:** Unsloth's README points to its [DGX Spark guide](https://unsloth.ai/docs/blog/fine-tuning-llms-with-nvidia-dgx-spark-and-unsloth), which builds a dedicated image from `Dockerfile_DGX_Spark` in [unslothai/notebooks](https://github.com/unslothai/notebooks):

```bash
wget -O Dockerfile "https://raw.githubusercontent.com/unslothai/notebooks/main/Dockerfile_DGX_Spark"
docker build -f Dockerfile -t unsloth-dgx-spark .
```

That Dockerfile is based on `nvcr.io/nvidia/pytorch` (CUDA 13), builds Triton and xformers from source for GB10 (`TORCH_CUDA_ARCH_LIST="12.1"`), and **pins older** `transformers`/`trl`/`bitsandbytes` versions. Expect a long build; run it memory-capped (see `hardware.md`). Whether the multi-arch `unsloth/unsloth` image or a plain `uv pip install unsloth` works on Spark without that Dockerfile is (unverified) — test with a tiny model first. Blackwell RTX 50: see Unsloth's Blackwell guide.

## Minimal working config/command

Unsloth is a Python API (Studio is a GUI). Short LoRA SFT:

```python
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer

model, tokenizer = FastLanguageModel.from_pretrained(
    "<org>/<model>", max_seq_length=4096, load_in_4bit=True,  # QLoRA; False for bf16 LoRA
)
model = FastLanguageModel.get_peft_model(
    model, r=16, lora_alpha=32, lora_dropout=0.0, use_gradient_checkpointing="unsloth",
)
ds = load_dataset("json", data_files="data/train.jsonl", split="train")
trainer = SFTTrainer(model=model, processing_class=tokenizer, train_dataset=ds,
                     args=SFTConfig(output_dir="outputs/unsloth-lora", num_train_epochs=2))
trainer.train()
model.save_pretrained("outputs/unsloth-lora/adapter")      # adapter only
tokenizer.save_pretrained("outputs/unsloth-lora/adapter")
```

Import `unsloth` before `transformers`/`trl` so its patches apply. Check the Unsloth notebook for your model family for the exact chat-template helper and SFT args.

## How it plugs into the stack

- **In:** HF model ids (Unsloth also publishes pre-quantized `unsloth/*-bnb-4bit` repos) or local dirs; `datasets` in TRL formats.
- **Out:**
  - Adapter: `model.save_pretrained(dir)` (PEFT format; works with vLLM `--lora-modules`, llama.cpp `convert_lora_to_gguf.py`).
  - Merged: `model.save_pretrained_merged(dir, tokenizer, save_method="merged_16bit")` (`"lora"` = adapter only, `"merged_4bit"` discouraged for further use).
  - GGUF: `model.save_pretrained_gguf(dir, tokenizer, quantization_method="q4_k_m")` (uses llama.cpp under the hood; quant choice belongs to `model-quantization`).
- Studio/Desktop exposes the same flow in a GUI and can run models locally.

## Operating

- One process per GPU; Unsloth targets single-device training (multi-GPU support status changes; check current docs before planning on it).
- Use `full_finetuning=True` in `from_pretrained` for full FT, `load_in_8bit=True` for 8-bit.
- Keep notebooks out of production: export the cells into a script and run it under `tmux` / `systemd-run` with a memory cap.

## Tuning knobs worth knowing

- `from_pretrained`: `max_seq_length`, `load_in_4bit`, `load_in_8bit`, `full_finetuning`, `dtype`.
- `get_peft_model`: `r`, `lora_alpha`, `lora_dropout`, `target_modules`, `use_gradient_checkpointing="unsloth"` (offloaded checkpointing), `use_rslora`, `random_state`.
- Trainer settings come from TRL (`SFTConfig`, `DPOConfig`, `GRPOConfig`).

## Known pitfalls

- Version skew: Unsloth patches specific `transformers`/`trl` versions. Let the Unsloth install pick them; don't upgrade TRL independently.
- GitHub "latest release" is Studio, not the library; check PyPI for the Core version.
- `save_pretrained_gguf` builds/uses llama.cpp and can use a lot of RAM on big models; on unified-memory machines stop serving first.
- 4-bit merged saves are lossy; merge into 16-bit for anything you'll re-quantize.

## Official links

- Repo: https://github.com/unslothai/unsloth
- Docs: https://unsloth.ai/docs
- Fine-tuning guide: https://unsloth.ai/docs/get-started/fine-tuning-llms-guide
- DGX Spark guide: https://unsloth.ai/docs/blog/fine-tuning-llms-with-nvidia-dgx-spark-and-unsloth
- Docker guide: https://unsloth.ai/docs/get-started/install/docker
- Notebooks: https://github.com/unslothai/notebooks
