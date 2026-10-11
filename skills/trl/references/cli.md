# TRL CLI and scaling

> Verified against huggingface/trl v1.15.0 (docs/source/clis.md), 2026-10-11

## Commands

Training: `trl sft`, `trl dpo`, `trl grpo`, `trl kto`, `trl reward`, `trl rloo`, `trl distillation` (on-policy distillation). Other: `trl env` (system info for bug reports), `trl vllm-serve` (**deprecated**, use `vllm serve`, see `combos/grpo-vllm.md`).

```bash
trl sft --model_name_or_path Qwen/Qwen2.5-0.5B --dataset_name stanfordnlp/imdb
trl grpo --model_name_or_path Qwen/Qwen2.5-0.5B \
  --dataset_name HuggingFaceH4/Polaris-Dataset-53K --reward_funcs accuracy_reward
```

`--reward_funcs` takes names of built-in functions (for example `accuracy_reward`). Custom Python reward functions need a script (`trainers.md`).

## YAML configs

Every flag can live in a YAML file, run with `trl <method> --config file.yaml`. Upstream's examples contain `model_name_or_path`, `dataset_name`, `reward_funcs` (a list), `num_processes` and `accelerate_config`. Starters: `templates/sft-lora.yaml`, `templates/grpo.yaml`.

Dataset mixtures:

```yaml
model_name_or_path: Qwen/Qwen2.5-0.5B
datasets:
  - path: HuggingFaceH4/Polaris-Dataset-53K
  - path: trl-lib/DeepMath-103K
```

All keywords for mixtures: `DatasetConfig` and `DatasetMixtureConfig` classes in the TRL source.

## Scaling with Accelerate

Pass `accelerate launch` arguments straight to `trl`:

```bash
trl sft --model_name_or_path Qwen/Qwen2.5-0.5B --dataset_name stanfordnlp/imdb --num_processes 4
trl sft --model_name_or_path Qwen/Qwen2.5-0.5B --dataset_name stanfordnlp/imdb --accelerate_config zero2
```

`--accelerate_config` accepts a built-in profile or a path to your own Accelerate YAML. Built-in profiles (loaded from `trl/accelerate_config/`): `fsdp1`, `fsdp2`, `zero1`, `zero2`, `zero3`, `multi_gpu`, `single_gpu`.

For scripts: `accelerate launch train.py`, optionally `--config_file` pointing at an Accelerate or DeepSpeed config.

## Local data and custom logic

The docs show only Hub dataset names for the CLI. For a local JSONL file, use a Python script and `datasets.load_dataset("json", data_files=...)` (`trainers.md`).
