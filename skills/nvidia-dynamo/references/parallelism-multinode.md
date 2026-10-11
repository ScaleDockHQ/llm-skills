# NVIDIA Dynamo disaggregation, Kubernetes and multinode

> Verified against Dynamo v1.5.1, 2026-10-11

Sources: disaggregated serving, KV routing and DGD guides; `examples/backends/vllm/` at v1.5.1.

## Disaggregated prefill/decode

Prefill workers compute the prompt KV cache; decode workers receive it over NIXL and generate tokens. Use it when
prefill and decode need separate scaling or parallelism. Skip it for short prompts, one GPU, or without a fast
interconnect (see `disaggregated-serving` skill for the gates).

Local (2 GPUs, vLLM, from a repo checkout of the same release):

```bash
cd $DYNAMO_HOME/examples/backends/vllm && bash launch/disagg.sh        # 1 prefill + 1 decode
bash launch/disagg_router.sh                                           # 2 + 2 workers, KV routing, 4 GPUs
```

The script starts `python -m dynamo.frontend`, a decode worker (`--disaggregation-mode decode`) and a prefill worker
(`--disaggregation-mode prefill`), both with `--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'`,
pinned with `CUDA_VISIBLE_DEVICES`, unique `VLLM_NIXL_SIDE_CHANNEL_PORT` and `DYN_SYSTEM_PORT` each. SGLang and
TensorRT-LLM have equivalent `launch/disagg.sh` presets. The frontend activates its prefill router after it discovers
compatible typed prefill and decode services for the same model and namespace. Adding another worker later needs no
frontend change.

## Kubernetes: DynamoGraphDeployment (DGD)

`nvidia.com/v1beta1`. A DGD lists `components` of `type` `frontend`, `worker`, `prefill` or `decode`; each has a `podTemplate`,
`replicas` and a command (`python3 -m dynamo.vllm`). Apply the templates (`templates/dgd-agg.yaml`,
`templates/dgd-disagg-router.yaml`), then:

```bash
kubectl create secret generic hf-token-secret --from-env-file=<(printf 'HF_TOKEN=%s\n' "$HF_TOKEN") -n <ns>
kubectl apply -f templates/dgd-agg.yaml -n <ns>
kubectl get dynamographdeployment -n <ns>; kubectl get pods -n <ns> -w
kubectl port-forward svc/<dgd-name>-frontend 8000:8000 -n <ns>
```

Frontend KV routing: env `DYN_ROUTER_MODE=kv` on the Frontend component. Exposure: the operator creates the
`<name>-frontend` Service; write your own Ingress or `LoadBalancer` Service, or use GAIE (`references/integrations.md`).
The v1alpha1 `ingress` field is gone in v1beta1.

## DGDR: describe intent, let Dynamo generate the DGD

`DynamoGraphDeploymentRequest` takes `model`, `backend`, optional `sla` (`ttft`, `itl` in ms), `searchStrategy`
(`rapid`: AIConfigurator estimates; `thorough`: benchmark candidates on GPUs), and `autoApply` (`false` stops after
generating so you can review). It is beta. Namespace-restricted installs must set `hardware.gpuSku`, `vramMb`,
`numGpusPerNode`. `templates/dgdr-rapid.yaml` is the minimal form.

## Multinode

- The operator needs **Grove** (default) or **LeaderWorkerSet**; otherwise multinode DGDs fail with a hard error.
  KAI Scheduler is optional but recommended with Grove. Compatibility matrix is in the install guide.
- Multinode tensor/pipeline-parallel vLLM: secondary nodes run `--headless`.
- **RDMA**: production disaggregation needs it (InfiniBand/RoCE, EFA on AWS, InfiniBand on Azure; see the RDMA setup
  guides). Without RDMA KV transfer falls back to TCP; upstream quotes about 98 s TTFT versus 200-500 ms.
- Rolling updates create generation-specific runtime namespaces; prefill and decode of one generation stay together
  and the frontend watches the namespace prefix. Plan `DYN_WORKER_GRACEFUL_SHUTDOWN_TIMEOUT` and migration
  (`--migration-limit`) so in-flight requests finish or move.
- Cloud guides: EKS, GKE, AKS (and Amazon ECS). Do not enable provider-managed GPU drivers and the GPU Operator driver together.
