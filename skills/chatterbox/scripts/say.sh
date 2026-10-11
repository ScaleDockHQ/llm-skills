#!/usr/bin/env bash
# Generate one WAV with Chatterbox through a short inline Python call.
# Usage: say.sh "text" out.wav [ref.wav]
# Env: CHATTERBOX_PY (python in the Chatterbox venv, default python3),
#      CHATTERBOX_DEVICE (cuda|mps|cpu, default auto), CHATTERBOX_NANO=1 for Nano.
# Needs approval to download model weights on first run. Prints no secrets.
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 \"text\" out.wav [ref.wav]" >&2
  exit 2
fi

PY="${CHATTERBOX_PY:-python3}"
TEXT="$1" OUT="$2" REF="${3:-}" "$PY" - <<'PYEOF'
import os
import torch
import torchaudio as ta
from chatterbox.tts_turbo import ChatterboxTurboTTS

dev = os.environ.get("CHATTERBOX_DEVICE") or (
    "cuda" if torch.cuda.is_available()
    else "mps" if torch.backends.mps.is_available()
    else "cpu"
)
nano = os.environ.get("CHATTERBOX_NANO") == "1"
model = ChatterboxTurboTTS.from_pretrained(device=dev, nano=nano) if nano else ChatterboxTurboTTS.from_pretrained(device=dev)
ref = os.environ.get("REF") or None
wav = model.generate(os.environ["TEXT"], audio_prompt_path=ref)
ta.save(os.environ["OUT"], wav, model.sr)
print("wrote", os.environ["OUT"], "sr", model.sr, "device", dev)
PYEOF
