# Models, quantization and compilation in MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

## What an MLC model is

An MLC model directory has `mlc-chat-config.json` (architecture, quantization, conversation template, defaults), weight shards `params_shard_*.bin` with `tensor-cache.json`, and tokenizer files. Weights are shared across platforms. A separate **model library** (`.so`, `.dylib`, `.dll`, `.tar`, `.wasm`) holds the compiled kernels per device; `serve` and `chat` JIT-compile it when you do not pass `--model-lib`.

Prebuilt MLC repos are on Hugging Face under `mlc-ai` (for example `HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC`, named `<Model>-<quant>-MLC`). Check the repo exists before promising it:

```bash
curl -s "https://huggingface.co/api/models?author=mlc-ai&search=<name>" | jq -r '.[].id' | head
```

## Quantization codes

Format `qAfB(_id)`: `A` weight bits, `B` activation float width. Docs list `q0f16`, `q0f32`, `q3f16_1`, `q4f16_1`, `q4f32_1` and `q4f16_awq` (not stable). Source also registers `q0bf16`, `q3f16_0`, `q4f16_0`, `q4bf16_0/1`, `q4f16_2`, `q4f16_autoawq`, `q4f16_ft`, `e5m2_e5m2_f16`, `e4m3_e4m3_f16` (FP8 weights and activations on CUDA, needs calibration), `fp8_e4m3fn_bf16_block_scale` and a static-activation variant. Upstream recommends 4-bit; 3-bit may be poor. The default algorithm is group quantization. FP8 calibration uses `mlc_llm calibrate` (see `docs/compilation/configure_quantization.rst`).

## Supported architectures

From `python/mlc_llm/model/model.py` on main: llama, llama4, mistral, ministral3, mixtral, gemma, gemma2, gemma3, gemma4, gpt2, gpt_neox, gpt_bigcode, gptj, phi, phi3, phi3_v, qwen, qwen2, qwen2_moe, qwen3, qwen3_moe, qwen3_5 (text and vision), deepseek, deepseek_v2, deepseek_v3, stablelm, baichuan, internlm, internlm2, rwkv5, rwkv6, orion, llava, chatglm, eagle, medusa, bert (encoder, embeddings), starcoder2, cohere, minicpm, olmo, olmo2, nemotron. Re-read this file for your version: support is not inferred from other engines. GGUF and AWQ/GPTQ files from other tools are not loaded directly; convert from the Hugging Face model.

## Convert your own model (three steps)

```bash
mkdir -p dist/models && cd dist/models
git lfs install && git clone https://huggingface.co/<org>/<model> && cd ../..
# 1. quantize weights (all platforms share the result)
mlc_llm convert_weight ./dist/models/<model>/ --quantization q4f16_1 -o dist/<model>-q4f16_1-MLC
# 2. generate mlc-chat-config.json and process the tokenizer
mlc_llm gen_config ./dist/models/<model>/ --quantization q4f16_1 --conv-template <template> -o dist/<model>-q4f16_1-MLC/
# 3. optional: compile a model library for a device
mlc_llm compile ./dist/<model>-q4f16_1-MLC/mlc-chat-config.json --device cuda -o dist/libs/<model>-q4f16_1-cuda.so
```

`convert_weight` options: `--quantization`, `--model-type`, `--device`, `--source`, `--source-format`, `--output`. `gen_config` options: `--conv-template` (required; `LM` for base or completion models, others from `python/mlc_llm/conversation_template/`: llama, mistral, qwen2, qwen3, deepseek, gemma, phi, hermes, chatml-style and more), `--context-window-size`, `--sliding-window-size` (experimental), `--prefill-chunk-size` (experimental), `--tensor-parallel-shard`. `compile` options: `--device` (cuda, metal, metal:x86-64, vulkan, rocm, opencl), `--host` (LLVM triple for iPhone, Android, wasm, Windows), `--opt O0..O3` or knobs like `"cutlass_attn=1;cudagraph=0"`, `--system-lib-prefix`, `--overrides`, `--output` (suffix selects `.so`, `.dylib`, `.dll`, `.tar`, `.wasm`). `O3` can break the system; `O2` is the JIT default.

Macs can compile for Metal, iOS targets need a Mac. Upload the output directory to a Hugging Face repo to serve it as `HF://<you>/<repo>`. Adding an unsupported architecture means writing it in `python/mlc_llm/model/` (see `docs/compilation/define_new_models.rst`).

## Sizing

Weights are about `params x bits / 8` plus group scales; KV cache and activation memory come on top and are sized by `gpu_memory_utilization` and `--mode`. Upstream suggests at least 6 GB of free VRAM for the int4 Llama 3 8B example.
