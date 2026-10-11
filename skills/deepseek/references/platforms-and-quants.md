# DeepSeek platforms and quants

> Verified against vLLM recipes (V4-Flash, V4.1-Flash), SGLang cookbook (V4, V4.1), Unsloth DeepSeek-V4 guide, NVIDIA and antirez model cards, TensorRT-LLM main, 2026-10-11

## Memory first

| Checkpoint                                                 | Stored size                                                                          | Source               |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------- |
| V4.1-Flash native (MXFP4 experts, MXFP8 dense, FP8 Engram) | about 511 GB (476 GiB), of which Engram tables are 183 GiB                           | vLLM V4.1 recipe     |
| V4-Flash-0731 native FP8/FP4                               | about 200 GB listed as the FP8 (0731) variant; fused DSpark checkpoints about 167 GB | vLLM V4-Flash recipe |
| V4-Flash NVFP4                                             | about 170 GB                                                                         | vLLM V4-Flash recipe |
| V4-Flash-0731 GGUF `UD-Q8_K_XL`                            | 162 GB                                                                               | Unsloth              |
| V4-Flash-0731 GGUF 3-bit (`UD-IQ3_XXS`)                    | 103 GB                                                                               | Unsloth              |
| V4-Pro                                                     | 1.6T parameters; Unsloth says Pro-0813 needs substantially more memory than Flash    | Unsloth, SGLang      |

Add KV cache on top. KV is small for V4.1 (890 bytes per token globally, about a quarter of V4-Flash), so weights set the limit.

## Platform summary

| Platform                         | V4.1-Flash                                                                                                  | V4-Flash-0731                                                                                              | V4-Pro-0813          |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------- |
| DGX Spark (GB10, 128 GB unified) | Does not fit: 476 GiB checkpoint against 2x128 GB (arithmetic from the recipe sizes; no Spark recipe found) | Two Sparks, TP=2, with a community Spark build. Single Spark only via a ~103 GB GGUF (unverified on GB10). | Not found            |
| Consumer RTX (24-32 GB)          | Not practical                                                                                               | Only as a GGUF with experts in system RAM; Unsloth lists 92 GB total memory as the 1-bit floor             | No                   |
| RTX PRO 6000 8x96 GB (sm_120)    | Fails to start on vLLM nightly (issue 59203); SGLang CUDA graph capture issue (42367)                       | vLLM TP8+EP verified without speculative decoding; DSpark needs nightly and a FlashInfer build             | Not listed           |
| Apple Silicon                    | mlx-lm `main`, MLX 2/4-bit, or antirez DwarfStar Q2 with SSD streaming on a 128 GB Mac                      | llama.cpp Metal GGUF; mlx-community V4-Flash quants                                                        | No                   |
| H100 80 GB                       | Not a supported SGLang target for V4.1; no vLLM recipe row                                                  | SGLang TP8 with Marlin; vLLM TP8+EP worked on 0.26.0 and failed at startup on 0.27.0 (issue 52065)         | SGLang 2 nodes TP16  |
| H200 141 GB                      | vLLM recipe: TP4 with Engram CPU offload; SGLang cookbook lists H200                                        | 4xH200 verified                                                                                            | 8xH200 FP4           |
| B200, B300, GB200, GB300         | TP2 (vLLM) or DEP4/DEP8; NVFP4 repo available                                                               | 8xB200, 4xGB300                                                                                            | 4xGB300, 8xB200/B300 |
| AMD MI300X to MI355X             | vLLM ROCm nightly and SGLang MI355X recipes                                                                 | vLLM and SGLang recipes                                                                                    | MI355X (SGLang)      |

## DGX Spark detail

- **V4-Flash-0731, two Sparks:** the vLLM recipe pins a community image (`eugr/spark-vllm-b12x:latest`) and sets `--tensor-parallel-size 2`, one GB10 per node, with the ConnectX network variables (`IFACE_NAME`, `IB_IF`, `HEAD_IP`). The SGLang cookbook uses `lmsysorg/sglang:dev-v4f-2dgx-v2` (FP4 or NVFP4), the same command on both nodes with `--node-rank 0/1`. Treat both images as upstream-owned.
- **NVFP4:** `nvidia/DeepSeek-V4-Flash-0731-NVFP4` runs on SM12x with extra flags listed in the cookbook (`--moe-runner-backend flashinfer_cutlass` and more); read them there.
- **Single Spark:** the only route found is the Unsloth GGUF near 103 GB through llama.cpp. DSpark adds about 10 GB. I found no GB10 measurement; verify memory headroom and speed before promising it.
- **TensorFold:** not qualified for any DeepSeek model.

## NVIDIA datacenter

