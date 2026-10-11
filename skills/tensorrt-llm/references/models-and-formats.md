# Models and formats

> Verified against TensorRT-LLM v1.2.1 (`docs/source/features/quantization.md`, `supported-hardware.md`, serve docs), DGX Spark playbook, 2026-10-11

## What loads

- **Hugging Face safetensors checkpoints** (a Hub id or a local directory) on the PyTorch backend. `trtllm-serve <id>` downloads and loads them; BF16/FP16 work on every supported GPU.
- **NVIDIA Model Optimizer pre-quantized checkpoints** (`nvidia/*-FP8`, `nvidia/*-FP4` / NVFP4) are loaded directly, no conversion step. Browse the collection: https://huggingface.co/collections/nvidia/inference-optimized-checkpoints-with-model-optimizer (links also from the quick start).
- **Your own quantization** via ModelOpt `hf_ptq.py` exporting a unified HF checkpoint (`hf_quant_config.json` + safetensors): see `combos/modelopt-nvfp4.md`.
- **GGUF, EXL3, AWQ in compressed-tensors, GPTQ from other tools**: not a documented path (the quantization doc only describes running ModelOpt-generated pre-quantized models, even for its AWQ and GPTQ rows). For GGUF use `llama-cpp` or `ollama`; for LLM Compressor outputs prefer `vllm`.
- **Legacy TensorRT engines**: v1.2.1 still accepts `--backend tensorrt` (alias `trt`), `--engine_dir` in `trtllm-bench throughput` and `trtllm-bench build`, and ModelOpt can still export "legacy TensorRT-LLM checkpoints" for the C++ backend followed by `trtllm-build`. Upstream's current docs mark `--backend` deprecated with only `pytorch` accepted, and ModelOpt describes the TensorRT engine flow as legacy. New work should use the PyTorch backend; engine builds are only for pinned old deployments (and disappear on newer lines).

## Quantization recipes (v1.2.1)

Recipe names: FP4 (NVFP4), MXFP4 (gpt-oss), FP8 per tensor, FP8 block scaling, FP8 rowwise, FP8 KV cache, NVFP4 KV cache, W4A16 / W4A8 AWQ, W4A16 / W4A8 GPTQ. The default PyTorch backend supports FP4 and FP8 on the latest Blackwell and Hopper GPUs.

Hardware matrix (Y = supported):

| GPU                   | NVFP4 | MXFP4 | FP8 per tensor | FP8 block | FP8 rowwise | FP8 KV | NVFP4 KV | W4A8 AWQ | W4A16 AWQ | W4A8 GPTQ | W4A16 GPTQ |
| --------------------- | :---: | :---: | :------------: | :-------: | :---------: | :----: | :------: | :------: | :-------: | :-------: | :--------: |
| Blackwell sm120       |   Y   |   Y   |       Y        |           |             |   Y    |          |          |           |           |            |
| Blackwell sm100 / 103 |   Y   |   Y   |       Y        |     Y     |             |   Y    |    Y     |    Y     |     Y     |     Y     |     Y      |
| Hopper                |       |       |       Y        |     Y     |      Y      |   Y    |          |    Y     |     Y     |     Y     |     Y      |
| Ada Lovelace          |       |       |       Y        |           |             |   Y    |          |    Y     |     Y     |     Y     |     Y      |
| Ampere                |       |       |                |           |             |   Y    |          |          |     Y     |           |     Y      |

DGX Spark (GB10) is not a row in this table (reported compute capability 12.1; unverified how it maps). NVIDIA's own Spark playbook runs NVFP4 checkpoints (`nvidia/Llama-3.1-8B-Instruct-FP4`, `nvidia/Qwen3-235B-A22B-FP4`) there, so NVFP4 works in the playbook images.

FP8 block scaling on sm100/103 uses the MXFP8 recipe, slightly different from Hopper's FP8 block recipe.

Model matrix highlights at v1.2.1 (full table in the quantization doc): NVFP4 for DeepSeek-R1, LLaMA, LLaMA-v2, LLaMA 4, Mixtral, Qwen-2/2.5 and Qwen-3; MXFP4 for GPT-OSS; FP8 per tensor for most dense families; NVFP4 KV cache for LLaMA-v2, LLaMA 3 and Qwen-3. The language component decides support for multimodal models (vision parts run FP16).

## KV cache dtype

```yaml
kv_cache_config:
  dtype: fp8 # allowed even when the checkpoint did not enable FP8 KV
  # dtype: nvfp4  # needs offline ModelOpt quantization, and only with FP8 weight/activation quant
```

NVFP4 KV cache currently requires `--quant fp8` in the ModelOpt script (upstream note).

## Choosing a format

| GPU                          | First choice                                 | Notes                                                                              |
| ---------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------- |
| Blackwell datacenter / Spark | NVFP4 (`nvidia/*-FP4`), else FP8             | NVFP4 inference needs Blackwell and TensorRT-LLM 1.2 or later (ModelOpt README).   |
| Hopper                       | FP8                                          | No NVFP4.                                                                          |
| Ada                          | FP8 or W4A16 AWQ                             |                                                                                    |
| Ampere                       | BF16, W4A16 AWQ / GPTQ                       | No FP8 compute.                                                                    |
| gpt-oss                      | Native MXFP4 (`openai/gpt-oss-20b`, `-120b`) | Needs the tiktoken files (`install.md`). Blackwell MoE backend defaults to TRTLLM. |

## Multimodal and other model types

- Vision-language models need a chat template, so only the Chat API works, and multimodal currently does not combine with KV reuse; set `kv_cache_config.enable_block_reuse: false` in the YAML. Example: `trtllm-serve Qwen/Qwen2-VL-7B-Instruct --config ./config.yml`. Inputs: `image_url` (URL or base64 data URI), `image_embeds`, `video_url`, `audio_url`, depending on the model.
- Encoder-only (BERT-style classifiers, reward and embedding models): `trtllm-serve embeddings <model>` gives `/v1/embeddings`.
- Diffusion (FLUX.1/2, Wan 2.1/2.2, Cosmos): VisualGen, beta, `--visual_gen_args` (docs on `main`).
- Supported model list: https://nvidia.github.io/TensorRT-LLM/models/supported-models.html (not reproduced here; check the page for your version).

## Verify a checkpoint before serving

```bash
hf download nvidia/Qwen3-8B-FP8 --local-dir ~/models/Qwen3-8B-FP8
jq '.quantization // .' ~/models/Qwen3-8B-FP8/hf_quant_config.json 2>/dev/null | head -20
jq '.torch_dtype, .architectures' ~/models/Qwen3-8B-FP8/config.json
```

## Official links

- Quantization: https://nvidia.github.io/TensorRT-LLM/features/quantization.html
- Supported hardware: https://nvidia.github.io/TensorRT-LLM/supported-hardware.html
- ModelOpt support matrix: https://nvidia.github.io/Model-Optimizer/guides/0_support_matrix.html
- Pre-quantized collection: https://huggingface.co/collections/nvidia/model-optimizer-66aa84f7966b3150262481a4
