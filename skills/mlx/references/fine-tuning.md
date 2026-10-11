# Fine-tune with `mlx_lm.lora` and fuse adapters

> Verified against mlx-lm 0.32.0 (mlx_lm/LORA.md, lora.py CONFIG_DEFAULTS, fuse.py on main), 2026-10-11

## What it does

`mlx_lm.lora` trains LoRA, DoRA or full-weight fine-tunes on Apple Silicon. If `--model` is a quantized MLX model, training is QLoRA; otherwise regular LoRA. Training strategy, data quality and evaluation design belong to the `fine-tuning-llms` skill; this file is the MLX mechanics.

## Setup

```bash
pip install "mlx-lm[train]"          # datasets and tqdm
mlx_lm.lora --help
```

LORA.md lists tested families (Mistral, Llama, Phi2, Mixtral, Qwen2, Gemma, OLMo, MiniCPM, InternLM2). That list may lag the code (unverified): check that the target model loads in `mlx_lm.generate` first and try a short run.

## Data

Put `train.jsonl` (required for `--train`), optional `valid.jsonl` (validation loss) and `test.jsonl` (for `--test`) in one directory, one JSON object per line. Formats are detected automatically:

```jsonl
{"messages": [{"role": "system", "content": "You are helpful."}, {"role": "user", "content": "Hello."}, {"role": "assistant", "content": "Hi, how can I help?"}]}
{"prompt": "What is the capital of France?", "completion": "Paris."}
{"text": "Free-form text the model should learn."}
```

`chat`, `completions`, `text` and `tools` (chat plus a `tools` array of function schemas and `tool_calls`) are supported. The model's chat template is applied for chat, tools and completions; the `arguments` field format for tool calls varies by model, so check its template. Use `--mask-prompt` to compute loss only on the completion (the final message for chat data). `--data` also accepts a Hugging Face dataset id (for example `mlx-community/wikisql`) or a YAML `hf_dataset` mapping (`prompt_feature`, `completion_feature`, `text_feature`, `chat_feature`, `{train,valid,test}_split`). Do not put real personal or secret data in a dataset you will upload.

## Train, evaluate, generate

```bash
mlx_lm.lora --model mlx-community/Llama-3.2-3B-Instruct-4bit --train --data ./data \
  --iters 600 --batch-size 2 --num-layers 8 --adapter-path ./adapters
mlx_lm.lora --model <same model> --adapter-path ./adapters --data ./data --test      # test perplexity
mlx_lm.generate --model <same model> --adapter-path ./adapters --prompt "..."
mlx_lm.lora --config ./lora.yaml                                                      # YAML config; CLI flags override it
```

Defaults from `CONFIG_DEFAULTS`: `fine_tune_type` `lora` (also `dora`, `full`), `optimizer` `adam` (also `adamw`, `muon`, `sgd`, `adafactor`), `num_layers` 16, `batch_size` 4, `iters` 1000, `learning_rate` 1e-5, `max_seq_length` 2048, `val_batches` 25, `steps_per_report` 10, `steps_per_eval` 200, `save_every` 100, `adapter_path` `adapters`, `grad_accumulation_steps` 1, `lora_parameters` rank 8, dropout 0.0, scale 20.0. Resume with `--resume-adapter-file <adapters.safetensors>`. Log to Weights & Biases or SwanLab with `--report-to wandb` (or `swanlab`, comma-separated) and `--project-name`. The `model` default in `lora.py` is a tiny Qwen3 model, so always pass `--model`.

## Reduce memory (upstream tips)

1. QLoRA: train on a quantized model.
2. `--batch-size 1` or `2`; raise `--grad-accumulation-steps` to keep the effective batch.
3. Fewer layers: `--num-layers 8` or `4` (can cost quality on big datasets).
4. Shorter examples (split long ones); lower `--max-seq-length`.
5. `--grad-checkpoint` trades compute for memory.

Upstream's example for a 32 GB machine: Mistral-7B with `--batch-size 1 --num-layers 4` runs about 250 tokens per second on an M1 Max. Watch `memory_pressure` and swap while training; a training job that swaps will crawl (`apple-silicon.md`).

## Fuse

```bash
mlx_lm.fuse --model <base model> --adapter-path ./adapters --save-path ./fused_model
mlx_lm.fuse --model <base model> --adapter-path ./adapters --dequantize          # fuse into a dequantized model
mlx_lm.fuse --model <base> --upload-repo <org>/<name> --hf-path <base repo>      # asks for approval first: uploads
```

Defaults: `--model mlx_model`, `--save-path fused_model`, `--adapter-path adapters`. GGUF export is limited: see `combos/lora-to-gguf.md`.

## Serve an adapter without fusing

`mlx_lm.server --model <base> --adapter-path ./adapters`, or send `"adapters": "<relative path>"` in a request (paths are relative to the server's start directory). Server details: `serving.md`.

## Official links

- LORA.md: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md
- lora.py: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/lora.py
- fuse.py: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/fuse.py
- Example YAML config: https://github.com/ml-explore/mlx-lm/blob/main/examples/lora_config.yaml
