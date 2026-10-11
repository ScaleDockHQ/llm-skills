# Triton integrations

> Verified against Triton Inference Server v2.73.0 (NGC 26.09), 2026-10-11

- **Kubernetes**: run the container with a model repository volume or object storage, readiness probe on
  `/v2/health/ready`, liveness on `/v2/health/live`, metrics on 8002 (`templates/k8s-deployment.yaml`). Helm examples:
  `deploy/gcp`, `deploy/aws`, `deploy/fleetcommand`.
- **KServe**: Triton is a KServe-supported runtime (the protocol is KServe v2). See the `kserve` skill.
- **SageMaker and Vertex AI**: built-in endpoint modes (`--endpoint=sagemaker`, `--endpoint=vertex-ai` at build time;
  the SageMaker guide covers multi-model endpoints).
- **Gateways**: put an API gateway or mesh in front (Triton has no authentication): `litellm`/`llm-gateway` for the
  OpenAI frontend, Envoy/Istio/NGINX/Kong for KServe traffic.
- **Prometheus/Grafana**: scrape `:8002/metrics`; `dcgm-exporter` skill for host GPU telemetry (Triton's own GPU metrics
  fail with MIG or a separate DCGM agent).
- **Other NVIDIA skills**: `nvidia-dynamo` (LLM orchestration; has a Triton backend overview), `nvidia-nim` (packaged
  microservices), `tensorrt-llm`, `vllm`.
- **Tutorials**: github.com/triton-inference-server/tutorials (quick deploy, conceptual guide).