- **Native checkpoint on Blackwell:** FP4 experts run directly. vLLM: `--kv-cache-dtype fp8 --block-size 256`, single node `--data-parallel-size 4 --enable-expert-parallel --moe-backend deep_gemm_mega_moe` for V4.
- **NVFP4:** `nvidia/DeepSeek-V4-Flash-0731-NVFP4`, `nvidia/DeepSeek-V4-Pro-0813-NVFP4`, `nvidia/DeepSeek-V4.1-Flash-NVFP4`. Experts NVFP4; attention, shared experts, router and the draft layer stay in the checkpoint's native formats. NVFP4 experts do not support `deep_gemm_mega_moe`, so vLLM uses its default MoE backend.
- **Hopper:** SGLang runs the original FP4 checkpoint with W4A16 kernels (Marlin or FlashInfer SM90 CUTLASS), or the FP8 repacks `sgl-project/DeepSeek-V4-Flash-FP8` and `-Pro-FP8` (H100 and H200 only) for DP-attention and DeepEP. vLLM issue 57772 notes Marlin weight-only is the only expert path on SM90 today.
- **TensorRT-LLM:** the `deepseek_v4` example documents `DeepseekV4ForCausalLM` on the PyTorch backend, Hopper (SM90) and Blackwell (SM100+); an 8xH200 or 8xB200 node is enough for Flash bring-up. No V4.1 example was found. Use `custom_tokenizer="deepseek_v4"` for Instruct. Latest TensorRT-LLM tag read: v1.3.0rc29 (pre-release).
- **KV and context:** Think Max needs at least 384K context. vLLM `--max-model-len auto` sizes to the KV pool.

## GGUF and llama.cpp

| Quant           | Size                    | Use                                                                                               |
| --------------- | ----------------------- | ------------------------------------------------------------------------------------------------- |
| `UD-Q8_K_XL`    | 162 GB                  | Lossless against the official weights (Unsloth: 1,328 tensors bit-identical). Needs about 169 GB. |
| `UD-Q4_K_XL`    | 155 GB                  | Experts bit-exact, only the 4% non-expert tensors quantized to Q8_0.                              |
| `UD-IQ3_XXS`    | 103 GB                  | Unsloth's pick for 128 GB machines; they advise at least 110 GB RAM.                              |
| 1-bit and 2-bit | 92 GB and 102 GB totals | Quality drops.                                                                                    |

Why Unsloth beats other Q4 conversions: V4's routed experts are stored in MXFP4 natively, which GGUF MXFP4 reproduces exactly, so re-quantizing the experts to Q4_K or IQ2_XXS adds error (Unsloth reports Q4_K experts at KLD 0.029 versus 0.010 for its Q4). Unsloth's note that `Q8_0` and `F16` for some tensors is not lossless is from the same page.

DSpark on GGUF needs a separate drafter GGUF and about 10 GB more memory. V4.1 GGUFs exist only for forks (antirez DwarfStar `ds4`, other community repos) because upstream PR 28696 is open; read each card, and note antirez's V4.1 GGUFs are not interchangeable with V4 weights or the V4 drafter.

## Apple Silicon

- **V4-Flash on llama.cpp:** Metal kernels for the V4 hyper-connections and lightning indexer are merged upstream. Use the Unsloth `UD-IQ3_XXS` on a 128 GB Mac only if the memory budget holds (110 GB RAM advised plus the OS).
- **V4.1-Flash:** antirez `ds41f-q2` (about 341 GiB file, 152 GiB main weights, 189 GiB FP8 Engram tables read from SSD) runs on one 128 GB Mac with `--ssd-streaming` and a fast local SSD; Q4 needs a 512 GB Mac for residency. Experimental, from `antirez/ds4`.
- **MLX:** mlx-lm `main` supports V4.1; community repos `mlx-community/DeepSeek-V4.1-Flash-MLX-4bit` and `-2bit` exist. No size check was made; V4.1 weights are huge.

## Context limits

| Model                  | Native        | Notes                                                            |
| ---------------------- | ------------- | ---------------------------------------------------------------- |
| V4.1, V4-0731/0813, V4 | 1,048,576     | V4.1 reaches 1M by YaRN factor 16 over a 65,536 training window. |
| V3.2                   | 163,840       | YaRN factor 40.                                                  |
| R1                     | 128K per card | R1-0528 benchmarks used 64K generation.                          |

## Sources

- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4-Flash>
- <https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4>
- <https://docs.sglang.io/cookbook/autoregressive/DeepSeek/DeepSeek-V4_1>
- <https://unsloth.ai/docs/models/deepseek-v4>
- <https://huggingface.co/nvidia/DeepSeek-V4.1-Flash-NVFP4>
- <https://huggingface.co/antirez/deepseek-v4.1-flash-gguf>
- <https://github.com/NVIDIA/TensorRT-LLM/blob/main/examples/models/core/deepseek_v4/README.md>
- <https://github.com/ashhart/TensorFold>
- <https://github.com/ggml-org/llama.cpp/pull/28696>
- <https://github.com/vllm-project/vllm/issues/57772>
