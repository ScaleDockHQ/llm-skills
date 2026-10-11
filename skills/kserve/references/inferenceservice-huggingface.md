# InferenceService with the Hugging Face runtime

> Verified against KServe v0.21.0 (website generative-inference: overview, text-generation, multi-node, autoscaling; ClusterServingRuntime kserve-huggingfaceserver), 2026-10-11

The classic path. `InferenceService` (`serving.kserve.io/v1beta1`) with `modelFormat.name: huggingface` selects
the `kserve-huggingfaceserver` runtime, whose backend is vLLM by default. If vLLM does not support the model,
KServe falls back to the Hugging Face backend. Force it with `--backend=huggingface` in `args`. Tasks covered:
text generation, text2text, embeddings, reranking. Endpoints are OpenAI-compatible under `/openai/v1/...`.

The runtime image comes in a CUDA and a CPU variant (`kserve/huggingfaceserver:v0.21.0` and `:v0.21.0-gpu` exist on
Docker Hub). KServe picks the GPU one when the container requests `nvidia.com/gpu`.

## Minimal deploy

```bash
kubectl create secret generic hf-secret --from-file=HF_TOKEN=/path/to/token-file   # gated models only
kubectl apply -f templates/inferenceservice-hf.yaml
kubectl get inferenceservice llama3-8b
```

The storage initializer downloads `hf://` models. For gated or private repos, create a `ClusterStorageContainer`
named `hf-hub` that injects `HF_TOKEN` from the Secret (`supportedUriFormats: - prefix: hf://`); the template
file includes it. Other URIs: `s3://`, `gs://`, `pvc://`, `oci://`.

## Useful `args`

`--model_name=<served name>`, `--backend=huggingface`, and vLLM flags such as `--max-model-len`,
`--tensor-parallel-size` (look flags up with the `vllm` skill). Sets of arguments differ by release; list what the
installed runtime accepts with `kubectl get clusterservingruntime kserve-huggingfaceserver -o yaml`.

## Calling it

```bash
kubectl port-forward svc/llama3-8b-predictor 8080:80 &     # Standard mode service name: <name>-predictor
curl -s localhost:8080/openai/v1/models | jq
curl -s localhost:8080/openai/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq '.choices[0].message'
```

With a Gateway/Ingress host, the same paths sit under the InferenceService URL
(`kubectl get inferenceservice <n> -o jsonpath='{.status.url}'`) and, in Knative mode, require the `Host` header.

## Multi-node (Standard mode only)

Needs at least two nodes, an RWX PVC holding the model (`pvc://` is the only storage protocol allowed) and the
`kserve-huggingfaceserver-multinode` runtime:

```yaml
spec:
  predictor:
    deploymentStrategy: { type: Recreate } # a rolling update needs spare GPUs on every node
    model:
      modelFormat: { name: huggingface }
      runtime: kserve-huggingfaceserver-multinode
      storageUri: pvc://<pvc>/<path>
    workerSpec:
      tensorParallelSize: 2
      pipelineParallelSize: 2
```

Restrictions from the docs: autoscaler must be `none`; set parallel sizes through `workerSpec`, not env vars (the
runtime defaults them to 1); exactly one head pod; do not mix GPU types; only NCCL; nvidia, intel, amd and habana GPU
resource types are allowed by default, extra ones via the annotation `serving.kserve.io/gpu-resource-types`.
Raise the startup probe for large models (default `failureThreshold: 40`, `periodSeconds: 30`).
For multi-node LLM serving with autoscaling and routing, prefer `LLMInferenceService`.

## KEDA autoscaling on vLLM metrics (Standard mode)

```yaml
metadata:
  annotations:
    serving.kserve.io/deploymentMode: "Standard"
    serving.kserve.io/autoscalerClass: "keda"
    serving.kserve.io/enable-prometheus-scraping: "true"
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 5
    autoScaling:
      metrics:
        - type: External
          external:
            metric:
              backend: "prometheus"
              serverAddress: "http://prometheus.<ns>.svc.cluster.local:9090"
              query: vllm:num_requests_running
            target: { type: Value, value: "2" }
```

The controller creates a `ScaledObject` named `<isvc>-predictor`. The OpenTelemetry route pushes pod metrics to the
`keda-otel-add-on` gRPC endpoint instead of Prometheus. Skill `keda` covers KEDA itself.

## Sources

- <https://kserve.github.io/website/docs/model-serving/generative-inference/overview>
- <https://kserve.github.io/website/docs/model-serving/generative-inference/tasks/text-generation/text-generation>
- <https://kserve.github.io/website/docs/model-serving/generative-inference/multi-node/multi-node>
- <https://kserve.github.io/website/docs/model-serving/generative-inference/autoscaling/autoscaling>
