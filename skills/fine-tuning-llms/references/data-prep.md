# Data Preparation for Fine-Tuning

> Verified against Axolotl v0.20.0 (docs/dataset-formats, docs/dataset_loading.qmd, docs/rlhf.qmd) and TRL v1.15.0 (docs/source/dataset_formats.md), 2026-10-11

## What it is and when to choose it

Most failed fine-tunes are data problems: wrong chat template, unmasked user turns, duplicates, leaked eval rows, or noisy labels. Do this before choosing hyperparameters.

## Pick one canonical format: chat `messages` JSONL

Store training data as JSONL, one conversation per line, OpenAI-style:

<!-- prettier-ignore -->
```jsonl
{"messages": [{"role": "system", "content": "You are a support agent."}, {"role": "user", "content": "Reset my password"}, {"role": "assistant", "content": "Go to Settings > Security ..."}]}
```

Both Axolotl and TRL accept this directly, and it renders through the model's own chat template, so training and serving see identical prompts.

## Formats Axolotl accepts (`datasets[].type`)

| `type`          | Row shape                                                                                                           | Use for                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `chat_template` | `{"messages": [{role, content}, ...]}` (keys remappable via `field_messages`, `message_property_mappings`, `roles`) | SFT on chats (recommended)                      |
| `alpaca`        | `{"instruction", "input", "output"}`                                                                                | Single-turn instruction data                    |
| `completion`    | `{"text": ...}`                                                                                                     | Continued pretraining on raw text (no masking)  |
| `input_output`  | `{"segments": [{"text", "label": bool}, ...]}`                                                                      | Template-free, you control every token and mask |
| _(empty)_       | `input_ids`, `attention_mask`, `labels`                                                                             | Pre-tokenized data                              |
| custom dict     | `field_instruction`, `field_output`, `format`, `no_input_format`                                                    | Custom instruct formats                         |

Older ShareGPT data (`{"conversations": [{"from", "value"}]}`) works with `chat_template` by mapping keys: `field_messages: conversations`, `message_property_mappings: {role: from, content: value}`, and `roles` mapping `human`/`gpt` to `user`/`assistant`.

Preference types are per method (see `rlhf.qmd`): e.g. DPO `chat_template.default` (with `field_messages`, `field_chosen`, `field_rejected`), `chat_template.argilla_chat` (`chosen`/`rejected` message lists), `chatml.intel`, `llama3.*`; KTO has its own set.

Chat template choice: `chat_template: tokenizer_default` (use the model's template; default), a built-in name such as `chatml` or `llama3`, `tokenizer_default_fallback_chatml`, or `chat_template_jinja` for a custom template.

Masking: `roles_to_train: ["assistant"]` and `train_on_eos: turn` (values: `all`, `turn`, `last`, `none`) so only assistant tokens contribute loss.

Local files: `path: data/train.jsonl` with optional `ds_type: json` (CSV, JSON, Parquet, Arrow supported; inferred from extension).

## Formats TRL accepts

TRL distinguishes **format** (standard text vs conversational message lists) from **type**:

| Type                | Standard example                          | Conversational example                                    |
| ------------------- | ----------------------------------------- | --------------------------------------------------------- |
| Language modeling   | `{"text": ...}`                           | `{"messages": [...]}`                                     |
| Prompt-only         | `{"prompt": ...}`                         | `{"prompt": [{role, content}]}`                           |
| Prompt-completion   | `{"prompt", "completion"}`                | `{"prompt": [user msgs], "completion": [assistant msgs]}` |
| Preference          | `{"prompt", "chosen", "rejected"}`        | same keys with message lists                              |
| Unpaired preference | `{"prompt", "completion", "label": bool}` | same with message lists                                   |

Which trainer needs what (TRL docs): `SFTTrainer` language modeling or prompt-completion; `DPOTrainer` preference (explicit prompt recommended); `KTOTrainer` unpaired preference or preference; `GRPOTrainer` and `RLOOTrainer` prompt-only; `RewardTrainer` preference (implicit prompt recommended); `experimental.orpo.ORPOTrainer` preference.

## Cleaning checklist

- **Split first.** Hold out an eval set (typically 5-10%, at least a few hundred rows if you have them) _before_ dedup/augmentation decisions leak across the split. Split by source/user/document, not just by row, so near-duplicates don't straddle train and eval.
- **Dedup.** Exact dedup on normalized text (lowercase, collapse whitespace) with `jq`/`sort -u` on a canonical field; near-dup with MinHash tools if the data is scraped. Check eval-vs-train overlap explicitly.
- **PII scrub.** Remove or replace emails, phone numbers, addresses, account IDs, API keys and tokens before training; a model can memorize and regurgitate them. Use a dedicated PII tool (e.g. Microsoft Presidio) plus regexes for your own ID formats, then spot-check by hand.
- **Secrets.** Grep training data for key-like strings; never train on credentials.
- **Consistency.** One system prompt style, one answer style. Contradictory examples teach the model to be random.
- **Length.** Check token length distribution and decide what happens to rows beyond `sequence_len`. Axolotl's `excess_length_strategy` is `drop` (default), `truncate`, or `raise`; truncation can cut off the answer you wanted to teach.
- **Balance.** Over-represented intents dominate. Cap per-intent counts.
- **Synthetic data.** If generated by another model, check that provider's terms on training competing models with its outputs, and review a sample by hand.

Quick inspection commands (no Python):

```bash
wc -l data/train.jsonl data/eval.jsonl
jq -c 'select(.messages | length < 2)' data/train.jsonl | head        # malformed rows
jq -r '.messages[-1].role' data/train.jsonl | sort | uniq -c          # last turn should be assistant
jq -r '.messages | map(.content) | join(" ")' data/train.jsonl | sort | uniq -d | head   # exact dups
```

## Verify the rendered prompt and masks

Always look at tokenized output before a long run:

```bash
axolotl preprocess config.yaml --debug --debug-num-examples 3
```

The debug output shows `(label, token_id)` pairs; masked tokens have label `-100`. User/system tokens must be `-100`, assistant tokens must not. Warnings like `Could not find content __ boundary` mean the template and data disagree.

## Known pitfalls

- Training with one chat template and serving with another: the model "forgets" its fine-tune. Save the template with the model (Axolotl writes the chosen template into `tokenizer_config.json`) and check the served template.
- Missing EOS on assistant turns: model never stops generating. Set `train_on_eos` and check EOS/EOT tokens (`special_tokens`).
- Roles hardcoded by some templates (e.g. only `user`/`assistant`): map extra roles or fold system text into the first user turn.
- Eval rows that also appear in train: inflated scores.

## Official links

- Axolotl dataset formats: https://docs.axolotl.ai/docs/dataset-formats/
- Axolotl dataset loading: https://docs.axolotl.ai/docs/dataset_loading.html
- Axolotl RLHF dataset types: https://docs.axolotl.ai/docs/rlhf.html
- TRL dataset formats: https://huggingface.co/docs/trl/dataset_formats
- Microsoft Presidio (PII): https://github.com/microsoft/presidio
