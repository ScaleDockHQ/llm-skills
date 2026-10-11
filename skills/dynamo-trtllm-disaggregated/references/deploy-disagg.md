# Deploy disaggregated TRT-LLM with a DynamoGraphDeployment

> Verified against NVIDIA Dynamo v1.5.1 (examples/backends/trtllm at tag v1.5.1), TensorRT-LLM 1.3.0rc25 (bundled), 2026-10-11

The Dynamo operator turns a `DynamoGraphDeployment` (DGD, `nvidia.com/v1beta1`) into pods: a `frontend` (OpenAI-compatible HTTP API and router), plus `prefill` and `decode` workers running `python3 -m dynamo.trtllm`. The repo ships templates under `examples/backends/trtllm/deploy/`: `agg.yaml`, `agg_router.yaml`, `disagg.yaml`, `disagg_router.yaml`, `disagg-multinode.yaml`, `disagg_planner.yaml`, `agg-with-config.yaml`, `snapshot-restore.yaml`.

The `deploy/*.yaml` templates use `v1beta1`, with `spec.components[]` carrying `name`, `type` (`frontend`, `prefill`, `decode`), `replicas`, `podTemplate` and for multinode `multinode.nodeCount`. Some other Kubernetes docs still show `v1alpha1`; confirm on your cluster:

```bash
kubectl api-resources --api-group=nvidia.com
kubectl explain dynamographdeployment.spec.components --api-version=nvidia.com/v1beta1 | head -40
```

## Get the templates at a pinned tag

```bash
git clone --depth 1 --branch v1.5.1 https://github.com/ai-dynamo/dynamo.git
cd dynamo/examples/backends/trtllm
```

## Step 1: aggregated baseline

Deploy `deploy/agg.yaml`, load test it, record TTFT, ITL and throughput. Without this you cannot tell if the split helps (`disaggregated-serving`).

```bash
export NAMESPACE=dynamo-system
kubectl apply --dry-run=server -n $NAMESPACE -f deploy/agg.yaml
kubectl apply -n $NAMESPACE -f deploy/agg.yaml
```

## Step 2: disaggregated deployment

`deploy/disagg.yaml` at v1.5.1 (model `Qwen/Qwen3-0.6B`, one GPU per worker, one replica per role):

```yaml
apiVersion: nvidia.com/v1beta1
kind: DynamoGraphDeployment
metadata:
  name: trtllm-disagg
spec:
  components:
    - name: Frontend
      type: frontend
      replicas: 1
      podTemplate:
        spec:
          containers:
            - name: main
              image: nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1
    - name: decode
      type: decode
      replicas: 1
      podTemplate:
        spec:
          containers:
            - name: main
              image: nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1
              command: [python3, -m, dynamo.trtllm]
              args:
                [
                  --model-path,
                  Qwen/Qwen3-0.6B,
                  --served-model-name,
                  Qwen/Qwen3-0.6B,
                  --extra-engine-args,
                  ./examples/backends/trtllm/engine_configs/qwen3/decode.yaml,
                  --disaggregation-mode,
                  decode,
                ]
              envFrom: [{ secretRef: { name: hf-token-secret } }]
              resources: { limits: { nvidia.com/gpu: "1" } }
              workingDir: /workspace/
    - name: prefill
      type: prefill
      replicas: 1
      # same shape as decode, with engine_configs/qwen3/prefill.yaml and --disaggregation-mode prefill
```

Model, GPU count and replicas are the template's placeholders. For a real model pick `--model-path`, `tensor_parallel_size`, GPU limits and replica ratio from measurements (the `tensorrt-llm` and `choosing-hardware` skills), and write your own engine YAMLs in a ConfigMap rather than relying on files inside the image.

Image tag `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.5.1` is the tag used by the repo YAML at v1.5.1. NGC does not list tags anonymously, so confirm it pulls (`kubectl describe pod` shows pull errors) and check the NGC catalog page. Pin the tag; do not use `latest`.

Engine YAML for `qwen3`:

```yaml
tensor_parallel_size: 1
moe_expert_parallel_size: 1
enable_attention_dp: false
max_num_tokens: 8192
trust_remote_code: true
backend: pytorch
enable_chunked_prefill: true
disable_overlap_scheduler: false # true on prefill: the overlap scheduler is unsupported on prefill-only workers
cuda_graph_config:
  max_batch_size: 16
kv_cache_config:
  free_gpu_memory_fraction: 0.85
cache_transceiver_config:
  backend: DEFAULT # see kv-transfer-and-networking.md
```

The `gpt-oss-120b` configs use `backend: UCX` and `max_tokens_in_buffer: 65536`. `max_tokens_in_buffer` must exceed your maximum input length (known deadlock otherwise, see `routing-scaling-ops.md`). `kv_cache_config.free_gpu_memory_fraction` of 0.85 is the example value; tune it for the memory TRT-LLM needs beyond KV.

Apply and watch:

```bash
kubectl apply --dry-run=server -n $NAMESPACE -f deploy/disagg.yaml
kubectl apply -n $NAMESPACE -f deploy/disagg.yaml
kubectl get dynamographdeployment -n $NAMESPACE
kubectl get pods -n $NAMESPACE -w
kubectl logs -n $NAMESPACE -l nvidia.com/dynamo-graph-deployment-name=trtllm-disagg --all-containers --tail=30 2>/dev/null | head -80
```

Label selectors vary by version: if the label query returns nothing, use `kubectl get pods --show-labels`.

## Multinode workers

`deploy/disagg-multinode.yaml` shows a `multinode: {nodeCount: 2}` on `decode` and `prefill` with 4 GPUs per node (8 GPUs, `tensor_parallel_size: 8` in the ConfigMap engine YAML), engine YAMLs in a ConfigMap `nvidia-config`, and a PVC `models` for weights. It needs Grove with KAI, or LWS with Volcano, installed (`install-platform.md`). On decode multinode there is a NIXL plugin ABI issue and on GB200 a `ComputeDomain` requirement: both are in `kv-transfer-and-networking.md`. The template pairs a tiny model with TP=8 only to show the structure; use a model that needs it.

## Reach the frontend

```bash
kubectl get svc -n $NAMESPACE | grep -i frontend
kubectl port-forward -n $NAMESPACE svc/<frontend-service> 8000:8000 &
curl -s localhost:8000/v1/models | jq -r '.data[].id'
curl -s localhost:8000/v1/chat/completions -H 'content-type: application/json' \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

Substitute the real service name and port from the first command. Expose the frontend outside the cluster only after the user approves an auth path (see `gateway-api-routing` in the Dynamo docs or an ingress with auth). Never expose it unauthenticated.

## Alternative: DynamoGraphDeploymentRequest

The quickstart uses a `DynamoGraphDeploymentRequest` (`v1beta1`) with `model`, `backend: auto`, `image` and `runtimeVersionOverride`; a profiler then creates the DGD. That path chooses a configuration for you and needs the planner image. It was read but not run here. Use it when the user wants automatic sizing; keep the hand-written DGD when you need control.

## Verify

```bash
kubectl get dynamographdeployment -n $NAMESPACE -o json | jq '.items[].status'
kubectl get pods -n $NAMESPACE -o wide
```

Then run the same load as the aggregated baseline and compare TTFT, ITL and throughput per GPU. Only keep the split if the numbers justify it and the `llm-evals` check shows no quality loss.
