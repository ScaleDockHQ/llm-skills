# PEFT method families

> Verified against PEFT v0.21.2, 2026-10-11

PEFT's `PeftType` enum at v0.21.2 includes (non-exhaustive categories): prompt-based `PROMPT_TUNING`, `MULTITASK_PROMPT_TUNING`, `P_TUNING`, `PREFIX_TUNING`, `CPT`; layer tuning `LN_TUNING`, `TRAINABLE_TOKENS`; adapters `LORA`, `ADALORA`, `IA3`, `LOHA`, `LOKR`, `OFT`, `BOFT`, `VERA`, `FOURIERFT`, `HRA`, `VBLORA`, `RANDLORA`, `MISS`, `XLORA`, `ROAD`, `C3A`, `SHIRA`, and many newer ones. Use `from peft import PeftType; list(PeftType)` for your installed version.

Advice from the PEFT methods overview:

1. Try prompting first; if the base model already solves the task, use prompt-based methods or nothing.
2. If not, use layer tuning or adapter methods; they are more expressive and closer to full fine-tuning.
3. Measure retention of prior knowledge; each fine-tuning step can unlearn.

LoRA is the default starting point. Other methods differ in capability:

- **Quantization:** not every method supports quantized bases.
- **Features:** multiple adapters, mixed-adapter inference and merging/unmerging are not universal.
- **Layer types:** linear layers are widely supported; embedding and convolution layers less so.
- **Runtime:** most methods add overhead; merging the weights removes it where supported.

For a quality and memory comparison across methods use the PEFT method comparison suite: https://huggingface.co/spaces/peft-internal-testing/PEFT-method-comparison

## Prompt-based methods

Soft prompts (prompt tuning, p-tuning, prefix tuning) are not mergeable into base weights and cannot be activated together with other adapters (`set_adapter` with several names is not possible for prompt learning). They are mostly useful for small models and classification-style tasks; for chat LLMs LoRA is the common choice.

## Converting to LoRA

Some non-LoRA methods can be exported as a LoRA checkpoint, which downstream tools (Diffusers, vLLM) can load: check `model.supports_lora_conversion()` then `peft.save_as_lora(path, model, rank=...)`.

## Custom and non-Transformers models

`get_peft_model` works on any `nn.Module` with matching `target_modules` (MLPs, timm models). Unsupported layer types need dynamic dispatch registration (experimental in the custom models guide).
