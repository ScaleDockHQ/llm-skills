# Updating Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (GitHub releases, docs/installation.qmd, docs/multi-gpu.qmd, docs/faq.qmd), 2026-10-11

## Cadence and status

Actively maintained. Recent releases: v0.20.0 (2026-09-30), v0.19.0 (2026-09-10), v0.18.0 (2026-07-17), v0.17.0 (2026-06-03). Check the latest tag before pinning:

```bash
gh api repos/axolotl-ai-cloud/axolotl/releases/latest --jq '.tag_name,.published_at'
curl -s https://pypi.org/pypi/axolotl/json | jq -r '.info.version,.info.requires_python'
pip show axolotl 2>/dev/null | head -3
```

## Upgrade steps

1. Record what works: `pip show axolotl`, `pip freeze | grep -E 'torch|transformers|peft|trl|vllm|deepspeed'`, the config files.
2. Read the release notes between your version and the target for config renames.
3. Use a fresh venv or a new Docker tag (`axolotlai/axolotl:<version>`); do not upgrade in place on a machine mid-run.
4. Re-run the install command with the new pin: `uv pip install --no-build-isolation 'axolotl[deepspeed]==<version>'`.
5. Re-validate: `axolotl preprocess cfg.yml --debug` on an existing config, then a 20-step training smoke run.

## Breaking changes seen in current upstream docs

- Python >= 3.12 and PyTorch >= 2.13.0 (2.13.0 recommended); Blackwell needs PyTorch >= 2.11 and CUDA 13.0. Runtime images target CUDA 13.0.
- FSDP1 removed; only FSDP2 (`fsdp_version: 2`, default). Old `fsdp:` lists and `fsdp_*` keys must be migrated (`references/multi-gpu.md`).
- `flash_attention: true` is deprecated: use `attn_implementation: flash_attention_2` (or `sdpa`).
- Click CLI uses dash overrides (`--lora-model-dir`); the legacy `python -m axolotl.cli.*` form uses underscores.
- `axolotl vllm-serve` and GRPO require `vllm>=0.30.0`; TRL-side GRPO options track TRL (some options are marked "TRL >= 1.6/1.7/1.8/1.9" upstream).
- Docker images moved to uv (`/workspace/axolotl-venv`); `-uv` names are aliases, not separate lines.
- `train_on_eos` / `eot_tokens` semantics were reworked: with no `eot_tokens`, `eot_tokens` defaults to the tokenizer's EOS and `train_on_eot` follows `train_on_eos`.

Keep the previous venv or image until one full training and merge cycle passes.
