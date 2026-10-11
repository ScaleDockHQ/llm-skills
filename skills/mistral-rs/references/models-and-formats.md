# Models and formats

> Verified against mistral.rs v0.9.4 (docs `reference/supported-models`, `guides/quantization/quantize-a-model`, `reference/gguf-support`, `guides/models/*`), 2026-10-11

## Is my model supported?

The architecture is auto-detected from `config.json` `architectures`. Read that field on the model page and match it to
`reference/supported-models` upstream (generated from the loader registry, so it is the authoritative list). Representative
families in v0.9.4:

- **Text:** Mistral, Mixtral, Llama 2/3.x, Gemma 1/2, Phi-2/3/3.5 and Phi-3.5-MoE, Qwen2/2.5/3, Qwen3 MoE, Qwen3-Next and
  Qwen3-Coder-Next, Qwen3.5, DeepSeek-V2/V3/R1, GLM-4 and GLM-4.7, GPT-OSS, SmolLM3, Granite 4.0, HunYuan, LFM2/2.5, Starcoder2.
- **Multimodal:** Gemma 3/3n/4, Qwen2-VL/2.5-VL/3-VL, Qwen3.5/3.6 (vision), Llama 3.2 Vision and Llama 4, Mistral Small 3,
  Phi-3.5-Vision and Phi-4-multimodal, Idefics2/3, LLaVA, MiniCPM-o, Voxtral (speech input).
- **Other kinds:** embeddings, image generation (diffusion), speech (TTS), block diffusion. See `guides/models/` upstream.

Unlisted architecture: check `reference/gguf-support`, then the upstream issue tracker. `--arch` only helps when the checkpoint
matches a known architecture. `mistralrs serve` with the default `auto` kind picks text vs multimodal itself.

```bash
mistralrs run -m <model>            # first run downloads weights, then chat
mistralrs tune -m <model>           # table: Quant | Est. Size | VRAM % | Context Room | Quality | Status
```

## What `--quant` does

`--quant 4` is resolved in this order (docs):

1. Look for a prebuilt UQFF at `mistralrs-community/<model>-UQFF` matching the bit width and load it directly.
2. Otherwise fall back to ISQ (in-situ quantization) while loading: Q4K on CUDA/CPU, AFQ4 on Metal. The full unquantized
   model is never resident, but loading takes longer.
3. A local safetensors directory skips the UQFF probe and applies ISQ. A local directory with GGUF files selects a matching GGUF.

| Flag                               | Meaning                                                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `--quant 2,3,4,5,6,8`              | Bit width; weights shrink roughly linearly (BF16 14B is about 28 GB, at 4 bits about 7 GB)                   |
| `--quant auto`                     | Same analysis as `tune` (balanced profile); no quantization if it fits at full precision; never picks a GGUF |
| `--quant q4k`, `afq4`, `q8_0`, ... | A named format (`reference/quantization-types` has hardware constraints)                                     |
| `--isq <type>`                     | Force runtime ISQ and skip the UQFF lookup; for GGUF it requantizes the exact `-f` file                      |
| `--from-uqff <file or level>`      | Load a specific UQFF artifact                                                                                |
| `--imatrix`, `--calibration-file`  | Importance matrix for K-quants at low bit widths                                                             |
| `--isq-organization moqe`          | MoE-only quantization variant (default `default`)                                                            |

Quality depends on model and workload; test the chosen width on your tasks. KV cache memory is a separate budget (context
length, not weight bits).

## GGUF

```bash
mistralrs serve -m unsloth/Qwen3-4B-GGUF --quant 4        # pick a variant from a GGUF repo
mistralrs serve -f /models/model-q4_k_m.gguf --tok-model-id Qwen/Qwen3-4B   # local file, tokenizer from the base repo
```

The filename suffix selects the format. Multimodal GGUF repos with an unambiguous projector pick up the `mmproj` file
automatically; override with `--mmproj`. Dynamic LoRA works on supported GGUF text models.

## UQFF (Universal Quantized File Format)

Pre-quantized artifacts load in minutes instead of quantizing on every start and are the recommended way to ship an ISQ
result. Produce one with `mistralrs quantize` (`guides/quantization/uqff` upstream), publish privately, and load with
`--from-uqff`. UQFF used with `--mtp` must include the `mtp.*` tensors.

## KV cache quantization

`--pa-cache-type f8e4m3` stores the paged KV cache in FP8 to cut KV memory at some quality risk (default
`auto`). Only applies with paged attention.

## Memory budget

Weights (bits per parameter) + KV pool + activations. `--pa-memory-fraction`, `--pa-memory-mb`, or `--pa-context-len` size the
KV pool; without them paged attention uses 90% of available VRAM, which collides with other GPU tenants (a second model, a
display, ComfyUI). On CUDA integrated-GPU systems (GB10 and similar) the usable share is `MISTRALRS_IGPU_MEMORY_FRACTION`
(default 0.75). Apple Silicon uses unified memory with no multi-GPU split; leave headroom for the OS.

CPU offload: automatic device mapping places layers on the CPU when the model does not fit; CPU layers run at f32
internally, so partial offload is slow. Automatic mapping is sized from `--max-seq-len` (4096) and `--max-batch-size` (1),
not from your serving `--max-seqs`.

## Gated and private repos

Accept the license on the model page, then authenticate with `mistralrs login` (token must start with `hf_`; saved under
`$HF_HOME/token`, default `~/.cache/huggingface/token`) or export `HF_TOKEN` from a `0600` file. The CLI has no model revision flag:
IDs resolve to `main`. To pin, download the snapshot yourself at a commit and pass the local directory to `-m`.

## Model family notes

Per-family quantization, thinking and tool-call behaviour lives in `guides/models/model-family-notes` upstream. Check it for
the specific family before assuming defaults (for example MLA for DeepSeek, hybrid recurrent layers for Qwen3-Next/3.5).
