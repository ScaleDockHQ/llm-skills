# HQQ troubleshooting

> Verified against hqq v0.2.8.post1 (README, Transformers HQQ guide), 2026-10-11

| Symptom                                                            | Cause and fix                                                                                                                                                                                |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `from_pretrained` fails on a directory saved with `save_quantized` | The hqq library's own format is not Transformers-compatible. Use `AutoHQQHFModel.from_quantized`, or re-export with `save_to_safetensors`.                                                   |
| Saving after `prepare_for_inference` gives a broken checkpoint     | Save before patching, as upstream warns. Reload and save again.                                                                                                                              |
| Fused backend does not speed things up                             | Unsupported settings fall back to the native backend. Use `axis=1`, `nbits=4` (or 2/1 for GemLite), the right compute dtype (fp16 GemLite, bf16 `torchao_int4`), and a supported group size. |
| `ATEN` backend errors                                              | It supports only `axis=0`.                                                                                                                                                                   |
| CUDA kernel build fails during install                             | Set `DISABLE_CUDA=1` to skip building the aten kernels, or match PyTorch's CUDA version with the toolkit.                                                                                    |
| `group_size` error                                                 | `weight.numel()` must be divisible by `group_size`.                                                                                                                                          |
| Gibberish at 3, 2 or 1 bit                                         | Expected degradation; raise bits for sensitive layers with a per-layer config, use `axis=0`, or train HQQ+ adapters.                                                                         |
| vLLM on-the-fly path fails                                         | Install GemLite, set the quant mode before creating `LLM`, skip `lm_head` and vision modules, and test with the exact vLLM version.                                                          |

Open issues at https://github.com/dropbox/hqq/issues with `pip freeze` for hqq, torch, transformers.
