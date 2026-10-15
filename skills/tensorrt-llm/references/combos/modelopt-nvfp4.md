# NVIDIA Model Optimizer NVFP4 / FP8 to a TensorRT-LLM server

> Verified against NVIDIA/Model-Optimizer 0.47.0 (`examples/hf_ptq/README.md`), TensorRT-LLM v1.2.1 (`features/quantization.md`) and NGC release tags, 2026-10-11

Combo owned by this skill: quantize a Hugging Face model with NVIDIA Model Optimizer ("ModelOpt", PyPI `nvidia-modelopt`, repo `NVIDIA/Model-Optimizer`) and serve the exported checkpoint with `trtllm-serve`. The full quantization workflow (formats, calibration datasets, quality gates, publishing) is the `model-quantization` skill: `npx skills add ScaleDockHQ/llm-skills --skill model-quantization`. This file keeps only what is TensorRT-LLM specific.

## First check whether you need to quantize

NVIDIA already publishes many `nvidia/*-FP8` and `nvidia/*-FP4` (NVFP4) checkpoints, which `trtllm-serve` loads directly (`models-and-formats.md`). Quantize yourself only for a model without one, a custom fine-tune, or a different recipe.

## Constraints

- NVFP4 inference needs Blackwell GPUs and TensorRT-LLM 1.2 or later (ModelOpt README). Hopper and Ada: FP8. Calibration itself runs on any supported CUDA GPU.
- Unified HF checkpoint (`hf_quant_config.json` + safetensors) is the format TensorRT-LLM's PyTorch backend loads. ModelOpt also still writes legacy TensorRT-LLM checkpoints for the old C++/engine flow; do not use them for new deployments.
- NVFP4 KV cache needs ModelOpt with FP8 weights and activations (`--quant fp8 --kv_cache_quant nvfp4` in the wrapper script, per TensorRT-LLM docs).
- GB10 (DGX Spark) compute capability 12.1 is not named in the support tables; NVIDIA's own Spark playbook serves NVFP4 checkpoints on it. (Whether ModelOpt-made NVFP4 checkpoints hit the same fast kernels on GB10 is unverified; test.)

## Quantize

ModelOpt's README recommends running Hugging Face PTQ inside the TensorRT-LLM container (its example names `nvcr.io/nvidia/tensorrt-llm/release:1.2.0`); that image ships a matching PyTorch. Upgrade `nvidia-modelopt` inside if needed. Alternatively use a venv (see `model-quantization`).

```bash
docker run --rm -it --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -v "$HOME/models:/models" -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  nvcr.io/nvidia/tensorrt-llm/release:1.2.1 bash
# inside
pip install -U "nvidia-modelopt[hf]==0.47.0"
git clone --branch 0.47.0 https://github.com/NVIDIA/Model-Optimizer /tmp/mo
pip install -r /tmp/mo/examples/hf_ptq/requirements.txt
cd /tmp/mo/examples/hf_ptq
python hf_ptq.py --pyt_ckpt_path /models/Qwen3-8B --qformat nvfp4_mlp_only \
  --kv_cache_qformat fp8_cast --export_path /models/Qwen3-8B-NVFP4
```

Accuracy-first NVFP4 presets per the README: `nvfp4_mlp_only`, `nvfp4_experts_only` (MoE), `nvfp4_omlp_only` (also quantizes `o_proj`) keep attention QKV in higher precision; plain `nvfp4` is the default config. FP8: `--qformat fp8`. Other flags (`--calib_size`, `--calib_seq`, `--low_memory_mode`, `--use_seq_device_map`, `--cast_mxfp4_to_nvfp4`) are described in `model-quantization`'s `modelopt-nvfp4.md`. On a unified-memory machine cap the memory of the calibration run and stop other engines first.

Wrapper alternative documented by TensorRT-LLM: `scripts/huggingface_example.sh --model <hf-id> --quant fp8` (or `--quant nvfp4`, check `--help`) inside `examples/llm_ptq` (the TensorRT-LLM doc's path; the ModelOpt repo now uses `examples/hf_ptq`).

## Serve with TensorRT-LLM

```bash
trtllm-serve /models/Qwen3-8B-NVFP4 --host 127.0.0.1 --port 8000 --config /cfg/config.yml
```

With the checkpoint present, TensorRT-LLM reads `hf_quant_config.json`; no `--quantization` flag exists. For FP8 KV cache add `kv_cache_config: {dtype: fp8}`; for an NVFP4 KV cache checkpoint use `dtype: nvfp4`.

Smoke test, then compare with the base model before deploying:

```bash
trtllm-eval --model /models/Qwen3-8B-NVFP4 gsm8k
trtllm-eval --model /models/Qwen3-8B gsm8k
```

(or `llm-evals` for task suites). Record the ModelOpt version, qformat or recipe, KV format and calibration set in the model card.

## Pitfalls

- NVFP4 on Hopper/Ada/Ampere is not supported by TensorRT-LLM's matrix (it is on other engines as weight-only); use FP8 there.
- Checkpoints made with a much newer ModelOpt than the serving image may need a newer TensorRT-LLM image; match versions (ModelOpt 0.47.0 with TensorRT-LLM 1.2.x or the 1.3 rc images) and test.
- Multimodal models: only the language part follows the quantization recipe; vision parts stay FP16.

## Official links

- Model Optimizer: https://github.com/NVIDIA/Model-Optimizer
- hf_ptq example: https://github.com/NVIDIA/Model-Optimizer/tree/main/examples/hf_ptq
- TensorRT-LLM quantization: https://nvidia.github.io/TensorRT-LLM/features/quantization.html
- Pre-quantized collection: https://huggingface.co/collections/nvidia/model-optimizer-66aa84f7966b3150262481a4
