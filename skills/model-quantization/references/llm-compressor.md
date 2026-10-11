# AWQ, GPTQ, FP8 and NVFP4 with LLM Compressor

> Verified against vllm-project/llm-compressor 0.14.0 (README.md, examples/awq, examples/quantization_w4a16, examples/quantization_w8a8_fp8, examples/quantization_w4a4_fp4, docs/guides/big_models_and_distributed/model_loading.md) and vLLM v0.31.0, 2026-10-11

## What it is and when to choose it

[LLM Compressor](https://github.com/vllm-project/llm-compressor) (Red Hat AI and the vLLM project) applies quantization recipes to a Hugging Face model and saves a [compressed-tensors](https://github.com/vllm-project/compressed-tensors) checkpoint that vLLM loads natively (SGLang also reads compressed-tensors). Choose it when the target engine is vLLM or SGLang and you want:

- INT4 weight-only (W4A16) via GPTQ or AWQ: Ampere and newer, best memory savings.
- FP8 (W8A8): Ada / Hopper / Blackwell (compute capability >= 8.9), near-lossless, faster prefill.
- NVFP4 (W4A4) or NVFP4A16: Blackwell; on < SM100 vLLM runs it weight-only.
- MXFP4 / MXFP8, INT8 W8A8, KV-cache FP8, and other schemes also exist.

It has no CLI: you write a short Python script around `oneshot()`. Algorithms: simple PTQ (round-to-nearest), GPTQ, AWQ, SmoothQuant, AutoRound, rotations (SpinQuant, QuIP).

## Install

Same on DGX Spark (arm64) and x86, given a CUDA-enabled PyTorch for the platform:

```bash
python3 -m venv ~/venvs/llmc && . ~/venvs/llmc/bin/activate
pip install llmcompressor
```

Install it in its own venv, separate from the vLLM you serve with, so their pins do not fight.

## Minimal working config/command

Pick one recipe. Scheme names below are taken from the upstream examples.

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "<org>/<model>"           # or a local path
model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

# FP8 dynamic: no calibration data needed
recipe = QuantizationModifier(targets="Linear", scheme="FP8_DYNAMIC", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)

SAVE_DIR = MODEL_ID.split("/")[-1] + "-FP8-Dynamic"
model.save_pretrained(SAVE_DIR)          # the INT4 / NVFP4 examples pass save_compressed=True
tokenizer.save_pretrained(SAVE_DIR)
```

Other recipes (replace `recipe` and the `oneshot` call):

```python
# GPTQ INT4 weight-only (W4A16, group 128): needs calibration data
from llmcompressor.modifiers.gptq import GPTQModifier
recipe = GPTQModifier(targets="Linear", scheme="W4A16", ignore=["lm_head"])
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=512)

# AWQ INT4 asymmetric
from llmcompressor.modifiers.transform.awq import AWQModifier
recipe = [AWQModifier(duo_scaling="both"),
          QuantizationModifier(targets=["Linear"], scheme="W4A16_ASYM", ignore=["lm_head"])]
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=512, num_calibration_samples=256)

# NVFP4 (weights + activations); calibrates activation global scales
recipe = QuantizationModifier(targets="Linear", scheme="NVFP4", ignore=["lm_head"])
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=20)
```

Other scheme strings listed in the README: `FP8_BLOCK`, `NVFP4A16`, `W8A16`, `MXFP4A16`, `MXFP8A16`, and W8A8 INT8/FP8. Check the matching `examples/` folder before using one.

Run the script inside a memory-capped scope (`memory-safety.md`), for example:

```bash
systemd-run --user --scope -p MemoryMax=96G -p MemorySwapMax=0 -- python quantize_fp8.py
```

## How it plugs into the stack

- In: HF model (local dir or Hub id). Out: HF directory with compressed safetensors and a `quantization_config` in `config.json`.
- Serve with vLLM; it detects compressed-tensors from the config, so `--quantization` is not needed:
  ```bash
  vllm serve ~/models/<model>-FP8-Dynamic --served-model-name <model>-fp8 \
    --host 127.0.0.1 --port 8000 --max-model-len 8192 --gpu-memory-utilization 0.85
  curl -s http://127.0.0.1:8000/health && curl -s http://127.0.0.1:8000/v1/models | jq .
  ```
  vLLM accepts `--quantization compressed-tensors` if you want to be explicit.
- SGLang: `python3 -m sglang.launch_server --model-path <dir> --host 127.0.0.1 --port 30000` (do not add an online `--quantization` on top of a pre-quantized model).

## Operating

- Calibration data matters for GPTQ, AWQ and NVFP4: use the upstream default for a first pass, then a sample of your real traffic (chat-formatted) if quality drops. Record the dataset, split and sample count in the model card.
- Run a sample generation on the quantized model before saving (the upstream examples do this) and a perplexity / smoke check after (`quality-checks.md`).
- Keep the script that produced the checkpoint and publish it alongside (it is the recipe).

## Tuning knobs worth knowing

- `ignore`: keep `lm_head` (and for MoE, router/gate layers such as `"re:.*mlp.gate$"`) unquantized, as the examples do.
- `num_calibration_samples`, `max_seq_length`: more samples / longer sequences cost time and memory; follow the examples' values first.
- Big models: load with disk offload so the sequential pipeline fits:
  ```python
  from llmcompressor.utils import load_context
  with load_context():
      model = AutoModelForCausalLM.from_pretrained(
          MODEL_ID, device_map="auto_offload",
          max_memory={"cpu": 64e9}, offload_folder="/scratch/offload")
  ```
- Mixed precision (for example NVFP4 experts + FP8 attention) via non-uniform recipes: see `examples/quantization_non_uniform` and `examples/quantizing_moe`.

## Known pitfalls

- FP8 kernels need compute capability >= 8.9; on Ampere use W4A16 instead.
- NVFP4 on pre-Blackwell runs weight-only in vLLM, so expect memory savings, not speed.
- Loading the full BF16 model on CPU needs RAM about 2 bytes x parameters; on unified-memory machines that RAM is also the GPU's. Use `auto_offload` + `offload_folder`, or a bigger machine.
- Version skew: a checkpoint made with a newer compressed-tensors may need a newer vLLM. Record versions (`pip show llmcompressor compressed-tensors transformers torch`).
- `trust_remote_code` models need the flag on both `from_pretrained` calls.

## Official links

- Repo and examples: https://github.com/vllm-project/llm-compressor
- Docs (choosing a scheme): https://docs.vllm.ai/projects/llm-compressor/en/latest/
- compressed-tensors: https://github.com/vllm-project/compressed-tensors
- vLLM quantization docs: https://docs.vllm.ai/en/latest/features/quantization/
