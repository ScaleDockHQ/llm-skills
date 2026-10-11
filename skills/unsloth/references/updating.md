# Updating Unsloth

> Verified against unslothai/unsloth library 2026.10.3 (PyPI), Studio/Desktop v0.1.905-beta (GitHub releases), README.md install and update sections, 2026-10-11

## Channels and status

Actively maintained (Apache-2.0 core, pushed 2026-10-11, new Studio beta tags almost daily: v0.1.902 on 2026-10-01 through v0.1.905 on 2026-10-08).

| Channel                            | Version scheme                                                                     | Check                                                                                           |
| ---------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Core library (PyPI)                | Date-based, `2026.10.3`                                                            | `curl -s https://pypi.org/pypi/unsloth/json \| jq -r '.info.version'`                           |
| Studio / Desktop (GitHub releases) | `v0.1.NNN-beta`                                                                    | `gh api repos/unslothai/unsloth/releases/latest --jq .tag_name`                                 |
| Docker                             | `latest`, `studio`, `core`, `nightly-YYYY.MM.DD`, `core-nightly-...`, release tags | Docker Hub `unsloth/unsloth`                                                                    |
| Nightly source                     | `main` / `nightly` branch                                                          | `git clone ...; ./install.sh --local` (README); `git checkout nightly` per the pip-install docs |

## Upgrade Core

1. Record `pip freeze | grep -E 'unsloth|torch|transformers|trl|peft|bitsandbytes|xformers'`.
2. Make a new venv: `uv venv unsloth_env2 --python 3.13 && source unsloth_env2/bin/activate`.
3. `uv pip install unsloth --torch-backend=auto` (Windows: `torchao` first).
4. Run a 10-step smoke training and a save in the new venv; keep the old venv until it passes.
5. Never upgrade `trl` or `transformers` on top of it; a TRL range is pinned in Unsloth's `pyproject.toml` (`<=1.15.0` on 2026-10-11).

## Upgrade Studio / Desktop

Re-run `curl -fsSL https://unsloth.ai/install.sh | sh` (the same command updates; Windows `irm ... | iex`). Dev installs: `cd unsloth && git pull && ./install.sh --local`. Reinstall normally holds two copies at once; `UNSLOTH_INSTALL_NO_ROLLBACK=1` (or `--no-rollback` with `--local`) frees space at the cost of no undo. Keep the model cache (`~/.cache/huggingface/hub/`).

## Docker

Pull a pinned tag (`docker pull unsloth/unsloth:<tag>`), not just `latest`, and stop/recreate the container; named volumes (`unsloth-studio`) keep Studio state.

## Things that changed recently (docs vs older references)

- README now states multi-GPU support (Accelerate, DeepSpeed, DDP); older notes said single-device only.
- Studio and Desktop are the headline product; Core is the code-based variant. Studio has an OpenAI/Anthropic-compatible API and `unsloth start <agent>`.
- GGUF export is also available through Studio's export page; the library's `ALLOWED_QUANTS` on main includes `bf16`.
