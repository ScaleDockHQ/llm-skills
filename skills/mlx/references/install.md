# Install MLX, mlx-lm and mlx-vlm

> Verified against mlx 0.32.3, mlx-lm 0.32.0 (PyPI; GitHub tag v0.32.0), mlx-vlm 0.7.6, 2026-10-11

## What gets installed

| Package   | Provides                                                                | Python (PyPI `requires_python`) | License / upstream                |
| --------- | ----------------------------------------------------------------------- | ------------------------------- | --------------------------------- |
| `mlx`     | Array framework (pulled in by the others)                               | >= 3.10                         | MIT, github.com/ml-explore/mlx    |
| `mlx-lm`  | Text LLMs: generate, chat, server, convert, LoRA, perplexity, benchmark | >= 3.11                         | MIT, github.com/ml-explore/mlx-lm |
| `mlx-vlm` | Vision, audio and omni models: generate, server, convert, chat UI, LoRA | >= 3.10                         | MIT, github.com/Blaizzy/mlx-vlm   |

All three repos were active on 2026-10-11 (last pushes within two days; none archived). mlx-lm's `mlx>=0.32.2` dependency is installed on macOS automatically.

## Requirements (MLX install docs)

- macOS >= 14.0 on Apple Silicon, **native arm64 Python** (not Rosetta). A non-native Python is the usual cause of MLX import or install failures.
- Linux is supported by MLX itself through `mlx[cuda12]`, `mlx[cuda13]` or `mlx[cpu]` (glibc >= 2.35; CUDA toolkit >= 12.0, CUDA 13 needs driver >= 580). mlx-lm and mlx-vlm expose matching `cuda12`, `cuda13` and `cpu` extras. Server and training behaviour on those backends was **not verified** here; this skill targets Apple Silicon.

## Install (macOS)

```bash
python3 -m venv ~/.venvs/mlx && . ~/.venvs/mlx/bin/activate
python -c 'import platform; print(platform.machine())'      # must print arm64
pip install -U pip
pip install mlx-lm                    # or: conda install -c conda-forge mlx-lm
pip install "mlx-lm[train]"           # adds datasets and tqdm for mlx_lm.lora
pip install -U mlx-vlm                # vision/audio models; quote extras in zsh:
pip install -U 'mlx-vlm[ui]'          # Gradio chat UI
pip install -U 'mlx-vlm[train]'       # mlx-vlm LoRA training extra
```

Pin versions in scripts: `pip install 'mlx-lm==0.32.0' 'mlx-vlm==0.7.6'`. Use a separate venv per project so a new `transformers` requirement (mlx-lm needs `>=5.7.0`, mlx-vlm `>=5.14.0` at these versions) does not break other tools.

## Verify

```bash
command -v mlx_lm.generate mlx_lm.server mlx_lm.convert mlx_lm.lora mlx_lm.fuse mlx_vlm.generate
python -m mlx --version && python -m mlx_lm --version      # upstream's documented version command
mlx_lm.generate --model mlx-community/Llama-3.2-3B-Instruct-4bit --prompt "Say hi" --max-tokens 32
```

The first run downloads the model to the Hugging Face cache (`~/.cache/huggingface/hub`, or `HF_HOME`). Ask before pulling multi-gigabyte repos.

## Models

Thousands of ready-made conversions live in the `mlx-community` organization on Hugging Face (https://huggingface.co/mlx-community). Not every architecture is supported: if load fails with an unknown model type, check `mlx_lm/models` upstream, upgrade (`updating.md`), or file an issue. Some tokenizers need `--trust-remote-code` (mlx-lm prompts in the terminal if you omit it). Only use it for repos you trust.

## Hugging Face access

Gated or private repos need a login: `hf auth login` (huggingface_hub CLI) or `HF_TOKEN` in the environment. Never print the token. See the `hugging-face` skill.

## Official links

- mlx-lm: https://github.com/ml-explore/mlx-lm
- MLX install: https://ml-explore.github.io/mlx/build/html/install.html
- mlx-vlm: https://github.com/Blaizzy/mlx-vlm
- PyPI: https://pypi.org/project/mlx-lm/, https://pypi.org/project/mlx-vlm/, https://pypi.org/project/mlx/
