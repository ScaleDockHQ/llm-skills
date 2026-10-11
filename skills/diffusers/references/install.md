# Diffusers: install

> Verified against Diffusers v0.41.0 (docs installation, PyPI metadata and the v0.41.0 wheel), 2026-10-11

Upstream: [huggingface/diffusers](https://github.com/huggingface/diffusers) (Apache-2.0, not archived, last push 2026-10-10). PyPI `diffusers` 0.41.0 was uploaded 2026-10-06 and requires Python 3.10+. The docs say it is tested with PyTorch 2.6+.

## Pick a path

| Path                                                          | Use when                                                             |
| ------------------------------------------------------------- | -------------------------------------------------------------------- |
| `uv pip install "diffusers[torch]" transformers`              | default; `[torch]` pulls PyTorch and Accelerate                      |
| `pip install` in a venv                                       | no uv; same extras                                                   |
| `conda install -c conda-forge diffusers`                      | conda environments                                                   |
| `uv pip install git+https://github.com/huggingface/diffusers` | you need unreleased `main` (may be unstable; install Accelerate too) |
| editable clone, `uv pip install -e ".[torch]"`                | developing or patching; keep the clone                               |

```bash
uv venv ~/diffusers-env && . ~/diffusers-env/bin/activate     # or: python3 -m venv ...
uv pip install "diffusers[torch]" transformers                 # install the right PyTorch first on CUDA/ROCm hosts
diffusers-cli env                                              # prints Python, PyTorch, Diffusers, CUDA info
```

Install PyTorch for the hardware from pytorch.org first when the default wheel does not match (CUDA version, ROCm, XPU). Core dependencies at 0.41.0: `huggingface-hub>=1.32,<2`, `safetensors>=0.8`, `numpy`, `Pillow`, `requests`, `regex`; extras include `training` (`accelerate`, `peft>=0.17`, `datasets`, `tensorboard`...). Other helpers used in this skill need their own installs: `bitsandbytes`, `gguf`, `kernels`, `peft`, `sentencepiece`/`protobuf` for some tokenizers.

## Devices

Nothing is CUDA-specific; pass `"cuda"`, `"mps"` (Apple silicon), `"xpu"` (Intel) or `"cpu"`. Pick at runtime: `torch.accelerator.current_accelerator().type if torch.accelerator.is_available() else "cpu"`. Apple silicon: needs an arm64 Python; the MPS backend does not support arrays larger than `2**32` elements, and `pipe.enable_attention_slicing()` is recommended on machines with under 64 GB (docs/optimization/mps).

## NVIDIA Spark (ARM64)

Docs: install PyTorch from NVIDIA's index, then Diffusers, because the default and standard PyTorch indexes lack these ARM64 builds:

```bash
uv pip install torch --index-url https://pypi.nvidia.com
uv pip install diffusers
```

Check `nvidia-smi` first. Unified memory means a loaded pipeline competes with any resident LLM; see the `nvidia-dgx-spark` skill.

## Hub access and cache

- Models download from the Hugging Face Hub to `HF_HOME` (or `HF_HUB_CACHE`). Gated repos (for example FLUX.1-dev) need an account that accepted the licence and a token: `hf auth login` or `HF_TOKEN` from a `0600` file; the `hugging-face` skill covers it.
- Offline once cached: `export HF_HUB_OFFLINE=1`. A local directory (from `snapshot_download`) passed to `from_pretrained` is not re-downloaded or updated.
- Telemetry is sent only on Hub loads; opt out with `HF_HUB_DISABLE_TELEMETRY=1`.
- Parallel shard loading: `HF_ENABLE_PARALLEL_LOADING=YES`.
- Large model folders: check `du -sh` and free disk before approving a download.

## Agent skills from upstream

`diffusers-cli skills list` and `diffusers-cli skills add <name>` install upstream's own agent skill bundles (registry under `.ai/skills/` in the repo, installed to `.agents/skills/` for Cursor and Codex or `.claude/skills/`). They are fetched from GitHub `main` at install time; read the preview (`diffusers-cli skills` supports previewing a skill) before installing.
