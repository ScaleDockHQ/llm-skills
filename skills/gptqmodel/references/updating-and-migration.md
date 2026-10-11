# GPT-QModel: updating and migrating

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

## Release cadence

Frequent: v7.3.4 (2026-08-19), v7.3.5 (08-25), v7.3.6 (08-31), v7.4.0 (09-08), v7.5.0 (09-15); `main` is 7.6.0-dev with new model support. Notable additions per the README: 7.4.0 resumable checkpoints, shared-input Hessian dedup, `lm_head`/embedding requantization, native GGUF updates; 7.5.0 device-aware kernel selection and safer CUDA dispatch; 7.3.4 the Swordfish Blackwell kernel, planar GPTQ formats (`gptq_p`) and native MPS quantization.

```bash
pip index versions gptqmodel | head -1
pip install -U -v gptqmodel            # in the quantization venv, not the serving one
python -c "import gptqmodel;print(gptqmodel.__version__)"
```

For a model added on `main` only: `pip install -v git+https://github.com/ModelCloud/GPTQModel.git` (a source build; check the README's `python3-dev` note).

## What to redo after an update

- Existing GPTQ/AWQ checkpoints keep working in vLLM, SGLang and Transformers; re-quantize only for a fix that affects your model, a new better method, or a new architecture feature.
- Resume validation requires the same software versions: finish a checkpointed job before upgrading, or restart it.
- Clear or keep the JIT cache (`~/.cache/gptqmodel`); a changed torch/CUDA triggers a rebuild.
- Re-run the evaluation in `evaluate-and-adapters.md`.

## Migrating from AutoGPTQ and AutoAWQ

Upstream: GPT-QModel supports GPTQ and AWQ workflows that integrate with Transformers, Optimum and PEFT; existing inference integrations can generally stay (verify configuration compatibility). For AutoAWQ quantization scripts:

- `version` becomes `format`.
- `zero_point` becomes `sym`: `sym=True` is equivalent to `zero_point=False`.
- Calibration is passed to `model.quantize(...)` on a model loaded with `GPTQModel.load(model_id, quant_config)`.

Re-quantizing is not needed to load old checkpoints; test loading them with `GPTQModel.load(path)` on a copy first.

## Roll back

`pip install gptqmodel==<old>` in the same venv; keep a `pip freeze > requirements.lock` taken before the upgrade.
