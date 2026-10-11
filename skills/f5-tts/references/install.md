# F5-TTS: install

> Verified against F5-TTS 1.1.22 (README, pyproject.toml, Dockerfile), 2026-10-11

## Environment

```bash
conda create -n f5-tts python=3.11     # README example; badge says Python 3.10; virtualenv also works
conda activate f5-tts
conda install ffmpeg                    # or install ffmpeg with the OS package manager
```

FFmpeg matters: an all-silent output is usually a missing ffmpeg (upstream inference notes).

## PyTorch for your device

Install PyTorch first, matched to the hardware (README examples):

```bash
# NVIDIA: pick the wheel index for your CUDA version
pip install torch==2.8.0+cu128 torchaudio==2.8.0+cu128 --extra-index-url https://download.pytorch.org/whl/cu128
# older example: torch==2.4.0+cu124 with the cu124 index
# AMD (Linux): pip install torch==2.9.1+rocm7.2 torchaudio==2.9.1+rocm7.2 --extra-index-url https://download.pytorch.org/whl/rocm7.2
# Apple silicon: pip install torch torchaudio
# Intel XPU: pip install torch torchaudio --index-url https://download.pytorch.org/whl/test/xpu
```

Notes from the README: RDNA 3.5 and RDNA 4 GPUs (gfx1151, gfx1201) need ROCm 7.x; using ROCm 6.x there gives `HIP error: invalid device function`. Older RDNA1/2/3 can use `torch==2.5.1+rocm6.2`. Intel GPUs need the oneAPI runtime or IPEX. Ask before installing: these wheels are multiple gigabytes.

## Install F5-TTS

```bash
pip install f5-tts                      # inference only (PyPI 1.1.22 on 2026-10-11)
# or, to train or edit:
git clone https://github.com/SWivid/F5-TTS.git && cd F5-TTS
# git submodule update --init --recursive    # optional, only for the bigvgan vocoder
pip install -e .
```

Entry points installed: `f5-tts_infer-cli`, `f5-tts_infer-gradio`, `f5-tts_finetune-cli`, `f5-tts_finetune-gradio`. Dependencies include `gradio>=6.15.0`, `transformers`, `vocos`, `torchdiffeq`, `accelerate`, `librosa`, `pydub`, `torchcodec` (see `pyproject.toml`). On Python 3.10 `numpy<=1.26.4` is pinned.

## First run downloads

The first inference downloads the checkpoint (`SWivid/F5-TTS`, `F5TTS_v1_Base/model_1250000.safetensors`) and the Vocos vocoder from Hugging Face into the cache. Leaving `--ref_text ""` additionally downloads `openai/whisper-large-v3-turbo` for transcription. Ask before downloading; set `HF_HOME` to move the cache.

## Docker (NVIDIA)

```bash
docker container run --rm -it --gpus=all \
  --mount 'type=volume,source=f5-tts,target=/root/.cache/huggingface/hub/' \
  -p 127.0.0.1:7860:7860 ghcr.io/swivid/f5-tts:main
# web UI only:
docker container run --rm -it --gpus=all --mount 'type=volume,source=f5-tts,target=/root/.cache/huggingface/hub/' \
  -p 127.0.0.1:7860:7860 ghcr.io/swivid/f5-tts:main f5-tts_infer-gradio --host 0.0.0.0
```

Upstream's examples publish `-p 7860:7860`; use the loopback form. The image is built from `pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel` and the tag `main` follows the default branch, so it is not pinned. Build your own for reproducibility: `docker build -t f5tts:v1 .`.

## Verify

```bash
f5-tts_infer-cli --help | head -20
python3 -c 'import f5_tts; print("ok")'
```

Run one inference from `inference.md` with the repo's example clip to prove the whole path.
