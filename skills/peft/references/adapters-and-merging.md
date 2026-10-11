# Saving, loading, combining and merging adapters

> Verified against PEFT v0.21.2, 2026-10-11

## Files

`peft_model.save_pretrained(dir)` writes:

1. `adapter_model.safetensors` (or `.bin`): only adapter weights; tiny compared with the base.
2. `adapter_config.json`: `peft_type`, `base_model_name_or_path`, `target_modules`, hyperparameters.
3. `README.md`: model card, not needed for loading.

The base model must be available to load the adapter. Push with `peft_model.push_to_hub("<org>/<name>")` (needs login via `HF_TOKEN`; ask first).

## Load

```python
from transformers import AutoModelForCausalLM
from peft import PeftModel

base = AutoModelForCausalLM.from_pretrained("<org>/<model>")
model = PeftModel.from_pretrained(base, "out/adapter")                   # inference
model = PeftModel.from_pretrained(base, "out/adapter", is_trainable=True)  # continue training
```

`from_pretrained(model, model_id, adapter_name="default", is_trainable=False, config=None, autocast_adapter_dtype=True, ephemeral_gpu_offload=False, low_cpu_mem_usage=False, key_mapping=None)`. The base may be modified in place. Load the same base revision and, if you added tokens, resize embeddings the same way before loading; see the troubleshooting reference.

## Several adapters

```python
model = PeftModel.from_pretrained(base, path_0)           # adapter "default"
model.load_adapter(path_1, adapter_name="other")          # loaded but inactive
model.set_adapter("other")                                # switch to one
model.base_model.set_adapter(["default", "other"])        # activate several (not for prompt learning)
with model.disable_adapter():                             # base behavior
    ...
```

Train two adapters at once only after activating both (inactive adapters have `requires_grad=False` and the optimizer ignores them). Different adapter types on one model need `mixed=True` / `PeftMixedModel`.

## Hot-swap

`peft.utils.hotswap.hotswap_adapter(model, path, adapter_name="default", torch_device=device)` replaces adapter weights in place without recompiling a `torch.compile`d model; with compile call `prepare_model_for_compiled_hotswap(model, target_rank=max_rank)` first (see the hotswap reference).

## Weighted combination

LoRA adapters can be combined with `model.add_weighted_adapter(adapters, weights, adapter_name, combination_type=..., density=...)` (types include `"ties"` and `"dare_ties"` with a `density`). (IA)³ uses the same method without `combination_type`. Evaluate the result; merging quality is task-dependent.

## Merge into the base

```python
merged = model.merge_and_unload()      # NOT in place: use the returned model
merged.save_pretrained("out/merged")
tokenizer.save_pretrained("out/merged")
```

`merge_and_unload(progressbar=False, safe_merge=False, adapter_names=None)`; `safe_merge=True` checks for NaN before merging. Caveats from the checkpoint guide:

- The result is a plain model: no unmerge, no multiple adapters, no disabling.
- Not all methods support merging, and some only without particular quantization settings.
- The full model is large; check disk space first.
- Merged inference is slightly faster; DoRA in particular benefits from merging.

To merge, load the base in bf16/fp16 (not a quantized one) on CPU or GPU with enough memory. Verify by comparing generations of `model` and `merged` on the same prompts. For GGUF conversion use `llama-cpp`/`gguf-quantization`; for serving use `vllm`.

## Other storage routes

- Keep serving adapters separately: engines such as vLLM load LoRA adapters directly (skill `vllm`).
- LoRA only: a documented trick inserts PEFT weights into a Transformers model and saves it as a plain Transformers checkpoint (checkpoint guide, "Convert to a Transformers model").
- Non-LoRA methods that support it can be exported with `save_as_lora`.
