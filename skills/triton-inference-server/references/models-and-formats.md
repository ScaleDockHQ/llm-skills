# Triton models, repository and config.pbtxt

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: model repository, model configuration, backend READMEs.

## Layout

```
<repo>/
  <model-name>/
    config.pbtxt            # required for some backends, optional for others
    [labels.txt] [configs/<name>.pbtxt]
    <version>/              # numeric directories, at least one
      <model-file>          # model.plan, model.onnx, model.pt, model.py, model.json ...
```

`--model-repository` is repeatable. Backends: TensorRT (`tensorrt_plan`), ONNX Runtime, PyTorch (TorchScript and PT2/AOTI),
OpenVINO, Python, RAPIDS FIL, vLLM, TensorRT-LLM, and custom backends. Models run on a backend
named by `backend:` (or legacy `platform:`).

## Minimal config.pbtxt

```protobuf
name: "my_model"
backend: "onnxruntime"
max_batch_size: 8
input [ { name: "input0" data_type: TYPE_FP32 dims: [ 3, 224, 224 ] } ]
output [ { name: "output0" data_type: TYPE_FP32 dims: [ 1000 ] } ]
```

- `max_batch_size: 0` means no batching and `dims` is the full shape; >0 prepends an implicit `-1` batch dimension.
- With `max_batch_size > 1` and no scheduler block, the dynamic batcher is on by default.
- **Auto-complete**: Triton can derive inputs, outputs, `max_batch_size` and dynamic batching for most TensorRT, ONNX and
  OpenVINO models; Python models can implement `auto_complete_config`; all other models need a config. It lengthens start
  time and not for PyTorch (no metadata). Use `--disable-auto-complete-config` with full configs in production.
- Inspect what Triton resolved: `curl localhost:8000/v2/models/<model>/config | jq`.
- A custom-backend config needs a `backend` field or a model name of the form `<name>.<backend>`.
- TensorRT models without auto-complete may need `is_non_linear_format_io: true` for reformat-free tensors.

## Versions

Each numeric subdirectory is a version; `version_policy` (latest, all, specific) picks which load. Removing a version
under `poll` lets in-flight requests finish and fails new ones.

## Ensembles and BLS

`platform: "ensemble"` with `ensemble_scheduling` chains models in the config; Business Logic Scripting (Python backend)
is the programmable alternative. Ensembles have no instance group. See `references/parallelism-multinode.md`.

## LLM model layouts

- vLLM backend: `<model>/1/model.json` is the dict passed to vLLM's AsyncLLMEngine arguments (`model`,
  `tensor_parallel_size`, ...), plus `config.pbtxt`; use `instance_group [{ kind: KIND_MODEL }]` for multi-GPU and optional
  `GPU_DEVICE_IDS` parameter to pin GPUs. Sample: `vllm_backend/samples/model_repository/vllm_model`.
- TensorRT-LLM LLM API backend: repository `TensorRT-LLM/triton_backend/all_models/llmapi/` from the TensorRT-LLM tag that
  matches the container's `tensorrt_llm` version; `1/model.yaml` keys outside `triton_config` map to `LLM()` arguments.
- Weights come from Hugging Face or local paths; see the `vllm` and `tensorrt-llm` skills for formats and fit.

Gated models: forward `HF_TOKEN` with `-e HF_TOKEN` and accept the model license first.
