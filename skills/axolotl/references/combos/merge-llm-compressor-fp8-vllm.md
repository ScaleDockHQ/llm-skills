# Axolotl LoRA to FP8 with LLM Compressor and vLLM

> Verified against axolotl v0.20.0, llm-compressor 0.14.0 and vLLM v0.31.0, 2026-10-11

Goal: take a LoRA adapter trained with Axolotl, merge it into the base, quantize the merged bf16 model to FP8 with LLM Compressor, and serve it with vLLM. Use this when you want one self-contained, faster-to-serve checkpoint rather than a base plus adapter.

Install the other skills for depth: `npx skills add ScaleDockHQ/llm-skills --skill llm-compressor`, `--skill vllm`.

## 1. Merge (Axolotl venv)

```bash
axolotl merge-lora cfg.yml            # writes <output_dir>/merged
# QLoRA runs: add --dequant to get a bf16 checkpoint instead of re-quantizing to 4-bit
ls "$(grep -E '^output_dir:' cfg.yml | awk '{print $2}')/merged"
```

Check the merged directory has safetensors, `config.json`, tokenizer files and the chat template. Merging a QLoRA adapter without `--dequant` keeps the quantized format, which LLM Compressor cannot re-quantize.

## 2. Quantize (separate venv)

Install LLM Compressor in its own venv; do not share the Axolotl or vLLM environment (their `transformers` and `torch` pins collide).

```bash
python3 -m venv ~/venvs/llmc && . ~/venvs/llmc/bin/activate
pip install llmcompressor
```

Recipe from the upstream `examples/quantization_w8a8_fp8/llama3_example.py` (FP8 weights per channel, dynamic per-token activations, no calibration data):

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_DIR = "outputs/lora-run/merged"          # the Axolotl merged dir
model = AutoModelForCausalLM.from_pretrained(MODEL_DIR)
tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)

recipe = QuantizationModifier(targets="Linear", scheme="FP8_DYNAMIC", ignore=["lm_head"])
oneshot(model=model, recipe=recipe)

SAVE_DIR = "outputs/lora-run-FP8-Dynamic"
model.save_pretrained(SAVE_DIR)                # compressed-tensors format
tokenizer.save_pretrained(SAVE_DIR)
```

Run it as a script (for example `quantize_fp8.py`) memory-capped on shared hosts: `systemd-run --user --scope -p MemoryMax=96G -p MemorySwapMax=0 -- python quantize_fp8.py`. FP8 targets GPUs with compute capability 8.9 or newer (Ada, Hopper, Blackwell); this threshold comes from the sibling `model-quantization` reference and was not re-read upstream here (unverified).

## 3. Serve (vLLM venv)

vLLM detects compressed-tensors from `config.json`, so no `--quantization` flag is needed:

```bash
vllm serve outputs/lora-run-FP8-Dynamic --served-model-name my-model-fp8 \
  --host 127.0.0.1 --port 8000 --max-model-len 8192 --gpu-memory-utilization 0.85
curl -s http://127.0.0.1:8000/health && curl -s http://127.0.0.1:8000/v1/models | jq .
```

## Pitfalls

- Merge first, quantize second. Quantizing a base and then loading a bf16 adapter on it is not this recipe; for adapters on a quantized base see the `vllm` skill.
- The chat template must survive the merge and the quantize (`tokenizer.save_pretrained`). Compare a few prompts before and after.
- A checkpoint made with a newer compressed-tensors may need a newer vLLM; record `pip show llmcompressor compressed-tensors transformers torch` and the vLLM version next to the model.
- Compare against the unquantized merged model on your eval set before shipping (skill `llm-evals`).
