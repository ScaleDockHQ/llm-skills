# PEFT, quantization and memory in TRL

> Verified against huggingface/trl v1.15.0 (docs: peft_integration, reducing_memory_usage, sft_trainer), huggingface/peft v0.21.2, 2026-10-11

## LoRA

All TRL trainers accept `peft_config` (a `peft.LoraConfig`). CLI shortcut: `--use_peft --lora_r 32 --lora_alpha 16`. Three ways upstream documents: CLI flags, `peft_config=` on the trainer (recommended), or wrapping the model with `get_peft_model` yourself.

Use about 10x the full-fine-tuning learning rate with LoRA (SFT tip: about 1e-4).

## QLoRA

Add `--load_in_4bit` (CLI), or load the model yourself with a `BitsAndBytesConfig` as `quantization_config` and pass it to the trainer. Upstream parameters: `bnb_4bit_quant_type` (`nf4` recommended or `fp4`), `bnb_4bit_compute_dtype` (`bfloat16` for stability), `bnb_4bit_use_double_quant`. 8-bit: `load_in_8bit=True`. Needs `bitsandbytes`.

## Memory levers (upstream "Reducing memory usage")

- **Truncation**: `max_length`; choose it from your token length distribution.
- **Packing** (SFT only, with FlashAttention variants): `packing=True`, `packing_strategy` in `bfd` (default, overflow discarded), `bfd_split` (long sequences split, no tokens lost), `wrapped` (concatenate then split, mixes examples; upstream notes it hurts quality).
- **Padding-free** (`padding_free=True`, SFT; temporarily a no-op in DPO): use with FlashAttention 2/3 to avoid batch contamination, for example `model_init_kwargs={"attn_implementation": "kernels-community/flash-attn2"}`.
- **Activation offloading**: `SFTConfig(activation_offloading=True)`.
- **Padding to a multiple**: SFT and Reward trainers.
- **vLLM sleep mode**: `vllm_enable_sleep_mode=True` in online trainers.
- **Gradient checkpointing**, including selective activation checkpointing, per the same page.
- Online methods can disable model gathering for generation under sharded setups (see the page's section).

## Save and merge

```python
trainer.save_model("out/adapter")                      # adapter + config (PEFT)
```

```python
from peft import PeftModel
from transformers import AutoModelForCausalLM
base = AutoModelForCausalLM.from_pretrained("<base-model>")
model = PeftModel.from_pretrained(base, "out/adapter").merge_and_unload()
model.save_pretrained("out/merged")
```

Merge against the same base weights you trained on (and in 16-bit, not the 4-bit copy). Hub push: `model.push_to_hub("user/name-lora")`. GGUF, quantization and serving: skills `llama-cpp`, `model-quantization`, `vllm`; serving adapters directly: `fine-tuning-llms`.
