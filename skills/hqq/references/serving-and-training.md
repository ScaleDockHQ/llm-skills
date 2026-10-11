# Saving, serving and training with HQQ

> Verified against hqq v0.2.8.post1 (README, examples directory) and Transformers HQQ guide (main), 2026-10-11

## Save and load

| Path                                 | Save                                                              | Load                                        |
| ------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------- |
| Transformers `HqqConfig`             | `model.save_pretrained(dir)`                                      | `AutoModelForCausalLM.from_pretrained(dir)` |
| hqq library                          | `AutoHQQHFModel.save_quantized(model, dir)` (before any patching) | `AutoHQQHFModel.from_quantized(dir)`        |
| Safetensors for Transformers or vLLM | `AutoHQQHFModel.save_to_safetensors(model, dir)`                  | `from_pretrained`                           |

Models saved with the hqq library's own format are not loadable with `from_pretrained()`. Hub uploads need the user's approval and a token in the environment.

## vLLM

On-the-fly quantization (install GemLite first, set before creating `LLM`):

```python
from hqq.utils.vllm import set_vllm_onthefly_hqq_quant
skip = ["lm_head", "visual", "vision"]
set_vllm_onthefly_hqq_quant(weight_bits=4, group_size=128, quant_mode="int4_weightonly", skip_modules=skip)
llm = LLM(model="meta-llama/Llama-3.2-3B-Instruct", max_model_len=4096, gpu_memory_utilization=0.80, dtype=torch.float16)
```

Upstream lists these `quant_mode` values: `int8_weightonly` (8 bit), `int4_weightonly` (HQQ 4 bit), `int8_dynamic`, `fp8_dynamic`, `mxfp8_dynamic`, `mxfp4_weightonly`, `mxfp4_dynamic`, `nvfp4_dynamic`; weight_bits 4 or 8 pairs per mode as in the README. Examples: `examples/vllm.py` and `vllm_qwenvl.py` in the repo. Engine tuning belongs to `vllm`; a safetensors export is the other route. Test the vLLM version in use, since this path is out-of-tree.

## Training

- Transformers PEFT supports HQQ directly (PEFT quantization guide); use PEFT LoRA on an `HqqConfig` model like any quantized base (`bitsandbytes` skill shows the QLoRA pattern; `trl` for trainers).
- hqq-lib utilities: `PeftUtils.add_lora(model, {"self_attn.q_proj": {"lora_type": "default", "r": 32, "lora_alpha": 64, "dropout": 0.05, "train_dtype": torch.float32}, "mlp.gate_proj": None, ...})`, set `HQQLinear.set_backend(HQQBackend.ATEN if axis == 0 else HQQBackend.PYTORCH_COMPILE)`, train, `model.eval()`, `PeftUtils.cast_lora_weights(model, dtype=compute_dtype)`, `PeftUtils.save_lora_weights(model, filename)` and `load_lora_weights`. Full example: `examples/hqq_plus.py`.
- HQQ+ means HQQ with trainable low-rank adapters, to recover quality at lower bits.
- Multi-GPU: upstream points to Answer.AI's `fsdp_qlora` repository.
