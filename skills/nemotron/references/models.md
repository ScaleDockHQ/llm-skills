# Nemotron models

> Verified against the nvidia/* model cards on Hugging Face, Hugging Face API metadata, the NVIDIA Nemotron collection page and the Ollama library, 2026-10-11

## Current generations

All Nemotron 3 language models are hybrid Mamba-2 + MoE + a few attention layers (architecture `NemotronHForCausalLM`
in vLLM, `nemotron_h_moe` in llama.cpp). Sizes below are the summed `*.safetensors` or `*.gguf` file sizes on the Hub.

| Model                                                              | Params (total / active)                                                       | Released   | Context (card)                           | Official checkpoints (size)                                                                          | License                            |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------- | ---------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------- |
| **Nemotron 3.5 Lightning** `NVIDIA-Nemotron-3.5-Lightning-30B-A3B` | 30B / 3B, MTP layers                                                          | 2026-08-11 | up to 1M                                 | BF16 (65.8 GB), NVFP4 (21.5 GB), Base-BF16, drafters NVFP4-DSpark (1.3 GB) and NVFP4-DFlash (1.1 GB) | OpenMDW 1.1                        |
| **Nemotron 3 Ultra** `NVIDIA-Nemotron-3-Ultra-550B-A55B`           | 550B / 55B, LatentMoE, MTP                                                    | 2026-06-04 | up to 1M                                 | BF16 (1121 GB), NVFP4 (352 GB), Base-BF16, GenRM                                                     | OpenMDW 1.1                        |
| **Nemotron 3 Super** `NVIDIA-Nemotron-3-Super-120B-A12B`           | 120B / 12B, LatentMoE, MTP                                                    | 2026-03-11 | up to 1M                                 | BF16, FP8 (128 GB), NVFP4 (80 GB), Base-BF16; separate `Nemotron-3-Super-120B-A12B-BF16-MTPv2` head  | NVIDIA Nemotron Open Model License |
| **Nemotron 3 Nano** `NVIDIA-Nemotron-3-Nano-30B-A3B`               | 30B / 3.5B (card text)                                                        | 2025-12-15 | up to 1M (256k default in recipes)       | BF16 (63.1 GB), FP8 (32.6 GB), NVFP4 (19.3 GB), Base-BF16                                            | NVIDIA Nemotron Open Model License |
| **Nemotron 3 Nano 4B** `NVIDIA-Nemotron-3-Nano-4B`                 | 3.97B dense hybrid (Mamba-2 + 4 attention layers), compressed from Nano 9B v2 | 2026-03-16 | 262K                                     | BF16 (7.9 GB), FP8 (5.2 GB), GGUF Q4_K_M (2.8 GB)                                                    | NVIDIA Nemotron Open Model License |
| **Nemotron 3 Nano Omni** `Nemotron-3-Nano-Omni-30B-A3B-Reasoning`  | 30B / ~3B plus CRADIO v4-H vision and Parakeet audio encoders                 | 2026-04-28 | 131,072 in recipes (vLLM blog says 256K) | BF16, FP8, NVFP4 (22.4 GB)                                                                           | see card (not re-read)             |

Notes:

- The Ultra card lists 10 languages (English, French, Spanish, Italian, German, Japanese, Hindi, Korean, Brazilian
  Portuguese, Chinese); Super lists 7; Lightning lists English plus Spanish, French, German, Italian, Japanese.
- Model cards say "up to 1M" tokens. The deployment snippets differ: Lightning's vLLM recipes serve 1M by default
  (the H100 and GB200 snippets), Super, Ultra and Nano default to 262144 and need `VLLM_ALLOW_LONG_MAX_MODEL_LEN=1`
  plus `--max-model-len 1048576` for 1M.
- Lightning, Super and Ultra were pre-trained with an NVFP4 recipe. Ultra and Super use LatentMoE; Lightning is
  plain MoE.

## Labs and derived variants (listed, cards not re-read)

| Repo                                                               | What it is (from Hub metadata)                                                                               |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `nvidia/NVIDIA-Nemotron-Labs-3-Puzzle-75B-A9B-{BF16,FP8,NVFP4}`    | Derived from Super (`base_model` Super BF16), OpenMDW 1.1, created 2026-06-24                                |
| `nvidia/NVIDIA-Nemotron-Labs-3-Elastic-30B-A3B-{BF16,FP8,NVFP4}`   | Derived from Nano 30B, NVIDIA open model license, created 2026-04-14                                         |
| `nvidia/NVIDIA-Nemotron-Labs-3-Competitive-Coding-550B-A55B-NVFP4` | Competitive-coding variant of Ultra size, OpenMDW 1.1, created 2026-09-04                                    |
| `nvidia/Nemotron-Cascade-2-30B-A3B`                                | 30B-A3B reasoning model, created 2026-03-18. A vLLM issue reports it also uses the `qwen3_coder` tool parser |

Treat these as unverified: read their cards before serving them.

## Legacy: Llama-Nemotron and Nemotron 4

Still on the Hub, not current. NVIDIA's collection page lists Llama-3.1-Nemotron Ultra (253B), Super (49B) and Nano
(8B) as community collaborations built on Llama.

| Repo                                                      | Notes                                                                                                                                                                                                                                      |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `nvidia/Llama-3_3-Nemotron-Super-49B-v1_5` (+ FP8, NVFP4) | Derived from Llama-3.3-70B-Instruct, 131,072 context, NVIDIA Open Model License plus the Llama 3.3 Community License. Reasoning ON by default; `/no_think` in the system prompt turns it off. Sampling 0.6 / 0.95. Card pins `vllm==0.9.2` |
| `nvidia/Llama-3_1-Nemotron-Ultra-253B-v1` (+ FP8)         | Created 2025-04-07                                                                                                                                                                                                                         |
| `nvidia/Llama-3.1-Nemotron-Nano-4B-v1.1`, `Nano-8B-v1`    | Small Llama-based reasoning models                                                                                                                                                                                                         |
| `nvidia/Nemotron-4-340B-Instruct`                         | Older dense 340B                                                                                                                                                                                                                           |

Their chat template and parser story differs from Nemotron 3: no `enable_thinking`, system-prompt toggle instead.
Cards for the Llama variants were only skimmed (Super 49B v1.5); read the card before serving any of them.

## Not covered

Nemotron speech (Parakeet, Canary, ASR streaming), safety (Content Safety), embedding and reranking, Cosmos and GR00T
are separate model types and out of scope here.

## Sources

- https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Ultra-550B-A55B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16
- https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-BF16
- https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-BF16
- https://huggingface.co/nvidia/Llama-3_3-Nemotron-Super-49B-v1_5
- https://huggingface.co/nvidia
