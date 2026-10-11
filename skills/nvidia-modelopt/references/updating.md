# Updating NVIDIA Model Optimizer

> Verified against NVIDIA Model Optimizer 0.47.0 (PyPI, GitHub releases, CHANGELOG.rst, README.md), TensorRT-LLM v1.2.1, vLLM v0.31.0, SGLang v0.5.21, 2026-10-11

## Release channels

- PyPI `nvidia-modelopt`: stable 0.47.0 (2026-09-23). GitHub releases also carry release candidates (for example `0.48.0rc0`, 2026-10-08, and `0.47.0rc2`); pip skips pre-releases unless you pass `--pre`, so stay on stable for production.
- Changelog: https://nvidia.github.io/Model-Optimizer/reference/0_changelog.html (same text as `CHANGELOG.rst` in the repo). Roadmap issue linked from the README.
- Project status checked 2026-10-11: not archived, Apache-2.0, pushed to the same day.

## Check what you have

```bash
. ~/venvs/modelopt/bin/activate
pip show nvidia-modelopt torch transformers | grep -E '^(Name|Version):'
pip index versions nvidia-modelopt 2>/dev/null | head -2
gh api repos/NVIDIA/Model-Optimizer/releases --jq '.[0:4][] | [.tag_name,.prerelease,.published_at] | @tsv'
git -C ~/src/Model-Optimizer describe --tags
```

## Upgrade safely

1. Read the changelog entries between your tag and the target, especially "Backward Breaking Changes" and "Deprecations". 0.47.0 removed things earlier tutorials use (`examples/llm_ptq`, old qformat aliases, `--auto_quantize_*` flags, `--quant_cfg` in trainers, legacy `layerwise` keys) and changed the recipe layout.
2. Create a fresh venv and a fresh clone at the new tag:

   ```bash
   python3 -m venv ~/venvs/modelopt-new && . ~/venvs/modelopt-new/bin/activate
   pip install -U "nvidia-modelopt[hf]"
   git -C ~/src/Model-Optimizer fetch --tags && git -C ~/src/Model-Optimizer checkout <new-tag>
   pip install -r ~/src/Model-Optimizer/examples/hf_ptq/requirements.txt
   ```

3. Re-run a small model with the same qformat and compare `hf_quant_config.json`, a smoke prompt and perplexity with the old export.
4. Re-test the export on the engine version you serve with. Some format changes need a newer engine; some old checkpoints (for example quantized `TEGroupedLinear` saved before 0.47) must be regenerated.
5. Keep the old venv until the small run and the engine check pass.

## What changed recently (from the 0.47 changelog)

- Recipe tiers: model-type recipes under `modelopt_recipes/huggingface/<model_type>/`, checkpoint-mirror recipes under `models/<org>/<model_id>/`.
- New presets and recipes: `nvfp4_four_over_six`, `nvfp4_svdquant`, `nvfp4_act_headroom` calibration for activation global scales, FP8 vision-encoder recipes for Qwen3-VL and Qwen3.5, a Kimi-K3 streaming converter.
- `mtq.quantize` fails loudly when no weight quantizer matches; HF export no longer crashes on zero-amax dynamic-block quantizers.
- `lm_eval` over TensorRT-LLM moved to the harness's own `trtllm` backend (`lm_eval_trtllm.py`).
- Container floor for Megatron features moved to `nemo:26.08`.

## Updating the engines

After upgrading ModelOpt or an engine, re-run the smoke prompts on each checkpoint and read the engine startup log for the selected quantization method and kernel. See the `vllm`, `sglang` and `tensorrt-llm` skills for engine upgrades.

## Updating this skill's facts

Re-read the upstream README, `examples/hf_ptq/README.md` and `hf_ptq.py --help` at the new tag, the preset and recipe directory listings, PyPI metadata (requirements) and the engines' ModelOpt docs, then update each reference's `> Verified against ...` line and bump the skill version.
