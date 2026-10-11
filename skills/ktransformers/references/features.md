# Features

> Verified against KTransformers v0.7.1 (kt-kernel README, `Native-Precision-Tutorial.md`, `experts-sched-Tutorial.md`, v0.7.1 release notes, sglang-kt `server_args.py`), 2026-10-11

## Deferred experts (pipelined execution)

`--kt-max-deferred-experts-per-token K`: K experts per token are not waited for within the layer; the CPU finishes them while the GPU proceeds, and
results join later. 0 is synchronous (simplest, slowest); 1 to 4 is the recommended range; 5 to 7 cuts latency most but may cost accuracy. The last MoE layer always runs synchronously.
Evaluate quality on your tasks after changing it.

## Dual prefill and layerwise GPU prefill

For native methods (`FP8`, `RAWINT4`, `BF16`), `--kt-gpu-prefill-token-threshold T` switches strategy:

- Prompts of at most T tokens: hybrid CPU+GPU prefill, no extra VRAM, speed degrades slowly with length.
- Longer prompts: layerwise GPU prefill, which loads one MoE layer at a time onto the GPU and scales better, at the cost of about one extra MoE layer of
  VRAM (upstream: about 9 GB or more for Kimi K2 Thinking, about 3.6 GB for MiniMax M2.1).

First qualifying request pays a one-time setup cost. The DeepSeek-V4-Flash image defaults to 2048 and treats 0 as disabled.

## Expert scheduling

GPU expert mask, placement strategies and dynamic updates are covered in `parallelism-multinode.md`. They only change which experts are fast; the model output
is unaffected apart from numerics.

## Parsers, reasoning and tools

Tool calling and reasoning parsers come from SGLang: `--tool-call-parser` (for example `qwen3_coder` in the Coder-Next tutorial) and `--reasoning-parser`. Pick the
parser that matches the model family; see `tool-calling-parsers` and `reasoning-models` skills. Models such as GLM-5.3-flash and Qwen3.5 add multimodal input
(images, video) per their tutorials.

## KT LoRA serving (experimental)

`--kt-lora-path <PEFT dir>` serves one static adapter whose expert tensors run on the KT CPU path and whose Qwen3.5 non-expert tensors apply statically;
`--kt-expert-lora-path` is the expert-only variant. Both are labelled experimental in the fork, and KT LoRA serving constrains `--max-running-requests` and
disables CUDA graphs per validators in the fork. Read the fork's validation errors on startup rather than guessing.

## Fine-tuning (SFT) pointer

KTransformers also fine-tunes huge MoE models with LLaMA-Factory (`kt sft`, `pip install "ktransformers[sft]"`): LoRA, BF16, FP8 and INT8 recipes; v0.7.1 adds Qwen
VLM MoE LoRA and Kimi K2.5/K2.6 native RAWINT4 LoRA. This skill does not cover training; see the `fine-tuning-llms` skill and upstream's SFT cookbook.

## CPU kernels

AMX INT4/INT8, AVX512 native (FP8, BF16, RAWINT4), AVX2, llamafile (GGUF), AMD BLIS, ARM KML: selected at runtime in the wheel or at build time in source builds.
