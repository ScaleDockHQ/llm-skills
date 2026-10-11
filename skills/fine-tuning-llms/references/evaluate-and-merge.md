# Evaluate, Merge, and Export

> Verified against huggingface/peft v0.21.2, axolotl-ai-cloud/axolotl v0.20.0 (cli.qmd, export.qmd), and ggml-org/llama.cpp b11555 (convert_lora_to_gguf.py, convert_hf_to_gguf.py), 2026-10-11

## Evaluate against the base model

Training loss going down proves nothing about usefulness. Before merging or shipping:

1. **Same held-out set, same prompts, same decoding** for base, prompted base, and fine-tuned model (temperature 0 or fixed seed).
2. **Task metric**, not just loss: exact match / schema validity / unit tests / rubric judged by a stronger model or humans. Building and gating these evals belongs to the `llm-evals` skill.
3. **Regression check:** a small general set (instruction following, safety refusals, a few unrelated tasks) to catch catastrophic forgetting.
4. **Side-by-side read** of 20-50 outputs. Look for template leakage (raw special tokens), never-ending answers (EOS not learned), over-short answers, memorized training rows.
5. **Compare checkpoints**, not just the last one; earlier checkpoints often generalize better (watch eval loss rising while train loss falls = overfitting).

Quick ways to get outputs:

- Axolotl: `axolotl inference cfg.yaml --lora-model-dir ./outputs/lora-run` (or `--chat`); `axolotl evaluate cfg.yaml` for eval loss; `axolotl lm-eval cfg.yaml` for LM Eval Harness tasks.
- Serve base + adapter with vLLM (`serving-adapters.md`) and run the eval harness against the OpenAI-compatible endpoint, using `model=<base>` vs `model=<adapter-name>` on the same server. This is the cleanest A/B.

Record: base model + revision, dataset hash, config file, commit/version of trainer, eval scores. Keep the config next to the adapter.

## Merge or keep the adapter?

| Keep adapter separate                                                         | Merge into base                                                              |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Several fine-tunes share one base (multi-LoRA serving in vLLM / llama-server) | One model, one deployment                                                    |
| Adapter is small (MBs) and easy to ship/roll back                             | Target runtime lacks adapter support (current Ollama, many hosted endpoints) |
| You'll keep iterating                                                         | You'll quantize the result (quantize _after_ merging)                        |
| Base license or terms make redistributing merged weights awkward              | Lowest inference overhead                                                    |

## Merge recipes

**Axolotl:**

```bash
axolotl merge-lora cfg.yaml                                   # writes <output_dir>/merged
axolotl merge-lora cfg.yaml --lora-model-dir ./outputs/lora-run/checkpoint-400
CUDA_VISIBLE_DEVICES="" axolotl merge-lora cfg.yaml           # CPU merge if GPU memory is short
axolotl merge-lora cfg.yaml --dequant                         # QLoRA: write bf16 instead of re-quantizing
```

**PEFT (Python):** load the base in bf16/fp16 (not 4-bit), attach the adapter, merge, save:

```python
import torch
from peft import AutoPeftModelForCausalLM
from transformers import AutoTokenizer

model = AutoPeftModelForCausalLM.from_pretrained("outputs/lora-run", torch_dtype=torch.bfloat16)
merged = model.merge_and_unload()
merged.save_pretrained("outputs/merged", safe_serialization=True)
AutoTokenizer.from_pretrained("outputs/lora-run").save_pretrained("outputs/merged")
```

**Unsloth:** `model.save_pretrained_merged("outputs/merged", tokenizer, save_method="merged_16bit")`.

Merging needs roughly the full bf16 model in memory (2 bytes x params) plus headroom. Run it memory-capped (see `hardware.md`) and with serving stopped on unified-memory machines.

After merging, check: `config.json`, tokenizer files and `chat_template` present; a quick generation matches the adapter's outputs on a few eval prompts.

## Export to GGUF (llama.cpp family)

Two routes. Quantization type choice, imatrix, and llama-quantize details belong to the `model-quantization` skill.

**A. Merged model -> GGUF** (for Ollama, LM Studio, llama.cpp without adapters):

```bash
python llama.cpp/convert_hf_to_gguf.py outputs/merged --outfile model-f16.gguf --outtype f16
# then quantize with llama-quantize (see model-quantization)
```

Or Axolotl: `axolotl export cfg.yaml --quantize Q4_K_M` (needs `$LLAMA_CPP_DIR` with a built llama.cpp; merged checkpoints only).

**B. Adapter -> GGUF LoRA** (for `llama-server --lora`, base stays a separate GGUF):

```bash
python llama.cpp/convert_lora_to_gguf.py outputs/lora-run \
  --base ~/models/<model>-hf --outfile adapter-f16.gguf --outtype f16
```

- `lora_path` (positional): directory with `adapter_config.json` + `adapter_model.safetensors`.
- `--base`: local dir with the base model's `config.json`/tokenizer (weights not needed); or `--base-model-id <org>/<model>` to fetch config from the Hub; if neither, it uses the base named in `adapter_config.json`.
- `--outtype`: `f32` (default), `f16`, `bf16`, `q8_0`, `auto`. `--dry-run` previews.
- The base GGUF can be quantized; the adapter must come from the same base architecture/revision.

Install converter deps in a **separate venv** from your trainer (llama.cpp's requirements pin older `transformers` and CPU `torch`).

## Known pitfalls

- Merging into a 4-bit base then re-quantizing: double quantization loss. Merge into bf16.
- Adapter trained on base A, served on base B (e.g. instruct vs base, different revision): degraded or garbage output with no error.
- Lost chat template after merge/convert: the runtime falls back to a default template and the fine-tune "disappears". Axolotl export warns on missing chat template.
- Added tokens without resized embeddings: vocab mismatch fails GGUF conversion (Axolotl export checks this).
- Evaluating only on training-like prompts: looks great, generalizes poorly.

## Official links

- PEFT merging (`merge_and_unload`): https://huggingface.co/docs/peft/developer_guides/lora#merge-lora-weights-into-the-base-model
- PEFT model merging guide: https://huggingface.co/docs/peft/developer_guides/model_merging
- Axolotl merge-lora: https://docs.axolotl.ai/docs/cli.html#merge-lora
- Axolotl GGUF export: https://docs.axolotl.ai/docs/export.html
- llama.cpp converters: https://github.com/ggml-org/llama.cpp (convert_hf_to_gguf.py, convert_lora_to_gguf.py)
