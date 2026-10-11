# Updating bitsandbytes

> Verified against bitsandbytes 0.50.2 (PyPI, GitHub releases 0.50.1 and 0.50.2), 2026-10-11

## Where releases come from

- PyPI `bitsandbytes` (latest 0.50.2, released 2026-08-27) and https://github.com/bitsandbytes-foundation/bitsandbytes/releases. The release list also holds the rolling `continuous-release_main` pre-release; trust the "latest" release.
- Project status checked 2026-10-11: not archived, MIT licensed, active development.
- Recent releases added ROCm 10.0 builds (0.50.2) and NVIDIA RTX Spark Windows on ARM64 and CDNA5 support (0.50.1).

## Check what you have

```bash
python3 -m pip show bitsandbytes torch transformers peft | grep -E '^(Name|Version):'
python3 -m pip index versions bitsandbytes 2>/dev/null | head -2
gh api repos/bitsandbytes-foundation/bitsandbytes/releases/latest --jq '.tag_name,.published_at'
```

## Upgrade safely

1. Read the notes between your version and the target (`gh api repos/bitsandbytes-foundation/bitsandbytes/releases/tags/<tag> --jq .body`). Look for backend, minimum PyTorch and Python changes.
2. Use a fresh venv and keep the same PyTorch build:

   ```bash
   python3 -m venv ~/venvs/bnb-new && . ~/venvs/bnb-new/bin/activate
   pip install -U bitsandbytes
   python3 -m bitsandbytes | tail -25
   ```

3. Re-run a small model with the same config; compare `get_memory_footprint()` and a sample output with the old environment. Re-run one QLoRA step if you train.
4. Keep the old venv until a full run matches.
