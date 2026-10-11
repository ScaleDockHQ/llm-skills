# MLX quantization with mlx-lm

> Verified against ml-explore/mlx-lm v0.31.3 (mlx_lm/convert.py, mlx_lm/utils.py, mlx_lm/server.py, mlx_lm/SERVER.md, setup.py); v0.32.0 tag has the same convert flags, 2026-10-11

## What it is and when to choose it

[mlx-lm](https://github.com/ml-explore/mlx-lm) converts Hugging Face models to Apple [MLX](https://github.com/ml-explore/mlx) format and quantizes them in the same step. Choose it when the target runs on Apple Silicon: `mlx_lm.server`, LM Studio's MLX engine, or other MLX apps. Quantized MLX models load fast and use unified memory efficiently on M-series Macs.

Not for: NVIDIA/CUDA engines. For llama.cpp / Ollama on a Mac, produce GGUF instead (`gguf.md`).

## Install

macOS on Apple Silicon:

```bash
python3 -m venv ~/venvs/mlx && . ~/venvs/mlx/bin/activate
pip install mlx-lm
command -v mlx_lm.convert mlx_lm.server mlx_lm.perplexity
```

## Minimal working config/command

```bash
# 4-bit affine (defaults: group size 64, 4 bits)
mlx_lm.convert --hf-path <org>/<model> --mlx-path ~/models/<model>-mlx-4bit -q

# explicit bits / group size
mlx_lm.convert --hf-path ~/models/<model> --mlx-path ~/models/<model>-mlx-6bit -q --q-bits 6 --q-group-size 64

# mixed-bit recipe
mlx_lm.convert --hf-path ~/models/<model> --mlx-path ~/models/<model>-mlx-mixed_4_6 -q --quant-predicate mixed_4_6

# convert + upload in one go (needs HF auth; creates a public repo if missing)
mlx_lm.convert --hf-path ~/models/<model> -q --upload-repo <org>/<model>-4bit-mlx
```

### mlx_lm.convert flags

| Flag                    | Meaning                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `--hf-path` / `--model` | Local path or Hub id                                                               |
| `--mlx-path`            | Output dir (default `mlx_model`); must not already exist                           |
| `-q` / `--quantize`     | Quantize                                                                           |
| `--q-bits`              | Bits per weight                                                                    |
| `--q-group-size`        | Group size                                                                         |
| `--q-mode`              | `affine` (default), `mxfp4`, `nvfp4`, `mxfp8`                                      |
| `--quant-predicate`     | Mixed-bit recipe: `mixed_2_6`, `mixed_3_4`, `mixed_3_6`, `mixed_4_6` (affine only) |
| `--dtype`               | Dtype for non-quantized params: `float16`, `bfloat16`, `float32`                   |
| `--upload-repo`         | Upload the result to this Hub repo                                                 |
| `-d` / `--dequantize`   | Dequantize a quantized model                                                       |
| `--trust-remote-code`   | For custom tokenizers                                                              |

Defaults per `--q-mode` when bits / group size are not given: affine 4-bit / group 64, mxfp4 4 / 32, nvfp4 4 / 16, mxfp8 8 / 32.

Calibrated alternatives ship as separate entry points: `mlx_lm.awq`, `mlx_lm.gptq`, `mlx_lm.dwq` (distilled weight quantization) and `mlx_lm.dynamic_quant`. Check `<command> --help` for their flags before use.

## How it plugs into the stack

- In: HF safetensors. Out: MLX directory (`config.json` with a `quantization` block, safetensors, tokenizer).
- Serve: `mlx_lm.server --model ~/models/<model>-mlx-4bit --host 127.0.0.1 --port 8080` (defaults are 127.0.0.1:8080). OpenAI-compatible `POST /v1/chat/completions` and `GET /v1/models`. Upstream says the server is not recommended for production (basic security checks only).
- LM Studio on a Mac can load MLX directories (`local-llms` skill).

## Operating

- macOS has no systemd/cgroup memory cap; see `memory-safety.md` for what to do instead. Convert with other large apps closed and check memory pressure.
- Quality check: `mlx_lm.perplexity --model <dir>` on both the base (or 8-bit) and the quant with the same `--data-path`, `--sequence-length`, `--num-samples` and `--seed` (`quality-checks.md`).
- Name repos with the bit width and `mlx` (for example `<model>-4bit-mlx`) and record mlx-lm version and flags in the card.

## Tuning knobs worth knowing

- `--q-bits 8` is close to lossless; 4-bit is the common default; `mixed_*` recipes give some layers more bits.
- `--q-group-size 32` raises quality slightly at a size cost (affine).
- `--dtype bfloat16` keeps non-quantized tensors in BF16 if the base used it.

## Known pitfalls

- `--mlx-path` must not exist; convert refuses to overwrite.
- Quant predicates only support `affine` mode.
- `--upload-repo` uses your local HF login or `$HF_TOKEN`, creates the repo with default visibility (public) if it does not exist, and replaces the card body with a short "converted with mlx-lm" text (metadata keeps `base_model`, `library_name: mlx`, tag `mlx`). To review first, convert without `--upload-repo`, create the repo private (`hf repos create <org>/<repo> --private`), write the card, then upload (`publishing.md`).
- Architectures need MLX model code in mlx-lm; unsupported ones fail at load.

## Official links

- mlx-lm: https://github.com/ml-explore/mlx-lm
- Server docs: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
- MLX on the Hub: https://huggingface.co/docs/hub/mlx
- mlx-my-repo Space: https://huggingface.co/spaces/mlx-community/mlx-my-repo
