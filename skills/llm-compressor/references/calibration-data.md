# Calibration data

> Verified against llm-compressor 0.14.0 (docs/steps/choosing-dataset.md, docs/guides/entrypoints/oneshot.md, examples/custom_dataset_example.py, src/llmcompressor/transformers/data/*.py, docs/guides/big_models_and_distributed/distributed_oneshot.md), 2026-10-11

## When data is needed

From upstream's dataset guide:

- Algorithms that need a dataset: GPTQ, AWQ, AutoRound, SmoothQuant (and REAP pruning).
- Schemes that need a dataset even with RTN: NVFP4 (calibrates activation global scales) and static per-tensor activation quantization (FP8 or INT8 with a single scale, and FP8 KV cache scales).
- Data-free: RTN with `FP8_DYNAMIC`, `FP8_BLOCK`, `MXFP4`, `MXFP8`, and weight-only schemes such as `NVFP4A16`.

Calibration-based methods usually recover more accuracy, especially at low bit widths.

## Built-in dataset names

Pass the name as `dataset="..."` (registered in `src/llmcompressor/transformers/data/` at 0.14.0):

| Name                   | Aliases       | Notes                                                       |
| ---------------------- | ------------- | ----------------------------------------------------------- |
| `perfectblend`         |               | Used by most upstream LLM examples (`splits="train[:512]"`) |
| `ultrachat_200k`       | `ultrachat`   | Chat data; upstream docs also write `ultrachat-200k`        |
| `open_platypus`        |               | Instruction data                                            |
| `wikitext`             |               | Plain text                                                  |
| `c4`                   |               | Web text                                                    |
| `cnn_dailymail`        |               | News summaries                                              |
| `evolcodealpaca`       |               | Code instructions                                           |
| `gsm8k`                |               | Grade-school maths                                          |
| `flickr` / `flickr30k` |               | Image-text, for vision-language models                      |
| `peoples_speech`       |               | Audio, for audio-language models                            |
| `custom`               | `json`, `csv` | Local files via `dataset_path=`                             |

Upstream's doc page uses the hyphenated spelling `ultrachat-200k` while the code registers `ultrachat_200k`; use the underscore form from the code. (unverified) whether the registry also normalises hyphens.

You can also pass a Hugging Face dataset id such as `HuggingFaceH4/ultrachat_200k`, a loaded `Dataset` / `DatasetDict`, or a PyTorch `DataLoader`.

## How much and how long

`oneshot` defaults (from the entrypoint docs): `num_calibration_samples=512`, `max_seq_length=384`, `batch_size=1`, `shuffle_calibration_samples=True`, `text_column="text"`, `concatenate_data=False`.

Upstream guidance: 128 to 512 samples is enough for most models, start with 128 to 256 and increase if accuracy recovery is poor. The examples set `max_seq_length=2048` for GPTQ and NVFP4, `512` for AWQ. Longer sequences and more samples cost time and memory. Upstream's NVFP4 example uses only 20 samples because only activation global scales need data.

## Choose data that looks like the workload

- Chat or instruct models: calibrate on chat-formatted text (apply the model's chat template), not raw prose.
- Coding models: include code. Domain models: sample real prompts and responses (scrubbed of secrets and personal data).
- Reasoning models: include long, reasoning-style samples with a longer `max_seq_length`.
- Do not calibrate on your evaluation set; record the dataset id, split, sample count, sequence length and seed in the model card.

## Custom dataset (from upstream's example)

```python
from datasets import load_dataset

DATASET_ID = "HuggingFaceH4/ultrachat_200k"
DATASET_SPLIT = "train_sft"
NUM_CALIBRATION_SAMPLES = 512
MAX_SEQUENCE_LENGTH = 2048

ds = load_dataset(DATASET_ID, split=f"{DATASET_SPLIT}[:{NUM_CALIBRATION_SAMPLES}]")
ds = ds.shuffle(seed=42)

def preprocess(example):
    return {"text": tokenizer.apply_chat_template(example["messages"], tokenize=False)}

ds = ds.map(preprocess)

def tokenize(sample):
    return tokenizer(sample["text"], padding=False, max_length=MAX_SEQUENCE_LENGTH,
                     truncation=True, add_special_tokens=False)

ds = ds.map(tokenize, remove_columns=ds.column_names)

oneshot(model=model, dataset=ds, recipe=recipe,
        max_seq_length=MAX_SEQUENCE_LENGTH, num_calibration_samples=NUM_CALIBRATION_SAMPLES)
```

For files on disk, use `dataset_path=` with JSON or CSV and set `text_column` to the column holding the text.

## Distributed runs

Under `torchrun`, each rank should see a disjoint slice. Use `get_rank_partition` from `llmcompressor.datasets.utils` in the `split=` string, or pass a `Dataset` object (the sampler detects identical datasets across ranks and partitions them). See `big-models.md`.

## MoE models

`moe_calibrate_all_experts=True` (default) routes every calibration token through all experts so rarely-routed experts still get statistics. `min_tokens_per_module` logs a warning when a module receives too few tokens. Use more or longer samples when the warning fires.
