# GPT-QModel with vLLM

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

Goal: quantize a BF16 model to GPTQ 4-bit with GPT-QModel, check it, and serve it with vLLM.

## 1. Quantize (venv A, with gptqmodel)

Use the script from `quantize.md` with `GPTQConfig(bits=4, group_size=128)`, a workload-like calibration set and `model.save("~/models/<name>-gptq-4bit")`. Keep `format` at `gptq` (vLLM picks its Marlin path on NVIDIA by itself).

## 2. Check

```bash
jq '.quantization_config' ~/models/<name>-gptq-4bit/config.json
```

Run Evalution or your own task set against the original and the quant (`evaluate-and-adapters.md`).

## 3. Serve (venv B, with vllm)

```bash
vllm serve ~/models/<name>-gptq-4bit --host 127.0.0.1 --port 8000
curl -s http://127.0.0.1:8000/v1/models | jq '.data[].id'
```

Further flags (max length, parallelism, tool parsers): `vllm` skill. Do not use `dynamic` overrides for vLLM targets unless you have verified loading.

## Pitfalls

- Install gptqmodel and vllm in separate environments, since their torch pins differ.
- A different `transformers` version in the serving venv may change tokenizer behavior; keep the tokenizer files from the source model.
- Re-quantize after a source model revision; an old calibration or config does not transfer.
