# Training with LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## Stages and tuning types

`stage` is one of `pt` (pre-training), `sft`, `rm` (reward model), `ppo`, `dpo`, `kto` (from `finetuning_args.py`). `finetuning_type` is one of `lora`, `oft`, `freeze`, `full`. Upstream example YAMLs exist for LoRA pre-train, SFT, DPO (with `pref_loss` choices `sigmoid` = DPO, `orpo`, `simpo`), KTO, reward modeling, multimodal SFT and DPO, full SFT, and extras (GaLore, APOLLO, BAdam, Adam-mini, Muon, LoRA+, PiSSA, Mixture-of-Depths, LLaMA-Pro, FSDP+QLoRA, OFT, QOFT). Find them under `examples/` in your checkout (`train_lora`, `train_qlora`, `train_full`, `extras`).

Run the closest example first, then edit.

## LoRA keys

`lora_rank` (default 8), `lora_alpha`, `lora_dropout`, `lora_target` (`all` in the examples), `use_rslora`, `use_dora`, `loraplus_lr_ratio`, `pissa_init`. Preference keys: `pref_beta` (example 0.1), `pref_loss`, `pref_ftx`.

Smoke-test parameters from the SFT example: `per_device_train_batch_size: 1`, `gradient_accumulation_steps: 8`, `learning_rate: 1.0e-4`, `num_train_epochs: 3.0`, cosine schedule, `warmup_ratio: 0.1`, `bf16: true`, `cutoff_len: 2048`. DPO example uses `learning_rate: 5.0e-6`. Treat these as upstream demo values, not tuned recommendations.

## QLoRA

```yaml
quantization_bit: 4 # 8 (bnb/hqq/eetq), 4 (bnb/hqq), 3 or 2 (hqq)
quantization_method: bnb # bnb, hqq, eetq
```

This is the on-the-fly mode in `examples/train_qlora/qwen3_lora_sft_otfq.yaml`. Upstream also ships GPTQ, AWQ and AQLM pre-quantized examples. Hardware table in the README (estimates): 7B LoRA 16 GB, QLoRA 4-bit 6 GB, full bf16 60 GB (pure_bf16) up to 120 GB for mixed precision.

## Memory levers (in order)

1. `cutoff_len` down, `per_device_train_batch_size` down with `gradient_accumulation_steps` up.
2. `quantization_bit: 4` (QLoRA).
3. DeepSpeed ZeRO-2/3 with optional offload (`references/multi-gpu.md`).
4. Model-arg switches present in `model_args.py`: `flash_attn`, `enable_liger_kernel`, `use_unsloth`. Read the field help in your version before enabling; support depends on model and hardware.

## Evaluation and logging

Hold out data: `val_size: 0.1` (or `eval_dataset`), `eval_strategy: steps`, `eval_steps: 500`, `per_device_eval_batch_size: 1`. Logging: `report_to: none | wandb | tensorboard | swanlab | mlflow`, with `run_name`. For W&B export `WANDB_API_KEY` in the environment, never in the YAML.

Resume with `resume_from_checkpoint: <path>`; `overwrite_output_dir: true` in the examples will clobber an existing folder, so set it to `false` for real runs.

## Run

```bash
llamafactory-cli train mytrain.yaml
```

With more than one visible GPU this starts `torchrun` for you (`references/multi-gpu.md`). To use specific devices: `CUDA_VISIBLE_DEVICES=0 llamafactory-cli train mytrain.yaml`.

## After training

Check: adapter files in `output_dir`, loss plot (`plot_loss: true`), then `llamafactory-cli chat` with an inference YAML before merging (`references/export-and-serve.md`). For a reproducible record store the YAML and `llamafactory-cli env` output with the adapter.

For a batch evaluation with vLLM upstream provides `scripts/vllm_infer.py` and `scripts/eval_bleu_rouge.py`; for real model comparison use `llm-evals`.
