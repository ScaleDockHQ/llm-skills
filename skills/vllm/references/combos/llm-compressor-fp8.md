# Quantize a model to FP8 with llm-compressor, then serve it

> Verified against vLLM v0.31.0 docs (`features/quantization/llm_compressor/fp8.md`, `features/quantization/online.md`), 2026-10-11

Llm-compressor's own version was not checked.

Use when a BF16 model is slightly too large or too slow and you have a GPU with FP8 support (compute capability
8.9+: Ada, Hopper, Blackwell; MI300 on AMD). FP8 roughly halves weight memory with minimal accuracy impact
(upstream claim). The skill `llm-compressor` covers the library in depth; this page is the vLLM side.

## Option A: online FP8, no checkpoint (quickest)

```bash
vllm serve <bf16-model> --quantization fp8_per_tensor
```

Weights are quantized to FP8 E4M3 at load with a per-tensor scale; activations scale dynamically each forward
pass, so latency gains are limited. v0.31.0 replaced `quantization="fp8"` for this; check `--help` on your version.

## Option B: calibration-free FP8_DYNAMIC checkpoint (recommended)

Use a **separate virtualenv** for llm-compressor; upstream says it may not coexist with vLLM.

```bash
python -m venv venv-llm-compressor && . venv-llm-compressor/bin/activate
pip install llmcompressor
```

Run in a Python session or a script you keep **outside** this repo (the skills repo ships no Python files):

```python
from transformers import AutoTokenizer, AutoModelForCausalLM
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "<org>/<model>"
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, device_map="auto", dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

recipe = QuantizationModifier(targets="Linear", scheme="FP8_DYNAMIC", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)

SAVE_DIR = MODEL_ID.split("/")[1] + "-FP8-Dynamic"
model.save_pretrained(SAVE_DIR)
tokenizer.save_pretrained(SAVE_DIR)
```

`FP8_DYNAMIC` = static per-channel weights plus dynamic per-token activations; round-to-nearest, no calibration
data needed. Then serve the folder like any model:

```bash
vllm serve ./Meta-Llama-3-8B-Instruct-FP8-Dynamic --served-model-name my-fp8
```

vLLM detects the format from the checkpoint config. Choose the GEMM kernel with `--linear-backend`; if inference
hangs with no error try `VLLM_USE_DEEP_GEMM=0` or `--linear-backend cutlass`.

## Evaluate before trusting it

```bash
MODEL=$PWD/Meta-Llama-3-8B-Instruct-FP8-Dynamic
lm_eval --model vllm --model_args pretrained=$MODEL,add_bos_token=True \
  --tasks gsm8k --num_fewshot 5 --batch_size auto --limit 250
```

Quantized models can be sensitive to the `bos` token and `lm_eval` does not add it by default, so keep
`add_bos_token=True`. Compare against the BF16 model on your own tasks, not only gsm8k.

## Notes

- Ampere and Turing run FP8 checkpoints as weight-only W8A16 through Marlin (memory win, no compute win).
- Already-quantized FP8 checkpoints from the model vendor or Neural Magic / Red Hat collections avoid this work.
- NVFP4 is the Blackwell-native next step (`combos/rtx-blackwell.md`; skill `nvidia-modelopt`). Other
  formats and general guidance: skill `model-quantization`.
- Install with `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`.
