# Chatterbox: install

> Verified against resemble-ai/chatterbox master (pyproject.toml, README) and PyPI chatterbox-tts 0.1.7, 2026-10-11

## PyPI versus source

PyPI `chatterbox-tts` 0.1.7 was uploaded 2026-03-26 and requires Python 3.10 or newer. The repository's `pyproject.toml` still says 0.1.7, but three commits landed after that upload: the opt-in V3 multilingual checkpoint (2026-05-01), the V3 and Single Language Pack release (2026-06-10) and Nano support (2026-07-21). Upstream's last release tag is `v0.1.2` (2025-06-13). So:

| Need                                | Install                                                                                                  |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------- |
| original, Turbo, Multilingual V2    | `pip install chatterbox-tts` (confirm Turbo is in the wheel: `python3 -c 'import chatterbox.tts_turbo'`) |
| Multilingual V3, Nano, newest fixes | install from source (below)                                                                              |

## Environment

```bash
python3.11 -m venv ~/venvs/chatterbox      # upstream developed and tested on Python 3.11, Debian 11
. ~/venvs/chatterbox/bin/activate
pip install chatterbox-tts                  # PyPI
# or source:
git clone https://github.com/resemble-ai/chatterbox.git && cd chatterbox
pip install -e .
```

Dependencies are pinned in `pyproject.toml`: `torch==2.6.0` and `torchaudio==2.6.0` for Python below 3.14 (`>=2.9.0` on 3.14), `transformers==5.2.0`, `diffusers==0.29.0`, `gradio==6.8.0`, `librosa==0.11.0`, `safetensors==0.5.3`, `conformer==0.3.2`, `pykakasi==2.3.0`, `s3tokenizer`, `spacy-pkuseg`, `pyloudnorm`, `omegaconf`, numpy below 2 on Python below 3.13. These pins will fight other ML packages: keep Chatterbox in its own virtualenv.

`resemble-perth @ git+https://github.com/resemble-ai/Perth.git@master` is installed straight from a GitHub branch (the watermarker). It is unpinned, so installs are not reproducible and trust the `master` branch; review it, or vendor a commit, in sensitive environments.

On a CUDA host the default torch 2.6.0 wheel may not match your CUDA version; install the matching PyTorch build first and then the package with `--no-deps` only if you understand the pin conflict. Ask the user before changing torch versions.

## Devices

`from_pretrained(device=...)` takes `"cuda"`, `"mps"` or `"cpu"`. If you ask for MPS and it is unavailable the loader prints why and falls back to CPU. Apple silicon: upstream ships `example_for_mac.py`, which patches `torch.load` with a `map_location`, so checkpoint loading works on MPS or CPU. Nano is the model aimed at CPU.

## First-run downloads

`from_pretrained` downloads from Hugging Face on first use (`hf_hub_download` for the original, `snapshot_download` for Turbo and Nano, honouring `HF_TOKEN` if set). Ask before downloading, set `HF_HOME` to relocate the cache, and for offline hosts pre-populate the cache and use `from_local(ckpt_dir, device)`. If the Xet backend errors (`Unable to parse string as hex hash value`) the Turbo loader retries over standard HTTP; for other classes set `HF_HUB_DISABLE_XET=1`.

## Verify

```bash
python3 - <<'PY'
import torch, torchaudio as ta
from chatterbox.tts_turbo import ChatterboxTurboTTS
dev = "cuda" if torch.cuda.is_available() else "cpu"
m = ChatterboxTurboTTS.from_pretrained(device=dev)
ta.save("check.wav", m.generate("Hello from Chatterbox."), m.sr)
print("wrote check.wav", m.sr)
PY
```

Then listen to `check.wav` and `file check.wav`.
