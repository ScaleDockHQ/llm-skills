# Convert and quantize with `mlx_lm.convert`

> Verified against mlx-lm 0.32.0 (mlx_lm/convert.py, mlx_lm/utils.py, pyproject.toml entry points) and README on main, 2026-10-11

The v0.31.3 tag had the same convert flags.

## What it does

Converts Hugging Face weights into an MLX directory (`config.json` with a `quantization` block, safetensors, tokenizer files) and optionally quantizes in the same step. Choose it when the target runs on Apple Silicon: `mlx_lm.server`, LM Studio's MLX engine or other MLX apps. For GGUF (llama.cpp, Ollama) use the `model-quantization` skill instead. Cross-engine quant choice also lives there.

## Commands

```bash
# 4-bit affine (defaults: group size 64, 4 bits)
mlx_lm.convert --hf-path <org>/<model> --mlx-path ~/models/<model>-mlx-4bit -q

# explicit bits and group size
mlx_lm.convert --hf-path ~/models/<model> --mlx-path ~/models/<model>-mlx-6bit -q --q-bits 6 --q-group-size 64

# mixed-bit recipe (affine only)
mlx_lm.convert --hf-path ~/models/<model> --mlx-path ~/models/<model>-mlx-mixed_4_6 -q --quant-predicate mixed_4_6

# floating-point microscaling formats
mlx_lm.convert --hf-path <org>/<model> --mlx-path ~/models/<model>-mxfp4 -q --q-mode mxfp4

# convert only, change dtype
mlx_lm.convert --hf-path <org>/<model> --mlx-path ~/models/<model>-bf16 --dtype bfloat16
```

## Flags

| Flag                         | Meaning                                                                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `--hf-path` / `--model`      | Hub id or local path                                                                                                         |
| `--mlx-path`                 | Output directory, default `mlx_model`. **Must not exist**: convert raises "Cannot save to the path ... as it already exists" |
| `-q` / `--quantize`          | Quantize                                                                                                                     |
| `--q-bits`, `--q-group-size` | Bits per weight, group size                                                                                                  |
| `--q-mode`                   | `affine` (default), `mxfp4`, `nvfp4`, `mxfp8`                                                                                |
| `--quant-predicate`          | `mixed_2_6`, `mixed_3_4`, `mixed_3_6`, `mixed_4_6` (affine only)                                                             |
| `--dtype`                    | `float16`, `bfloat16`, `float32` for non-quantized tensors                                                                   |
| `--upload-repo`              | Upload the result to a Hub repo                                                                                              |
| `-d` / `--dequantize`        | Dequantize a quantized model                                                                                                 |
| `--trust-remote-code`        | Custom tokenizers; only for repos you trust                                                                                  |

Defaults per mode when bits and group size are not given: affine 4-bit/64; mxfp4 4-bit/32; nvfp4 4-bit/16; mxfp8 8-bit/32 (consistent with the mode inference table in `utils.py`).

Python API: `from mlx_lm import convert; convert("<repo>", quantize=True, upload_repo="<org>/<name>")`. It saves to `mlx_model` by default.

## Calibrated and advanced quantizers

mlx-lm installs separate entry points: `mlx_lm.awq`, `mlx_lm.gptq`, `mlx_lm.dwq` (distilled weight quantization) and `mlx_lm.dynamic_quant`. Read `<command> --help` before use; their flags were not enumerated here (unverified).

## Quality and size check

```bash
mlx_lm.perplexity --model ~/models/<model>-mlx-4bit --sequence-length 512 --num-samples 64 --seed 123
mlx_lm.perplexity --model <base-or-8bit-dir>       --sequence-length 512 --num-samples 64 --seed 123
du -sh ~/models/<model>-mlx-4bit
```

`mlx_lm.perplexity` flags: `--model`, `--batch-size` (8), `--sequence-length`, `--num-samples`, `--data-path`, `--seed` (123), `--trust-remote-code`. Compare the quant to a higher-precision reference with identical settings. `mlx_lm.evaluate` runs lm-eval tasks (needs `pip install "mlx-lm[evaluate]"`).

## Publish

`--upload-repo` uses your local Hugging Face login or `HF_TOKEN`. Per the earlier model-quantization verification it creates the repo with default visibility if it does not exist and writes a short "converted with mlx-lm" card. To review first, convert without `--upload-repo`, create the repo private (`hf repos create <org>/<repo> --private`), write the card, then upload with `mlx_lm.upload --path <dir> --upload-repo <org>/<repo>` or `hf upload`. Name repos with bit width and `mlx` (for example `<model>-4bit-mlx`) and record the mlx-lm version and flags in the card. Ask before uploading anything. The `mlx-my-repo` Space (https://huggingface.co/spaces/mlx-community/mlx-my-repo) converts in the browser.

## Pitfalls

- Convert with big apps closed; macOS has no cgroup memory cap, so a large model can push the Mac into swap (`apple-silicon.md`).
- Unsupported architectures fail at load; the model code has to exist in mlx-lm (`mlx_lm/models`). Vision models use `mlx_vlm.convert` (`vision.md`).
- 8-bit is close to lossless, 4-bit is the common default, `mixed_*` recipes give some layers more bits, group size 32 raises quality slightly at a size cost (affine).

## Official links

- mlx-lm: https://github.com/ml-explore/mlx-lm
- convert.py: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/convert.py
- MLX on the Hub: https://huggingface.co/docs/hub/mlx
