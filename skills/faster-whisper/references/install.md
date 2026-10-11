# faster-whisper: install

> Verified against faster-whisper v1.2.1 and ctranslate2 4.8.2 (README, requirements.txt, docker/Dockerfile), 2026-10-11

## Requirements

- Python 3.9 or newer (`pyproject`/PyPI `requires_python >=3.9`).
- FFmpeg is **not** needed: audio is decoded with PyAV, which bundles the FFmpeg libraries.
- Runtime dependencies from `requirements.txt`: `ctranslate2>=4.0,<5`, `huggingface_hub>=0.23`, `tokenizers>=0.13,<1`, `onnxruntime>=1.14,<2` (for the Silero VAD), `av>=11`, `tqdm`.

## CPU

```bash
python3 -m venv ~/venvs/faster-whisper
. ~/venvs/faster-whisper/bin/activate
pip install faster-whisper
```

Then load with `device="cpu", compute_type="int8"`. The README documents only `cpu`, `cuda` and `auto` devices; it does not document a Metal GPU backend, so on Apple silicon plan on CPU. For Apple GPU or Core ML speed, use the `whisper-cpp` skill.

## NVIDIA GPU

GPU execution needs, per the README:

- cuBLAS for CUDA 12
- cuDNN 9 for CUDA 12

The latest `ctranslate2` supports only CUDA 12 and cuDNN 9. Older stacks need an older CTranslate2: README says `3.24.0` for CUDA 11 with cuDNN 8, and `4.4.0` for CUDA 12 with cuDNN 8 (`pip install --force-reinstall ctranslate2==4.4.0`).

Ways to get the libraries (the README lists all three):

1. NVIDIA's own installers (recommended by upstream).
2. The container `nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04`, which is what upstream's `docker/Dockerfile` uses (then `pip3 install faster-whisper`).
3. Linux only, pip wheels. `LD_LIBRARY_PATH` must be set before Python starts:

```bash
pip install nvidia-cublas-cu12 nvidia-cudnn-cu12==9.*
export LD_LIBRARY_PATH="$(python3 -c 'import os, nvidia.cublas, nvidia.cudnn; print(os.path.dirname(nvidia.cublas.__path__[0]) + "/cublas/lib:" + os.path.dirname(nvidia.cudnn.__path__[0]) + "/cudnn/lib")')"
```

Windows users can take the library archive from the third-party Purfview `whisper-standalone-win` releases; that is not an upstream faster-whisper artefact, so ask the user before using it.

Confirm the GPU is visible:

```bash
python3 -c 'import ctranslate2; print(ctranslate2.get_cuda_device_count(), ctranslate2.get_supported_compute_types("cuda"))'
```

## Source installs

```bash
pip install --force-reinstall "faster-whisper @ https://github.com/SYSTRAN/faster-whisper/archive/refs/heads/master.tar.gz"
# or a specific commit
pip install --force-reinstall "faster-whisper @ https://github.com/SYSTRAN/faster-whisper/archive/<commit>.tar.gz"
```

Pin releases in production (`pip install 'faster-whisper==1.2.1'`); `master` can contain unreleased behaviour changes.

## Smoke test

```bash
python3 - <<'PY'
from faster_whisper import WhisperModel
m = WhisperModel("tiny", device="cpu", compute_type="int8")
segments, info = m.transcribe("audio.wav")
print(info.language, info.language_probability)
print(" ".join(s.text.strip() for s in segments))
PY
```

The first run downloads `Systran/faster-whisper-tiny` from the Hugging Face Hub into the standard cache (`~/.cache/huggingface/hub`, or `HF_HOME`). Ask before downloading larger models.
