# 8-bit and paged optimizers

> Verified against bitsandbytes 0.50.2 (docs optimizers.mdx, bitsandbytes/optim/**init**.py, Transformers integration), 2026-10-11

8-bit optimizers are drop-in replacements that keep optimizer state in 8-bit (block-wise quantization). Upstream states about 75% less optimizer memory without accuracy loss; the saving is proportional to parameter count, so activation-heavy models such as convolutional networks gain little.

```diff
- adam = torch.optim.Adam(params, lr=1e-4)
+ adam = bnb.optim.Adam8bit(params, lr=1e-4)
# NLP models, recommended upstream:
- torch.nn.Embedding(...)
+ bnb.nn.StableEmbedding(...)
```

## Available classes

`bnb.optim` exports `Adagrad`, `Adam`, `AdamW`, `AdEMAMix`, `LAMB`, `LARS`, `Lion`, `RMSprop`, `SGD`, each with `8bit` and `32bit` variants (for example `Adam8bit`, `AdamW32bit`). Adam, AdamW, AdEMAMix and Lion also have `Paged*` variants (for example `PagedAdamW8bit`). Paged optimizers page state between GPU and CPU to absorb memory spikes.

## Tuning

- Tensors with fewer than 4096 elements stay in 32-bit by default. Change with `min_8bit_size` (multiples of 4096 are recommended).
- `optim_bits=32` forces a 32-bit state for a plain optimizer class.
- Keep an unstable tensor in 32-bit while the rest is 8-bit:

```python
mng = bnb.optim.GlobalOptimManager.get_instance()
mng.register_parameters(model.parameters())   # while on CPU
model = model.cuda()
adam = bnb.optim.Adam(model.parameters(), lr=1e-3, optim_bits=8)
mng.override_config(model.fc1.weight, "optim_bits", 32)
```

Per-module overrides use `register_module_override(self, "weight", {"optim_bits": 32, "lr": 1e-4})` inside the module's `__init__`.

## Hugging Face Trainer

Pass the string in `TrainingArguments(optim=...)`, for example `paged_adamw_32bit` (upstream's example) or `paged_adamw_8bit`. Check the accepted names against your installed Transformers (`python3 -c "from transformers.training_args import OptimizerNames as O; print([o.value for o in O if 'bnb' in o.name.lower() or 'paged' in o.value or '8bit' in o.value])"`).

## Support

8-bit optimizers need NVIDIA compute capability 6.0+, and are not supported on Intel Gaudi (`install.md`).
