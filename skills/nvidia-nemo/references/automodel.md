# NeMo AutoModel

> Verified against NVIDIA-NeMo/Automodel v0.6.0 (README.md, docs/guides/installation.mdx, configuration.mdx, checkpointing.mdx, launcher/*.mdx, breaking-changes.mdx; PyPI nemo-automodel 0.6.0), 2026-10-11

PyTorch DTensor-native SPMD library: YAML recipes, `automodel` CLI (alias `am`), day-0 Hugging Face models. Python >= 3.10.

## Install

```bash
# PyPI (uv recommended)
uv venv && uv pip install "nemo-automodel"           # add extras: nemo-automodel[cli] for NeMo-Run submission
uv run --no-project python -c 'import nemo_automodel; print(nemo_automodel.__version__)'

# From a clone (reproducible, lockfile)
git clone https://github.com/NVIDIA-NeMo/Automodel.git && cd Automodel
uv venv && uv sync --frozen            # LLM recipes
# extras: --extra vlm --extra vlm-media | --extra cuda | --extra all | --all-extras

# NGC container (recommended for multi-node, Debian/Ubuntu); check the NGC catalog for the newest tag
docker pull nvcr.io/nvidia/nemo-automodel:26.10.00
docker run --gpus all -it --rm --shm-size=8g \
  -v "$PWD/checkpoints":/opt/Automodel/checkpoints \
  -v "$HOME/.cache/huggingface":/root/.cache/huggingface \
  nvcr.io/nvidia/nemo-automodel:26.10.00
```

The source lock selects PyTorch cu130 wheels on Linux; the host driver must support that CUDA runtime (containers use the host driver, not their own). No host CUDA toolkit is needed for wheels or containers. Minimum 16 GB RAM (32+ recommended), 50 GB free disk, GPU with 8 GB+ VRAM. macOS is CPU/experimentation only. The `26.10.00` tag is the one named in the v0.6.0 docs: confirm it exists in the NGC catalog before pulling.

## Run

```bash
automodel <config.yaml> [--nproc-per-node N] [--key.subkey value ...]
am examples/llm_finetune/llama3_2/llama3_2_1b_squad.yaml                       # 1 GPU, SFT
automodel examples/llm_finetune/llama3_2/llama3_2_1b_hellaswag_peft.yaml --nproc-per-node 8   # LoRA
automodel config.yaml --model.pretrained_model_name_or_path Qwen/Qwen3-0.6B   # override any field
# direct script (dev): torchrun --nproc-per-node=2 nemo_automodel/recipes/llm/train_ft.py -c <config.yaml>
```

Without `--nproc-per-node` the CLI uses all visible GPUs via `torchrun`. The YAML must name a recipe (three accepted forms: `recipe: TrainFinetuneRecipeForNextTokenPrediction`, a dotted path, or `recipe: {_target_: ...}`). Recipe classes: LLM fine-tune/pretrain `recipes.llm.train_ft.TrainFinetuneRecipeForNextTokenPrediction`, VLM `recipes.vlm.finetune.FinetuneRecipeForVLM`, distillation `recipes.llm.kd.KnowledgeDistillationRecipeForNextTokenPrediction`, benchmarking `recipes.llm.benchmark...`, sequence classification `recipes.llm.train_seq_cls...`. Browse `examples/llm_pretrain`, `llm_finetune`, `vlm_finetune`, `diffusion`, `dllm_sft` in the clone.

## YAML anatomy (see `templates/automodel-lora-llama.yaml`)

`recipe`, `step_scheduler` (`global_batch_size`, `local_batch_size`, `ckpt_every_steps`, `val_every_steps`, `num_epochs`), `dist_env`, `rng`, `model` (`_target_: nemo_automodel.NeMoAutoModelForCausalLM.from_pretrained`, `pretrained_model_name_or_path`, `torch_dtype`), `checkpoint`, `peft` (LoRA `PeftConfig`: `target_modules`, `dim`, `alpha`), `distributed`, `loss_fn`, `dataset`/`validation_dataset`, `packed_sequence`, `dataloader`, `optimizer`, optional `wandb`. Remove `peft` for full fine-tuning.

- `distributed.strategy`: `fsdp2`, `ddp` or `megatron_fsdp`, with `dp_size`, `tp_size`, `cp_size`, `pp_size`, `sequence_parallel`. The FSDP2 mixed-precision default `reduce_dtype` is float32 since 0.5.0.
- `freeze_config`: `freeze_modules` / `unfreeze_modules` with `path:` (exact module name) or `glob:` selectors for VLM/omni models.
- `prewarm`: `cublas_backward`, `fla_gdn_autotune`, `mamba_ssd_autotune`, `comm_groups`, `pipeline_stage_compile`; enable only the one matching an observed first-step failure (long-context OOM at step 0).
- Strings are typed (`"10"` -> 10). Env vars interpolate in YAML strings; config printing keeps placeholders so secrets are not leaked. Do not put tokens in YAML.
- **Config is code:** `_target_` imports any importable package or `file.py:symbol`; run only trusted YAML.

## Checkpoints

- `checkpoint.model_save_format`: `safetensors` or `torch_save`; optimizer state is DCP (`.distcp`).
- `checkpoint.save_consolidated`: `final` (recommended; sharded intermediates, consolidated HF weights at the end), `false` (sharded only; run the generated `model/consolidate.sh` later), `every`/`true`. PEFT checkpoints are consolidated adapters.
- Symlinks `LATEST` and `LOWEST_VAL`; `max_recent_checkpoints` bounds retention (local filesystems only; leave unset for `msc://`). `checkpoint.is_async: true` for background saves. Partial saves are marked in-progress and skipped on resume. Resuming from an older checkpoint with `restore_from` fails with `FileExistsError` if a published checkpoint exists for a later step.
- Serve the consolidated directory with `vllm serve` (skill `vllm`).

## Discovery

```bash
automodel --help | head -20
ls examples/llm_finetune | head -40
grep -n 'strategy\|tp_size\|pp_size' <config.yaml>
```
