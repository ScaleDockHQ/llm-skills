# Configuration and data in LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## YAML anatomy

Every run is one YAML passed to a subcommand. Sections used by the upstream examples (`examples/train_lora/qwen3_lora_sft.yaml`): `model` (`model_name_or_path`, `trust_remote_code`), `method` (`stage`, `do_train`, `finetuning_type`, `lora_rank`, `lora_target`), `dataset` (`dataset`, `template`, `cutoff_len`, `max_samples`, workers), `output` (`output_dir`, `logging_steps`, `save_steps`, `plot_loss`, `report_to`), `train` (batch size, accumulation, `learning_rate`, `num_train_epochs`, scheduler, `warmup_ratio`, `bf16`, `ddp_timeout`, `resume_from_checkpoint`), `eval` (commented: `eval_dataset` or `val_size`, `eval_strategy`, `eval_steps`).

Override any key from the command line without editing the file:

```bash
CUDA_VISIBLE_DEVICES=0,1 llamafactory-cli train my.yaml learning_rate=1e-5 logging_steps=1
```

`CUDA_VISIBLE_DEVICES` (or `ASCEND_RT_VISIBLE_DEVICES` on NPU) selects devices. `llamafactory-cli help` lists subcommands.

## Choosing the template

`template` names the chat format (the examples use `qwen3_nothink` for Qwen3-4B-Instruct-2507). Use the template the model family expects and the same value for train, chat and export. The supported list is in `src/llamafactory/data/template.py` and the model list in `src/llamafactory/extras/constants.py`; read those in your checkout rather than guessing.

For reasoning models (Qwen3), upstream data docs say that when a dataset has no chain of thought, empty CoT is added automatically; with `enable_thinking: true` (default) it is added to the response and counted in the loss, otherwise it goes to the prompt and is ignored. Keep `enable_thinking` identical between training and inference. `enable_thinking: null` mixes both and is documented as complicated.

## Registering data

`data/dataset_info.json` (in `dataset_dir`, default `./data`) maps a dataset name to its source. Custom data must have an entry; the YAML's `dataset:` is only the key. File types: json, jsonl, csv, parquet, arrow. Sources: `hf_hub_url`, `ms_hub_url`, `script_url`, `cloud_file_name` (s3/gcs), or local `file_name`. Optional keys: `formatting` (`alpaca` default, or `sharegpt`), `ranking` (preference data), `subset`, `split`, `folder`, `num_samples`, `columns`, `tags`.

Several datasets: `dataset: identity,alpaca_en_demo` (comma list).

Alpaca SFT row: `instruction`, optional `input`, `output`, optional `system` and `history` (list of `[user, assistant]` pairs; history answers are also learned).

```json
"my_sft": {
  "file_name": "my_sft.jsonl",
  "columns": { "prompt": "instruction", "query": "input", "response": "output", "system": "system", "history": "history" }
}
```

ShareGPT-style rows use a `conversations` list with `from`/`value`; roles `human` and `observation` must sit in odd positions, `gpt` and `function_call` in even positions, and the latter are learned:

```json
"my_chat": {
  "file_name": "my_chat.json",
  "formatting": "sharegpt",
  "columns": { "messages": "conversations", "system": "system", "tools": "tools" }
}
```

Role tag names are changeable under `tags` (`role_tag`, `content_tag`, `user_tag`, `assistant_tag`, `observation_tag`, `function_tag`, `system_tag`), e.g. for OpenAI-style `role`/`content` data.

Preference data (DPO, ORPO, SimPO, reward modeling) needs `chosen` and `rejected` and `"ranking": true`; KTO uses a `kto_tag` column. Pre-training data uses a single `text` column mapped to `prompt`.

Template starter: `templates/dataset_info.custom.json`. Merge entries into the existing file; do not overwrite it.

## Validate before training

```bash
jq -e . data/dataset_info.json >/dev/null && echo "dataset_info.json parses"
jq -r 'keys[]' data/dataset_info.json | grep -x my_sft
head -c 600 data/my_sft.jsonl
```

For large corpora, `examples/train_lora/qwen3_preprocess.yaml` shows tokenizing once ahead of training; set `tokenized_path` in the training config to load the result.
