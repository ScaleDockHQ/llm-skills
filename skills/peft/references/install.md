# Installing PEFT

> Verified against PEFT v0.21.2, 2026-10-11

## What it is and status

[PEFT](https://github.com/huggingface/peft) (Apache-2.0) is Hugging Face's parameter-efficient fine-tuning library. Actively maintained: v0.21.2 released 2026-10-01, last push 2026-10-09. `setup.py` at v0.21.2 requires Python >= 3.10 (the install page still says "tested on Python 3.9+"; trust `setup.py`). Core dependencies: `torch>=1.13.0`, `transformers`, `accelerate>=0.21.0`, `safetensors`, `huggingface_hub>=0.25.0`.

## Install

```bash
uv venv && source .venv/bin/activate
uv pip install peft                  # or: pip install peft
uv pip install accelerate bitsandbytes   # multi-GPU launcher and 4/8-bit QLoRA
python -c 'import peft; print(peft.__version__)'
```

Install a CUDA PyTorch build first when your platform needs a specific index. On Windows Arm64 with NVIDIA GPUs the install page says to take PyTorch from the NVIDIA PyPI index (`https://pypi.nvidia.com/nvtorch_oot_nightly`) before `pip install peft`.

Source installs for unreleased features: `pip install git+https://github.com/huggingface/peft`. An adapter trained with a source install may need a source install to load.

Other libraries used with quantized bases are separate installs and have their own constraints: `bitsandbytes`, `gptqmodel` (docs show `>=7.0.0`), `aqlm` (`>=1.0.2`), `hqq`, `eetq`, `torchao`. Read the PEFT quantization guide for the one you use.

## Verify

```bash
python - <<'PY'
import peft, transformers, torch
print(peft.__version__, transformers.__version__, torch.__version__, torch.cuda.is_available())
PY
```
