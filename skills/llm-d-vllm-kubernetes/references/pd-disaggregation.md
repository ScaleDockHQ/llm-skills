# Prefill/decode disaggregation with llm-d and vLLM

> Verified against llm-d v0.10.0, llm-d-router v0.11.0, vLLM NixlConnector (docs at v0.10.0), 2026-10-11

Split prompt processing (prefill) and token generation (decode) into separate pools, with the router choosing a pair and the KV cache moving by NIXL. Do this only after the aggregated baseline is measured. The `disaggregated-serving` skill covers when the split helps (it tunes TTFT and inter-token latency and does not by itself raise throughput) and the numerics gate.

## Layout of the guide

`guides/pd-disaggregation/` has `router/pd-disaggregation.values.yaml`, plus `modelserver/<accel>/<engine>/<provider>/` overlays. Providers for NVIDIA vLLM: `base`, `coreweave`, `aws`, `gke` (`gke/base`, `gke/a4x`, `gke/a4xmax`) and `cks-mooncake`.

Defaults (reference setup): model `openai/gpt-oss-120b`, decode 2 replicas at TP=4, prefill replicas at TP=1 (8x on H200 in the router comment), `--block-size=128`.

## Environment

```bash
export branch=v0.10.0
export GUIDE_NAME=pd-disaggregation
export NAMESPACE=llm-d-pd-disaggregation
export INFRA_PROVIDER=base      # base | coreweave | aws | gke/base | gke/a4x | gke/a4xmax
source ${REPO_ROOT}/guides/env.sh
```

Reuse the clone, CRDs, Secret steps and router chart variables from `install-baseline.md`.

## Router

```bash
helm install ${GUIDE_NAME} ${ROUTER_STANDALONE_CHART} \
  -f ${REPO_ROOT}/guides/recipes/router/base.values.yaml \
  -f ${REPO_ROOT}/guides/${GUIDE_NAME}/router/${GUIDE_NAME}.values.yaml \
  -n ${NAMESPACE} --version ${ROUTER_CHART_VERSION}
```

The values file configures an `EndpointPickerConfig` with two profiles: `prefill` (prefix-cache-affinity filter plus token-load scorer) and `decode` (active-request scorer), the `always-disagg-pd-decider` and the `disagg-profile-handler`. EPP replicas stay at 1 because the in-flight token accounting is per process. The `peakPrefillThroughput: 33821` there was measured for gpt-oss-120b with 8x prefill TP=1 on H200; re-measure with `calibrate.sh` for anything else.

## Model servers

```bash
kubectl kustomize ${REPO_ROOT}/guides/${GUIDE_NAME}/modelserver/gpu/vllm/${INFRA_PROVIDER} | grep -nE 'image:|REPLACE_'
kubectl apply -n ${NAMESPACE} -k ${REPO_ROOT}/guides/${GUIDE_NAME}/modelserver/gpu/vllm/${INFRA_PROVIDER}
```

Two things to check in the preview:

1. **Model server image.** The comment in the `base` overlay says the image component is deliberately set per provider overlay. The `coreweave` overlay includes `gpu-vllm/release`; if your preview still shows `REPLACE_MODEL_SERVER_IMAGE`, add `../../../../../recipes/modelserver/components/images/gpu-vllm/release` to a copy of the overlay.
2. **Router sidecar image.** The base overlay includes `routing-sidecar/nightly`, which resolves to the floating tag `main`. Replace it with `components/images/routing-sidecar/release` (`ghcr.io/llm-d/llm-d-router-disagg-sidecar:v0.11.0` at this tag) for anything beyond a throwaway test.

## Engine settings that matter

From the prefill and decode patches:

- `--kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer"|"kv_consumer","kv_buffer_device":"cuda","kv_connector_extra_config":{"backends":["UCX"]}}'` on prefill and decode respectively.
- `VLLM_NIXL_SIDE_CHANNEL_HOST` from the pod IP (`status.podIP`). The NIXL side channel is unauthenticated; keep it on a private pod network.
- A `NOTE` in the patches: vLLM 0.19 and 0.20 images ship both `nixl-cu13` and `nixl-cu12`, and NIXL can pick the wrong UCX libraries. Set `UCX_MODULE_DIR` only on a cu129 vLLM, as the comment says. Check the image's CUDA flavour before touching it.
- `--no-disable-hybrid-kv-cache-manager` is set for gpt-oss; keep flags the overlay sets unless you know why.
- RDMA: the coreweave overlay requests `rdma/ib: "1"` on both roles. Without a fast fabric, KV transfer over TCP can erase the benefit. See `nccl-rdma-networking`.
- Decode instances need a `routing sidecar` in front of the engine (the guide's `patch-sidecar.yaml`); that is why requests enter on port 8081 in the router values.

## Failure and scale-down behaviour

From `docs/operations/disaggregation/vllm.md`:

- vLLM can drain on SIGTERM with `--shutdown-timeout N` seconds, then aborts remaining requests.
- Scaling down decode frees the prefill blocks via a NIXL notification.
- Scaling down prefill cannot wait for in-flight KV reads; decode instances can set `kv_load_failure_policy=recompute` to recompute the prefill instead of returning errors.
- Prefill holds KV blocks under a lease (`kv_lease_duration`, default 30s), extended by decode heartbeats, so a crashed decode releases blocks within the lease.

## Verify

```bash
kubectl -n ${NAMESPACE} get pods -L llm-d.ai/role 2>/dev/null || kubectl -n ${NAMESPACE} get pods
kubectl -n ${NAMESPACE} logs deploy/$(kubectl -n ${NAMESPACE} get deploy -o name | grep prefill | head -1 | cut -d/ -f2) --tail=40 | grep -i nixl
export IP=$(kubectl get service ${GUIDE_NAME}-epp -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}')
```

Then send a long-prompt completion as in `install-baseline.md` and confirm in the logs that a prefill pod and a decode pod both handled it, and that KV transfer metrics move. Compare TTFT and inter-token latency against the aggregated baseline, and run a quality check with the `llm-evals` skill before keeping the split.

Monitoring for P/D: `kubectl apply -n ${NAMESPACE} -k ${REPO_ROOT}/guides/recipes/modelserver/components/monitoring-pd`.
