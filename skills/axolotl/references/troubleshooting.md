# Axolotl troubleshooting

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/faq.qmd, docs/multi-gpu.qmd, docs/export.qmd, docs/vllm_serving.qmd on main), 2026-10-11

Match the error text, apply the fix, re-run `axolotl preprocess cfg.yml --debug` when the data path is involved.

## Process and memory

| Symptom                                                       | Cause and fix                                                                                    |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `exitcode: -9`                                                | Out of system RAM. Lower `micro_batch_size`, use a memory-capped scope, stop co-located servers. |
| `exitcode: -7` with DeepSpeed                                 | `pip install -U deepspeed`.                                                                      |
| Trainer stops, no progress for minutes                        | GPU-to-GPU communication; see https://docs.axolotl.ai/docs/nccl.html.                            |
| `AttributeError: 'DummyOptim' object has no attribute 'step'` | DeepSpeed optimizer config mismatch; check the `deepspeed:` JSON against your `optimizer`.       |
| `ModuleNotFoundError: No module named 'mpi4py'` on one GPU    | Remove the `deepspeed:` section or `--deepspeed` flag.                                           |
| Stuck while saving preprocessed datasets                      | `export CUDA_VISIBLE_DEVICES=0`; on RunPod, start a new pod.                                     |
| `Data processing error: CAS service error`                    | `export HF_HUB_DISABLE_XET=1`.                                                                   |
| `Backward pass should have cleared tracker of all tensors`    | Try `offload_activations: legacy`.                                                               |
| `NoValidChoicesError ... max_autotune_gemm_backends`          | Add `flex_attn_compile_kwargs: {dynamic: false, mode: max-autotune-no-cudagraphs}`.              |
| FA2 2.8.0 `undefined symbol` on CUDA 12.4                     | Use CUDA 12.6 or FA2 2.7.4 (upstream flash-attention issue 1717).                                |
| `memory/max_*` differs from `nvidia-smi`                      | Axolotl reports torch's allocator stats, not driver totals.                                      |
| vLLM not working                                              | Axolotl needs `vllm>=0.30.0` (pins torch 2.13.0).                                                |

## Tokenizer and data

| Symptom                                                                           | Cause and fix                                                                                                                                                                |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Asking to pad but the tokenizer does not have a padding token`                   | Set `special_tokens: {pad_token: "<token>"}` (the EOS token if unsure).                                                                                                      |
| `KeyError: 'input_ids'` or `IterableDataset error` in `preprocess`                | Dataset uses `pretraining_dataset:` or `skip_prepare_dataset: true`; run `axolotl train` directly.                                                                           |
| Vocab size mismatch merging or loading adapters                                   | Use `axolotl merge-lora`. Axolotl grows embeddings if the tokenizer is larger; it does not shrink them unless `shrink_embeddings: true`.                                     |
| `jinja2.exceptions.UndefinedError: ... no attribute 'content'/'role'`             | Missing `message_property_mappings` entry for that attribute.                                                                                                                |
| `Empty template generated for turn N`                                             | That turn's `content` is empty.                                                                                                                                              |
| `Could not find content start/end boundary for turn N`                            | Set `special_tokens.eos_token` to the template's EOS; check that the template has proper per-turn boundaries (system turns may not).                                         |
| EOS or EOT masked wrongly / `EOS token ... not found in chat template`            | `tokenizer.eos_token` differs from the template's EOS: set `special_tokens.eos_token` to match. Some templates (e.g. `phi_35`) never use the dedicated EOS.                  |
| `EOT token ... not found in chat template` / encoded as multiple tokens           | Set `eot_tokens:` to the template's end-of-turn token(s). Multi-token EOTs: add under `tokens:` or (recommended) override unused added tokens via `added_tokens_overrides:`. |
| `Conflict between train_on_eos and train_on_eot`                                  | EOS is in `eot_tokens` while the two settings differ; make them equal or drop the EOS from `eot_tokens`.                                                                     |
| `chat_template choice is tokenizer_default but tokenizer's chat_template is null` | Base model has no template; set a named `chat_template` or add one to the tokenizer config.                                                                                  |
| `Error parsing tool_calls arguments as JSON`                                      | Bad string arguments in the dataset's `tool_calls`; fix the rows.                                                                                                            |
| Model never stops generating                                                      | EOS not trained: `train_on_eos: turn`; mismatch between served and training EOT.                                                                                             |

## Resume, merge and export

- Changing `lora_rank_pattern` between runs breaks `resume_from_checkpoint` (shape mismatch).
- Legacy CLI overrides use underscores (`--lora_model_dir`); the Click CLI uses dashes (`--lora-model-dir`).
- `axolotl export` refuses adapter-only dirs and pre-quantized checkpoints; merge first, with `--dequant` for QLoRA (`references/export-merge.md`).
- Fine-tune "disappears" in the serving engine: template mismatch, adapter on the wrong base, or adapter not selected (skills `fine-tuning-llms`, `vllm`).

## GRPO

- Server mode: vLLM must serve the same base model; with several GPUs give vLLM the highest-index GPUs; colocate mode is the one-GPU route.
- OOM during scoring: reduce `micro_batch_size` or `num_generations`.
- `rewards/*/mean` stuck at 0: test the reward function alone; check dataset columns passed as kwargs.

More: https://docs.axolotl.ai/docs/faq.html, https://docs.axolotl.ai/docs/debugging.html, https://docs.axolotl.ai/docs/training_stability.html.
