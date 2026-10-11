# Updating

> Verified against KTransformers v0.7.1 (GitHub releases, README updates, PyPI kt-kernel and sglang-kt 0.7.0.post4), 2026-10-11

## Versions

- GitHub releases: v0.6.4 (2026-07-23), v0.7.0 (2026-08-17), v0.7.0.post4 (2026-09-13), v0.7.1 (2026-09-15, "Latest").
- PyPI `kt-kernel`, `sglang-kt` and `ktransformers` stop at 0.7.0.post4. v0.7.1 focuses on Qwen VLM and Kimi LoRA fine-tuning and is not on PyPI at verification time:
  to run it, build from the v0.7.1 tag. Check `pip index versions kt-kernel` again before assuming either way.
- `kt-kernel` and `sglang-kt` are released together; keep both at the same version.
- Tutorials are tied to moments in time: a model recipe can need a specific branch (the Qwen3.5 tutorial checks out a `qwen3.5` branch). Read the tutorial for the version you run.

## Procedure

```bash
pip list 2>/dev/null | grep -i -E '^(kt-kernel|sglang-kt|ktransformers|torch) '
kt version; kt doctor
# Read the release notes first: https://github.com/kvcache-ai/ktransformers/releases
python3 -m venv ~/kt-venv-new && . ~/kt-venv-new/bin/activate        # new venv, never upgrade in place
pip install "kt-kernel==X" "sglang-kt==X"
python -m sglang.launch_server --help | grep -- --kt-                  # flags changed?
```

1. Launch the new venv on another port with the same flags; diff the `--kt-*` help output against the old one.
2. Smoke test: chat, stream, tool call, one long prompt (checks layerwise prefill VRAM).
3. Re-benchmark and compare accuracy on a few known prompts, because kernel changes can alter numerics.
4. Switch traffic, keep the old venv until a day of real traffic is clean.

## Rollback

Reactivate the old venv and restart the service with the previous flags. Converted AMX weights may depend on the kernel version: keep the old converted directory until the
upgrade is proven, and re-convert with the new `scripts/convert_cpu_weights.py` if the new release says the format changed.

## Source builds

`git fetch --tags && git checkout vX && git submodule update --init --recursive && ./install.sh` (it compiles for the local CPU; rebuild after CPU or microcode changes).
