# Schemes, algorithms and recipes

> Verified against llm-compressor 0.14.0 (docs/steps/choosing-scheme.md, choosing-algo.md, docs/guides/compression_schemes.md, docs/guides/saving_a_model.md, examples/quantization_w4a16, awq, quantization_w8a8_fp8, quantization_w8a8_int8, quantization_w4a4_fp4, quantization_w4a4_mxfp4, quantization_w4a16_fp4, quantization_w4a8_fp8, quantization_w8a8_mxfp8, quantization_kv_cache), compressed-tensors 0.19.0 (quant_scheme.py), vLLM v0.31.0, 2026-10-11

A recipe is one modifier (or a list) passed to `oneshot(recipe=...)`. A scheme is a preset string such as `"FP8_DYNAMIC"`. The workflow is: choose the model, then the scheme (numeric format), then the algorithm (how the scheme is applied).

## Choosing a scheme

From upstream's `choosing-scheme.md` (vLLM minimum compute capability for hardware-accelerated use):

| Scheme                      | Precision                       | GPU generation    | Min. compute capability | Use case                                     |
| --------------------------- | ------------------------------- | ----------------- | ----------------------- | -------------------------------------------- |
| `W4A16` / `W8A16`           | 4 or 8-bit weights, 16-bit acts | Turing and newer  | 7.5                     | Memory reduction, works on any of these GPUs |
| `W8A8` (INT8)               | INT8 weights and activations    | Turing and newer  | 7.5                     | Throughput on older hardware                 |
| `FP8_DYNAMIC` / `FP8_BLOCK` | FP8 weights and activations     | Ada and newer     | 8.9                     | Throughput on modern GPUs                    |
| `W4AFP8`                    | 4-bit weights, FP8 activations  | Hopper            | 9.0                     | Low-bit weights with FP8 activations         |
| `NVFP4`                     | FP4 (NVIDIA), weights + acts    | Blackwell (SM100) | 10.0                    | Maximum compression                          |
| `MXFP4` / `MXFP8`           | OCP MX FP4 / FP8                | Blackwell (SM100) | 10.0                    | Cross-platform MX formats                    |

Per upstream's hardware guidance: Blackwell NVFP4/MXFP4 (alternative MXFP8 or FP8), Hopper `FP8` (alternative W4AFP8), Ampere W4A16 (alternative INT8 W8A8), Turing INT8 W8A8 (alternative W4A16). vLLM's own docs add: FP8 models run on compute capability 7.5 and newer as weight-only W8A16 through Marlin; NVFP4 on GPUs without a native FP4 kernel falls back to weight-only Marlin (see `vllm-integration.md`). A checkpoint that loads is not a checkpoint that is fast.

Preset names accepted by `scheme=` in compressed-tensors 0.19.0: `W4A16`, `W4A16_ASYM`, `W8A16`, `W8A8` (alias `INT8`), `W4AFP8`, `FP8`, `FP8_DYNAMIC`, `FP8_BLOCK`, `NVFP4`, `NVFP4A16`, `MXFP4`, `MXFP4A16`, `MXFP8`, `MXFP8A16`, plus generic `WxAy` presets (`W2`..`W7`, `A4`/`A8`/`A16`) and `UNQUANTIZED`. Scheme-specific details:

- `FP8_DYNAMIC`: per-channel weights, dynamic per-token activations. Data-free with RTN.
- `FP8_BLOCK`: block-wise weights (commonly 128x128), dynamic per-group (128) activations. Data-free with RTN.
- `W4A16`: group quantization, group size 128 in the upstream example name (`-W4A16-G128`). Best with GPTQ or AWQ.
- `NVFP4`: global scale per tensor, local scales per group of 16, scales in FP8 E4M3. Needs calibration data for the activation global scales.
- `MXFP4` / `MXFP8`: group size 32 with E8M0 scales. Data-free with RTN.
- `FP8` (static): per-tensor activation scales need a calibration dataset.

Sparse (2:4) compression is no longer supported by LLM Compressor, per upstream docs.

## Choosing an algorithm

| Algorithm        | Modifier                                 | Data                                         | Notes                                                                 |
| ---------------- | ---------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------- |
| RTN              | `QuantizationModifier`                   | no (unless static activation scales / NVFP4) | Fast; good for FP8 and FP4, moderate elsewhere                        |
| GPTQ             | `GPTQModifier`                           | yes                                          | Second-order, high recovery, expensive; allocates a Hessian per layer |
| AWQ              | `AWQModifier` (+ `QuantizationModifier`) | yes                                          | Activation-aware rescaling, high recovery, can be expensive           |
| SmoothQuant      | `SmoothQuantModifier` (+ GPTQ)           | yes                                          | Moves activation outliers into weights; pair with INT8 W8A8           |
| AutoRound        | `AutoRoundModifier`                      | yes                                          | Sign-gradient rounding optimisation; see `examples/autoround`         |
| SpinQuant / QuIP | transforms (`examples/transform`)        | yes                                          | Rotations for best low-bit accuracy; combine with GPTQ                |
| REAP             | `REAPPruningModifier`                    | yes                                          | MoE expert pruning, not dense sparsity                                |

Rule of thumb from upstream: RTN for FP8, GPTQ or AWQ for 4-bit integer or FP4, SmoothQuant for INT8 W8A8. Start with the cheapest algorithm that meets the quality gate.

## Common script skeleton

