# Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0, 2026-10-11

## What it is and when to choose it

[Axolotl](https://github.com/axolotl-ai-cloud/axolotl) is a config-driven fine-tuning framework: one YAML file describes model, data, adapter, and trainer; the `axolotl` CLI preprocesses, trains, evaluates, merges, and exports. It wraps Hugging Face Transformers, PEFT, and TRL (for preference/RL methods).

Choose it when you want **reproducible runs without writing Python**, multi-GPU (FSDP/DeepSpeed), many dataset formats, or SFT + DPO/KTO/ORPO/GRPO from the same config style. This skill's default trainer. Template: `templates/axolotl-lora.yaml`.

## Install

Requirements (docs/installation.qmd): NVIDIA GPU (Ampere+ for bf16/Flash Attention) or AMD GPU, Python >= 3.12, recent PyTorch. Blackwell GPUs: use CUDA 13.0 builds.

**uv (recommended by upstream), x86_64 Linux:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export UV_TORCH_BACKEND=cu130   # or cu128
uv venv && source .venv/bin/activate
uv pip install --no-build-isolation 'axolotl[deepspeed]'
axolotl --help
```

Add `[vllm]` extra for GRPO (`'axolotl[vllm]'`).

**Docker (amd64 and arm64):** `axolotlai/axolotl` (alias `axolotlai/axolotl-uv`); `main-latest` targets Python 3.12 / CUDA 13.0 / PyTorch 2.13. The Docker Hub manifest for `main-latest` lists both `amd64` and `arm64`. Cloud variant `axolotlai/axolotl-cloud` sets `HF_HOME=/workspace/data/huggingface-cache` and starts Jupyter (disable with `JUPYTER_DISABLE=1`).

```bash
docker run --gpus all --rm -it --ipc=host \
  --mount type=bind,src="$PWD",target=/workspace/axolotl \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN \
  axolotlai/axolotl:main-latest
```

**DGX Spark / arm64:** Axolotl's docs have no DGX Spark page. The arm64 Docker image is the most direct route; a native `uv pip install` on aarch64 + GB10 is (unverified) — check for prebuilt wheels of flash-attn/bitsandbytes/deepspeed for aarch64 first, or skip those extras. Pin the tag (e.g. a release tag like `0.20.0`) rather than `main-latest` for reproducibility.

## Minimal working config/command

```bash
cp templates/axolotl-lora.yaml my-run.yaml   # edit base_model, data paths
axolotl preprocess my-run.yaml --debug --debug-num-examples 3   # check masking
axolotl train my-run.yaml
axolotl inference my-run.yaml --lora-model-dir ./outputs/lora-run --chat
```

Config file may also be a URL to raw YAML. CLI overrides use dash form: `axolotl train my-run.yaml --learning-rate 1e-4 --micro-batch-size 2 --num-epochs 3`.

Example configs: `axolotl fetch examples` (writes `examples/` locally; e.g. `examples/llama-3/lora-1b.yml`, `instruct-lora-8b.yml`, `qlora-1b.yml`, `instruct-dpo-lora-8b.yml`, `examples/qwen3.5/*-qlora.yaml`).

## How it plugs into the stack

- **In:** HF model id or local dir (`base_model`), datasets from HF Hub / local JSON/JSONL/CSV/Parquet/Arrow / `s3://` / `gs://`.
- **Out:** `output_dir` with checkpoints and the adapter (`adapter_model.safetensors` + `adapter_config.json`) for LoRA/QLoRA, or full weights for full FT.
- `axolotl merge-lora my-run.yaml` writes merged weights to `<output_dir>/merged` for vLLM/SGLang/TGI or GGUF conversion.
- `axolotl export my-run.yaml --quantize Q4_K_M` converts a *merged* checkpoint to GGUF using a llama.cpp checkout in `$LLAMA_CPP_DIR` (refuses adapter-only dirs). GGUF details belong to the `model-quantization` skill.
- `axolotl vllm-serve config.yaml` launches the vLLM generation server used by GRPO.

## Operating

| Command | Purpose |
|---|---|
| `axolotl fetch examples` / `fetch deepspeed_configs` | Download example configs |
| `axolotl preprocess cfg.yaml [--debug]` | Tokenize to `dataset_prepared_path`; inspect labels |
| `axolotl train cfg.yaml` | Train (`--launcher torchrun -- --nproc_per_node=2` for multi-GPU; `--resume-from-checkpoint path`; `--sweep sweep.yaml`) |
| `axolotl evaluate cfg.yaml` | Loss on train/eval sets |
| `axolotl lm-eval cfg.yaml` | LM Evaluation Harness with `lm_eval_tasks` |
| `axolotl inference cfg.yaml --lora-model-dir DIR [--chat|--gradio]` | Try the model |
| `axolotl merge-lora cfg.yaml [--lora-model-dir DIR] [--dequant]` | Merge adapter into base; `CUDA_VISIBLE_DEVICES=""` merges on CPU |
| `axolotl merge-sharded-fsdp-weights cfg.yaml` | Combine FSDP shards |
| `axolotl quantize cfg.yaml` / `axolotl export cfg.yaml` | torchao quantization / GGUF export |
| `axolotl train cfg.yaml --cloud cloud.yaml` | Remote run on Modal/Baseten/Nebius (see `cloud-llms` for renting GPUs generally) |

Wrap long runs in a memory-capped scope and `tmux`/`systemd-run` so SSH drops don't kill them (see `hardware.md`).

## Tuning knobs worth knowing

- `adapter: lora|qlora`, `load_in_4bit`, `lora_r`, `lora_alpha`, `lora_dropout`, `lora_target_linear` / `lora_target_modules`, `peft_use_dora`, `peft_use_rslora`, `lora_rank_pattern` / `lora_alpha_pattern` (per-module overrides).
- `sequence_len`, `sample_packing`, `pad_to_sequence_len`, `excess_length_strategy` (`drop`|`truncate`|`raise`).
- `micro_batch_size`, `gradient_accumulation_steps`, `num_epochs` or `max_steps`, `learning_rate`, `lr_scheduler`, `warmup_ratio`, `optimizer` (default `adamw_torch_fused`; `adamw_bnb_8bit` saves memory).
- `gradient_checkpointing: true|offload|offload_disk`, `attn_implementation` (`sdpa`, `flash_attention_2`, ...; `flash_attention: true` is deprecated).
- `val_set_size` *or* `test_datasets` (not both), `evals_per_epoch` / `eval_steps`, `saves_per_epoch` / `save_steps`, `save_total_limit`.
- `rl: dpo|ipo|kto|orpo|simpo|grpo|...` for preference/RL; `trl:` block for GRPO/vLLM settings.
- `gpu_memory_limit`, `lora_on_cpu` (for merging huge models).

## Known pitfalls

- Legacy CLI (`python -m axolotl.cli.train`, `accelerate launch -m ...`) uses underscore overrides (`--lora_model_dir`); the current CLI uses dashes (`--lora-model-dir`).
- Template/data mismatch shows as `Could not find content __ boundary` warnings in preprocess.
- Changing `lora_rank_pattern` between runs breaks `resume_from_checkpoint` with shape mismatch.
- Merging a QLoRA run: default merge into a quantized base is format-preserving; use `--dequant` to get a bf16 checkpoint for GGUF conversion (export rejects pre-quantized checkpoints).
- GRPO with vLLM in server mode: vLLM must use the *last* N GPUs (TRL constraint); single GPU needs `vllm_mode: colocate`.
- Don't `pip install` llama.cpp's requirements into the Axolotl venv; they pin older `transformers` and CPU `torch`.

## Official links

- Repo: https://github.com/axolotl-ai-cloud/axolotl
- Docs: https://docs.axolotl.ai/
- Config reference: https://docs.axolotl.ai/docs/config-reference.html
- CLI: https://docs.axolotl.ai/docs/cli.html
- Docker images: https://docs.axolotl.ai/docs/docker.html , https://hub.docker.com/u/axolotlai
- Dataset formats: https://docs.axolotl.ai/docs/dataset-formats/
- RLHF: https://docs.axolotl.ai/docs/rlhf.html
- GGUF export: https://docs.axolotl.ai/docs/export.html
