# Triton troubleshooting

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

First steps (debugging guide): run the model in its own framework outside Triton (ONNX Runtime, `trtexec`), find the
error text in the Triton source, start with `--log-verbose=1`, and load the model directly in Triton before blaming
`perf_analyzer` or Model Analyzer.

| Symptom                                                                        | Cause                                                                    | Fix                                                                                   |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| Model state UNAVAILABLE in the repository index                                | load failed; the `reason` field says why                                 | `curl -X POST localhost:8000/v2/repository/index                                      | jq`, fix config or model |
| Server exits at start because a model failed                                   | default fail-fast                                                        | `--exit-on-error=false` to start anyway                                               |
| `/v2/health/ready` not 200 though server runs                                  | a model not ready                                                        | fix the model, or `--strict-readiness=false`                                          |
| Undefined symbol on load                                                       | framework version mismatch or missing `LD_PRELOAD` for a backend library | match the framework version to the container; `LD_PRELOAD=<lib>.so tritonserver ...`  |
| TensorRT plan fails to load                                                    | built with another TensorRT version or GPU                               | rebuild the engine in the target container                                            |
| TensorRT model "may not load" without config                                   | no auto-complete and missing `is_non_linear_format_io`                   | set it for reformat-free tensors                                                      |
| Config errors (shape, dims, batch)                                             | `max_batch_size` vs `dims` confusion                                     | batch dim is implicit when `max_batch_size > 0`; compare with `/v2/models/<m>/config` |
| PyTorch model fails auto-complete                                              | no metadata in TorchScript                                               | write the full `config.pbtxt`                                                         |
| Slow start                                                                     | auto-complete                                                            | full configs plus `--disable-auto-complete-config`                                    |
| Cannot reach server from client container                                      | separate Docker networks                                                 | `--net=host` or published ports on the same network                                   |
| Load/unload API returns an error                                               | server in `poll` or `none` mode                                          | use `--model-control-mode explicit`                                                   |
| Cloud repo not found or denied                                                 | credentials not in env                                                   | set AWS/GCP/Azure credentials in the environment; check the URL form                  |
| Stale or partial models in `poll` mode                                         | polling sees incomplete uploads                                          | switch to explicit mode in production                                                 |
| vLLM model TP>1 fails at `initialize`                                          | default executor backend                                                 | `"distributed_executor_backend":"ray"` in `model.json`                                |
| vLLM TP>1 leaves processes after shutdown                                      | known vLLM issue                                                         | Ray executor backend                                                                  |
| `ImportError: cannot import name 'PartReasoningText'` (TensorRT-LLM container) | old `openai` package                                                     | `pip install -U openai`                                                               |
| `ModuleNotFoundError: No module named 'tensorrt_llm.bindings'`                 | launch script run inside the TensorRT-LLM clone                          | run from the parent directory                                                         |
| Segfault at shutdown with GPU metrics (NVSwitch)                               | DCGM/NSCQ issue                                                          | `--allow-gpu-metrics false`                                                           |
| No GPU metrics                                                                 | MIG or separate DCGM agent                                               | known limitation; use `dcgm-exporter`                                                 |
| Python models hang on unload (decoupled)                                       | `ResponseSender` still alive                                             | ensure it is cleaned up before unload                                                 |
| False memory leak after many loads                                             | allocator behaviour                                                      | tcmalloc or jemalloc via `LD_PRELOAD`                                                 |
| TensorRT-LLM container missing for a release                                   | 26.09 does not ship it                                                   | use 26.07 or build from source                                                        |
| `cuda_shared_memory` client crashes in threads                                 | CuPy with CUDA 13                                                        | avoid multithreaded CUDA shm clients                                                  |

Collect for help: `tritonserver --version`, image tag, `nvidia-smi`, the first 100 log lines with `--log-verbose=1`, the
repository index output, and the model config (secrets removed).