```python
from compressed_tensors.offload import dispatch_model
from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "<org>/<model>"  # or a local path
model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

recipe = ...  # one of the recipes below

oneshot(model=model, recipe=recipe)  # add dataset= etc. for calibrated recipes

dispatch_model(model)  # sample generation, as in the upstream examples
ids = tokenizer("Hello my name is", return_tensors="pt").input_ids.to(model.device)
print(tokenizer.decode(model.generate(ids, max_new_tokens=20)[0]))

SAVE_DIR = MODEL_ID.rstrip("/").split("/")[-1] + "-<SCHEME>"
model.save_pretrained(SAVE_DIR, save_compressed=True)
tokenizer.save_pretrained(SAVE_DIR)
```

`oneshot(..., output_dir=DIR)` can save for you instead. `save_compressed` defaults to `True`; `quantization_format=` overrides the inferred on-disk format (for example `"pack-quantized"` in the W4AFP8 example). For very large models skip the sample generation or use few tokens, since it onloads offloaded weights.

## Recipes

All taken from the 0.14.0 examples; replace `MODEL_ID`. Imports not shown above are listed per recipe.

### FP8 dynamic (data-free)

```python
recipe = QuantizationModifier(targets="Linear", scheme="FP8_DYNAMIC", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)
```

### FP8 block (data-free; MoE-friendly ignore list)

```python
recipe = QuantizationModifier(
    targets="Linear", scheme="FP8_BLOCK", ignore=["lm_head", "re:.*mlp.gate$"]
)
oneshot(model=model, recipe=recipe)
```

### INT4 W4A16 with GPTQ

```python
from llmcompressor.modifiers.gptq import GPTQModifier

recipe = GPTQModifier(targets="Linear", scheme="W4A16", ignore=["lm_head"])
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=512)
# save with save_compressed=True; example output name: <model>-W4A16-G128
```

### INT4 with AWQ (asymmetric)

```python
from llmcompressor.modifiers.transform.awq import AWQModifier

recipe = [
    AWQModifier(duo_scaling="both"),
    QuantizationModifier(ignore=["lm_head"], scheme="W4A16_ASYM", targets=["Linear"]),
]
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=512, num_calibration_samples=256)
```

The `awq` examples folder also has `fp8_dynamic_llama_example.py`, `fp8_block_llama_example.py` and `w4a8_fp8_llama_example.py` (AWQ combined with other schemes) and a `RESULTS.md`.

### INT8 W8A8 with SmoothQuant + GPTQ

```python
from llmcompressor.modifiers.gptq import GPTQModifier
from llmcompressor.modifiers.transform.smoothquant import SmoothQuantModifier

recipe = [
    SmoothQuantModifier(smoothing_strength=0.8),
    GPTQModifier(targets="Linear", scheme="W8A8", ignore=["lm_head"]),
]
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=512)
```

### NVFP4 (weights + activations; needs data)

```python
recipe = QuantizationModifier(targets="Linear", scheme="NVFP4", ignore=["lm_head"])
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=20)
```

Upstream's example uses only 20 calibration samples for NVFP4 because the data only calibrates activation global scales. The `quantization_w4a4_fp4` folder also has `llama3_gptq_example.py` and `qwen3_8_gptq_awq_example.py` (GPTQ or AWQ before NVFP4), which upstream says can recover more accuracy than RTN. Raise samples if the quality gate fails.

### NVFP4A16, MXFP4, MXFP8 (data-free)

```python
recipe = QuantizationModifier(targets="Linear", scheme="NVFP4A16", ignore=["lm_head"])   # weights FP4, acts 16-bit
recipe = QuantizationModifier(targets="Linear", scheme="MXFP4", ignore=["lm_head"])
recipe = QuantizationModifier(targets="Linear", scheme="MXFP8", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)
```

Per upstream's dataset guide, if no calibration data is available, MXFP4 with RTN is the data-free alternative to NVFP4, with likely poorer accuracy recovery.

### W4AFP8 (Hopper)

```python
recipe = GPTQModifier(targets="Linear", scheme="W4AFP8", ignore=["lm_head"])
oneshot(model=model, dataset="perfectblend", splits="train[:512]", recipe=recipe,
        max_seq_length=2048, num_calibration_samples=512)
model.save_pretrained(SAVE_DIR, save_compressed=True, quantization_format="pack-quantized")
```

### FP8 KV cache (static per-tensor, needs data)

Upstream's example passes a YAML recipe string (`quant_stage` / `quant_modifiers` / `QuantizationModifier`) with a `config_groups` block for weights and input activations and a `kv_cache_scheme` of 8-bit float, per-tensor, static, symmetric. Copy it from `examples/quantization_kv_cache/llama3_fp8_kv_example.py`; `llama3_fp8_head_kv_example.py` in the same folder does per-attention-head scales, which vLLM supports only with the Flash Attention backend (`vllm-integration.md`).

### Mixed precision, multimodal, attention

`examples/quantization_non_uniform` (different schemes per layer group), `examples/multimodal_vision`, `examples/multimodal_audio`, `examples/quantization_attention` (FP8 attention). Multimodal: the non-text tower is not quantized (upstream FAQ), so list it in `ignore` when its linear layers match `targets="Linear"`.

## Targets and ignore

- `targets="Linear"` quantizes every `nn.Linear` except those matched by `ignore`.
- `ignore` takes exact module names and `re:`-prefixed regexes, for example `["lm_head", "re:.*mlp.gate$"]`.
- Upstream FAQ: quantize all linear layers except `lm_head`; MoE gates and routers are sensitive, so ignore them too.

## Quick self-check after saving

Run `scripts/inspect-checkpoint.sh <SAVE_DIR>`: it should show `quant_method` `compressed-tensors`, the expected scheme, and `lm_head` in the ignore list. Then serve it (`vllm-integration.md`).
