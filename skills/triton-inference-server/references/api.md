# Triton API

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

Triton implements the KServe v2 inference protocol over HTTP/REST (8000) and gRPC (8001), with extensions
(model repository, model configuration, statistics, trace, logging, shared memory, binary data, parameters, schedule
policy, sequence, classification, generate).

```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/v2/health/live
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/v2/health/ready
curl -s localhost:8000/v2 | jq .                                   # server metadata and extensions
curl -s localhost:8000/v2/models/<model> | jq .                    # model metadata
curl -s localhost:8000/v2/models/<model>/ready -o /dev/null -w '%{http_code}\n'
curl -s localhost:8000/v2/models/<model>/config | jq .
curl -s localhost:8000/v2/models/<model>/stats | jq .
curl -s -X POST localhost:8000/v2/repository/index | jq .          # name, version, state, reason
curl -s -X POST localhost:8000/v2/models/<model>/infer -H 'Content-Type: application/json' \
  -d '{"inputs":[{"name":"input0","shape":[1,4],"datatype":"FP32","data":[1,2,3,4]}]}' | jq .
```

Model control (explicit mode only): `POST /v2/repository/models/<model>/load` and `.../unload`. These can load arbitrary
code: never expose them.

Clients: Python (`tritonclient[grpc,http]`) and C++ libraries; other languages via `grpc_service.proto` (Go, Java examples).
Use the gRPC client for streaming and decoupled models. Inference over HTTP with large tensors can use the binary data
extension or shared memory (system or CUDA) to avoid JSON overhead; CuPy has issues with the CUDA 13 device API in
multithreaded clients (known issue) so avoid multithreaded `cuda_shared_memory`.

LLM endpoints: `/v2/models/<model>/generate` and `/generate_stream` (HTTP only, generate extension); OpenAI frontend on
port 9000 (`references/features.md`).
