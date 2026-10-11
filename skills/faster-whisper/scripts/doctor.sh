#!/usr/bin/env bash
# Read-only faster-whisper environment check. Prints versions and device support; never prints secrets.
# Usage: scripts/doctor.sh [python-interpreter]   (default python3; activate your venv first)
# Needs bash 3.2+ and the chosen Python. GPU lines are skipped when nvidia-smi is absent.
set -euo pipefail

PY="${1:-python3}"
command -v "$PY" >/dev/null || { echo "error: $PY not found" >&2; exit 2; }

echo "== python"; "$PY" --version
echo "== packages"
"$PY" - <<'PYEOF' 2>&1 || echo "faster-whisper or ctranslate2 is not importable in this interpreter"
import ctranslate2
import faster_whisper
print("faster-whisper", faster_whisper.__version__)
print("ctranslate2", ctranslate2.__version__)
print("cpu compute types:", sorted(ctranslate2.get_supported_compute_types("cpu")))
n = ctranslate2.get_cuda_device_count()
print("cuda devices:", n)
if n:
    print("cuda compute types:", sorted(ctranslate2.get_supported_compute_types("cuda")))
PYEOF
echo "== gpu"
if command -v nvidia-smi >/dev/null; then
  nvidia-smi -L
  ldconfig -p 2>/dev/null | grep -E 'libcudnn|libcublas' | head -4 || true
else
  echo "nvidia-smi not found"
fi
echo "== cached whisper models"
ls "${HF_HOME:-$HOME/.cache/huggingface}/hub" 2>/dev/null | grep -i whisper || echo "none"
