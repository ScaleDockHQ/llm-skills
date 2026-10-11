# Triton Inference Server install

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Sources: README, quickstart, compatibility matrix, release v2.73.0 (2026-09-30), vllm_backend README.

Triton is distributed as NGC containers; Docker is the recommended path. Release 2.73.0 corresponds to NGC container
26.09. Requirements: Docker plus the NVIDIA Container Toolkit for GPUs; the same image runs CPU-only (omit `--gpus`)
but cannot load models that need a GPU. The 26.09 containers add initial NVIDIA Rubin support.

## Images (`nvcr.io/nvidia/tritonserver:<YY.MM>-<flavor>`)

| Flavor              | Contents                                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `py3`               | Server with TensorRT, ONNX Runtime, PyTorch, OpenVINO, Python and other backends                                                    |
| `py3-sdk`           | Clients, `perf_analyzer`, `genai-perf`, example clients (`image_client`)                                                            |
| `vllm-python-py3`   | vLLM backend (since 23.10). 26.09 bundles vLLM 0.29.0; Python 3.12.3; CUDA 13.4.1; driver 615.71.09                                 |
| `trtllm-python-py3` | TensorRT-LLM backends. **26.09 has no such image**; newest in the matrix is 26.07 (TensorRT-LLM 1.2.1, CUDA 13.1, driver 590.44.01) |

Confirm that a tag exists on the NGC catalog before pinning it. The full compatibility table (Python, Torch, TensorRT,
TensorRT-LLM, CUDA, driver per release) is in `docs/introduction/compatibility.md`; the DLFW support matrix is the
authority for driver requirements.

```bash
docker pull nvcr.io/nvidia/tritonserver:26.09-py3
docker pull nvcr.io/nvidia/tritonserver:26.09-py3-sdk
docker run --rm nvcr.io/nvidia/tritonserver:26.09-py3 tritonserver --version
```

NGC pulls may need `docker login nvcr.io` (username `$oauthtoken`, password an NGC API key read from a `0600` file with
`--password-stdin`; never inline the key).

## Without Docker, custom builds

- Non-Docker install and source builds: `docs/customization_guide/build.md` (`build.py`, backends chosen with
  `--backend=<name>:r<YY.MM>`).
- Slim custom container with only the backends you need: `docs/customization_guide/compose.md`.
- Add the vLLM backend to a stock container: `pip install vllm==<version>`, then copy
  `vllm_backend/src/*` into `/opt/tritonserver/backends/vllm`.
- The Python client: `pip install "tritonclient[grpc,http]"` (client versions track server releases; ARM SBSA wheels
  are not on PyPI and the PyPI install picks the Jetson build: take the wheel from the SDK image).

## Kubernetes and clouds

Repository examples: `deploy/gcp`, `deploy/aws` (Helm), `deploy/fleetcommand`. SageMaker and Vertex AI endpoints are
build options (`--endpoint=sagemaker`, `--endpoint=vertex-ai`). See `references/integrations.md`.

## Uninstall

`docker rm -f <name>`, `docker rmi nvcr.io/nvidia/tritonserver:<tag>`. Model repositories are yours; nothing else persists.
