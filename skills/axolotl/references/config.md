# Axolotl configuration and CLI

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/cli.qmd, docs/getting-started.qmd, docs/faq.qmd, config reference, examples/llama-3), 2026-10-11

One YAML file drives every command: `preprocess`, `train`, `evaluate`, `inference`, `merge-lora`, `export`. The config can be a local path or a URL to raw YAML. Full key list: https://docs.axolotl.ai/docs/config-reference.html. Starters: `templates/lora-sft.yaml` (SFT), `templates/grpo-colocate.yaml` (RL).

## Commands

```bash
axolotl <command> [config.yml] [options]
```

| Command                                                                                   | Purpose                                                                                                                                         |
| ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `axolotl fetch examples` / `fetch deepspeed_configs` (`--dest DIR`)                       | Download example and DeepSpeed configs                                                                                                          |
| `axolotl preprocess cfg.yml [--debug] [--debug-num-examples N]`                           | Tokenize into `dataset_prepared_path`; `--debug` prints tokens with labels                                                                      |
| `axolotl train cfg.yml`                                                                   | Train. `--resume-from-checkpoint DIR`, `--launcher python\|torchrun\|accelerate -- <launcher args>`, `--sweep sweep.yaml`, `--cloud cloud.yaml` |
| `axolotl evaluate cfg.yml`                                                                | Loss on train/eval sets                                                                                                                         |
| `axolotl lm-eval cfg.yml`                                                                 | LM Evaluation Harness; keys `lm_eval_model`, `lm_eval_tasks`, `lm_eval_batch_size`, `output_dir`                                                |
| `axolotl inference cfg.yml [--lora-model-dir DIR] [--base-model DIR] [--chat] [--gradio]` | Try the model; stdin works (`cat prompt.txt \| axolotl inference ...`)                                                                          |
| `axolotl merge-lora cfg.yml [--lora-model-dir DIR] [--dequant]`                           | Merge adapter (`references/export-merge.md`)                                                                                                    |
| `axolotl merge-sharded-fsdp-weights cfg.yml`                                              | Combine FSDP shards                                                                                                                             |
| `axolotl quantize cfg.yml`                                                                | torchao quantization from the config's quantization settings                                                                                    |
| `axolotl export cfg.yml --quantize Q4_K_M`                                                | GGUF export (`references/export-merge.md`)                                                                                                      |
| `axolotl vllm-serve cfg.yml`                                                              | vLLM generation server for GRPO (`references/rl-and-grpo.md`)                                                                                   |
| `axolotl delinearize-llama4 IN OUT`                                                       | Convert a linearized Llama 4 to a regular HF model                                                                                              |

Any config key is a dash-form flag: `axolotl train cfg.yml --learning-rate 1e-4 --micro-batch-size 2 --num-epochs 3`. The legacy module CLI (`python -m axolotl.cli.train`, `accelerate launch -m axolotl.cli.train`) uses underscores (`--lora_model_dir`).

Sweeps: a YAML with `_:` (list of dependent variable sets), then independent lists such as `learning_rate: [0.0003, 0.0006]`, `lora_r: [16, 32]`, run via `axolotl train cfg.yml --sweep sweep.yaml`.

## Key groups

| Group   | Keys                                                                                                                                                                                                                                               |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Model   | `base_model`, `load_in_8bit`, `load_in_4bit`, `chat_template` (`tokenizer_default` = the tokenizer's own template, or a named template such as `llama3`), `special_tokens` (e.g. `pad_token`)                                                      |
| Adapter | `adapter: lora\|qlora`, `lora_r`, `lora_alpha`, `lora_dropout`, `lora_target_linear` or `lora_target_modules`, `lora_model_dir`, `peft_use_dora`, `peft_use_rslora`, `lora_rank_pattern` / `lora_alpha_pattern`, `lora_on_cpu`, `gpu_memory_limit` |
| Data    | `datasets:` (`path`, `type`, `ds_type`, `split`, `field_messages`, `roles_to_train`, `train_on_eos`), `test_datasets:` or `val_set_size` (not both), `dataset_prepared_path`, `skip_prepare_dataset`                                               |
| Length  | `sequence_len`, `sample_packing`, `pad_to_sequence_len`, `excess_length_strategy` (`drop`, `truncate`, `raise`)                                                                                                                                    |
| Optim   | `micro_batch_size`, `gradient_accumulation_steps`, `num_epochs` or `max_steps`, `learning_rate`, `lr_scheduler`, `warmup_ratio`, `optimizer` (default `adamw_torch_fused`; `adamw_bnb_8bit` saves memory), `weight_decay`                          |
| Memory  | `gradient_checkpointing: true\|offload\|offload_disk`, `attn_implementation` (`sdpa`, `flash_attention_2`; `flash_attention: true` is deprecated), `bf16: auto`, `tf32`                                                                            |
| Run     | `output_dir`, `logging_steps`, `evals_per_epoch` / `eval_steps`, `saves_per_epoch` / `save_steps`, `save_total_limit`, `resume_from_checkpoint`, `seed`, `hub_model_id`                                                                            |
| RL      | `rl: dpo\|ipo\|kto\|orpo\|simpo\|grpo\|...`, `trl:` block, `vllm:` block                                                                                                                                                                           |

Effective batch = `micro_batch_size` x `gradient_accumulation_steps` x number of GPUs. `adapter: lora` with `load_in_8bit: true` is LoRA on 8-bit weights; both quant flags false is bf16 LoRA; `load_in_4bit: true` + `adapter: qlora` is QLoRA; remove adapter and quant lines for full fine-tuning.

## Dataset types

- `type: chat_template`: JSONL rows with a message list (`field_messages: messages` by default OpenAI-style). `roles_to_train: ["assistant"]` masks system/user tokens. `train_on_eos: turn` trains the EOS that ends each trainable turn so the model learns to stop. Custom role/content keys go through `message_property_mappings`.
- `type: alpaca`: `instruction` / `input` / `output` rows (used by upstream getting-started).
- Preference formats for `rl: dpo|kto`: `chatml.intel`, `chatml.argilla`, `chatml.prompt_pairs`, `chatml.ultra`, `llama3.*` and more (`references/rl-and-grpo.md`). Full lists: https://docs.axolotl.ai/docs/dataset-formats/.
- Local files: set `ds_type: json` for JSONL; HF Hub, Parquet, CSV, Arrow, `s3://` and `gs://` paths are also accepted.
- `pretraining_dataset:` and `skip_prepare_dataset: true` datasets are prepared on demand; `axolotl preprocess` does not work with them (use `axolotl train`).

## Masking checks

`axolotl preprocess cfg.yml --debug --debug-num-examples 3` prints each token with its label. System/user tokens should show `-100`; assistant tokens and the closing EOS/EOT should be labeled. Warnings such as `Could not find content start/end boundary for turn` mean the template's turn boundaries were not detected: set `special_tokens.eos_token` to the template's EOS, and `eot_tokens` if the end-of-turn token differs (`references/troubleshooting.md`).

Train and serve with the same template. If the base tokenizer has none (`chat_template` is null) `tokenizer_default` fails; set a named template or add one to the tokenizer config.
