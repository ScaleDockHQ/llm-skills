# Models and formats

> Verified against LMDeploy v0.18.0 (docs `supported_models/supported_models.md`, `quantization/*`, `inference/turbomind_config.md`), 2026-10-11

## Choosing the engine

| Engine                        | Use when                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| TurboMind (default)           | The model is in the TurboMind table of the supported-models doc; best speed; AWQ/GPTQ 4-bit, KV int4/int8                                        |
| PyTorch (`--backend pytorch`) | Newer or unusual architectures, LoRA (`--adapters`), speculative decoding, sliding-window models (Mistral, Qwen1.5), W8A8, multi-node Ray, DP/EP |

`pipeline()` and `api_server` choose automatically with TurboMind first when it supports the model (in `api_server`
the default `--backend turbomind` runs the autodetect and falls back to PyTorch). Force PyTorch with `--backend pytorch`. The supported-models doc footnotes: TurboMind has no window attention (use PyTorch for models with
`use_sliding_window`); head_dim other than 128 (Llama3.2-1B, Qwen2-0.5B, InternVL2-1B) disables TurboMind KV 4/8-bit;
TurboMind does not support the Qwen3.5 vision encoder.

Families listed in the TurboMind table include Llama 1-3.x, InternLM2/2.5/3, Intern-S1, Qwen1.5-Qwen3.5, Mistral,
Mixtral, DeepSeek-V2/V2.5, GLM4, GLM-4.7-Flash, gpt-oss (20B, 120B), InternVL, LLaVA, MiniCPM-V, Molmo. The PyTorch
table is longer. The doc also has Ascend, Cambricon and MetaX tables. Always read the table for the exact model,
size and feature (the doc changes with each release): <https://github.com/InternLM/lmdeploy/blob/main/docs/en/supported_models/supported_models.md>.

## Weight formats

| Format                                   | How                                                                                                                       |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| FP16/BF16 (HF)                           | `--dtype auto`: FP16 for FP32/FP16 models, BF16 for BF16 models                                                           |
| AWQ 4-bit (W4A16)                        | Quantize with `lmdeploy lite auto_awq`, or use a prequantized AWQ repo; TurboMind and PyTorch support W4A16 per the table |
| GPTQ 4-bit                               | Serve existing GPTQ checkpoints (TurboMind); LMDeploy's own quantizer only does AWQ                                       |
| compressed-tensors, FP8 (blocked), MXFP4 | `--model-format compressed-tensors` (usually auto-detected), `fp8`, `mxfp4`                                               |
| SmoothQuant W8A8                         | `lmdeploy lite smooth_quant <model> --work-dir <dir> --quant-dtype int8                                                   | fp8` (INT8 on sm70+, FP8 on sm89/sm90; PyTorch engine) |
| llm-compressor output                    | Upstream has `quantization/llm_compressor.md`; read it for the supported recipes                                          |

`--model-format` choices: `hf, awq, gptq, compressed-tensors, fp8, mxfp4`.
4-bit kernels in the prebuilt package use group size 128.

### Quantize to AWQ

```bash
lmdeploy lite auto_awq internlm/internlm2_5-7b-chat \
  --calib-dataset wikitext2 --calib-samples 128 --calib-seqlen 2048 \
  --w-bits 4 --w-group-size 128 --batch-size 1 --work-dir ./internlm2_5-7b-chat-4bit
lmdeploy serve api_server ./internlm2_5-7b-chat-4bit --model-format awq --server-name 127.0.0.1
```

Upstream notes: put the model name in `--work-dir` so LMDeploy can match a built-in chat template; if accuracy drops,
re-run with `--search-scale` and a larger `--batch-size` (slower, more memory). The calibration step downloads
a dataset. Needs a GPU with enough memory for the fp16 model layers.

## KV-cache quantization (`--quant-policy`)

Online, data-free, per-head per-token asymmetric quantization (since v0.4.0). Values: `0`/`none` off, `4`/`int4`,
`8`/`int8`, `16`/`fp8`, `17`/`fp8_e5m2`, `42`/`turbo_quant` (K 4-bit QJL + V 2-bit). Upstream: int8 KV is
near lossless, int4 has slight loss; int4 and int8 raise the number of KV blocks about 4x and 2x versus fp16.
KV int4/int8 needs sm70+ and head_dim 128 on TurboMind. TurboQuant results are from upstream's own H200 benchmark:
measure on your model.

```bash
lmdeploy serve api_server Qwen/Qwen3-8B --quant-policy 8 --server-name 127.0.0.1
```

## Memory budget

KV block bytes (TurboMind) = `cache_block_seq_len * num_layer * kv_head_num * size_per_head * 2 * sizeof(kv_dtype)`.
KV pool = `free_memory_after_weights * cache_max_entry_count` (default 0.8). If `cache_max_entry_count` is an integer
above zero in the engine config it is a block count. Set `--session-len` to what you need: it caps the longest
sequence, and requests that exceed it end with `finish_reason: length`.

Long context on TurboMind: raise `--session-len` and set `--rope-scaling-factor` (>= 1.0, dynamic NTK, per
`advance/long_context.md`, example `internlm2_5-7b-chat-1m` with factor 2.5 and `--tp 4`).
