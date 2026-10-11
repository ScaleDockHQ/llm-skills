# KV cache transfer and networking

> Verified against NVIDIA Dynamo v1.5.1 docs, TensorRT-LLM 1.3.0rc22 to 1.3.0rc25, NIXL v1.3.1 to v1.4.0, 2026-10-11

Prefill workers compute the prompt KV cache and send it to decode workers. In Dynamo with TRT-LLM this uses NIXL (UCX backend by default) driven by `cache_transceiver_config` in the engine YAML.

## `cache_transceiver_config.backend`

| Value                            | Behaviour                                                                                                                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| not set                          | KV transfer disabled; disaggregated mode fails. A missing `cache_transceiver_config` caused a router e2e failure fixed in Dynamo 1.2.0.                                                   |
| `DEFAULT`                        | Uses the backend selected by the first of `TRTLLM_USE_NIXL_KVCACHE`, `TRTLLM_USE_UCX_KVCACHE`, `TRTLLM_USE_MOONCAKE_KVCACHE`, `TRTLLM_USE_MPI_KVCACHE` set to `1`; NIXL when none is set. |
| `NIXL`, `UCX`, `MOONCAKE`, `MPI` | Uses that backend and ignores the env vars.                                                                                                                                               |

The precedence matches TRT-LLM 1.3.0rc22 (`CacheTransceiverConfig._resolve_default_backend` in `tensorrt_llm/llmapi/llm_args.py`); re-check it against the 1.3.0rc25 image: `kubectl exec <pod> -- python3 -c 'import inspect, tensorrt_llm.llmapi.llm_args as m; print(inspect.getsource(m.CacheTransceiverConfig))'`.

NIXL backends: `UCX` (default) and `LIBFABRIC`. On AWS EFA, UCX with SRD transport is the tested and recommended path.

Related setting: `max_tokens_in_buffer` (for example 65536) must exceed the longest input sequence. If smaller, heavy load can exhaust KV, time out context transfers and leave workers hung until restart.

## RDMA is the difference

Dynamo falls back to TCP when RDMA is absent. The docs report roughly 98 s TTFT on TCP against about 200 to 500 ms with RDMA, a 200 to 500 times degradation. Treat RDMA as required for production disaggregation, and check before deploying:

```bash
kubectl get nodes -o json | jq -r '.items[] | [.metadata.name, (.status.allocatable["rdma/ib"] // .status.allocatable["vpc.amazonaws.com/efa"] // "none")] | @tsv'
kubectl get pods -A | grep -Ei 'network-operator|rdma|efa'
```

Provider guides in the Dynamo repo (`docs/fern/pages/kubernetes/installation/rdma-setup/`): overview, EFA on AWS, InfiniBand on Azure. The `nccl-rdma-networking` skill covers diagnosing a fabric with `ib_*` and `nccl-tests`.

Check the transport the workers picked after startup:

```bash
kubectl logs -n $NAMESPACE <prefill-pod> | grep -iE 'NixlTransfer|UCX|srd|rdmap|ib|tcp' | head
```

Expected lines include `NixlTransferAgent using NIXL backend: UCX`; on EFA `srd/rdmap*`; on InfiniBand RC or DC transports, not `tcp`.

## AWS EFA

- Image: the pre-built EFA image `nvcr.io/nvidia/ai-dynamo/tensorrtllm-runtime:1.3.0-efa` is documented for 1.3.0 (and `1.2.1-efa-amd64` for 1.2.1; `1.2.1-efa` was never published). Whether a `1.5.1-efa` tag exists was not confirmed. Check the Dynamo release-artifacts page, or mount the EFA SDK from the host as documented.
- Resources: `vpc.amazonaws.com/efa: "4"` as request and limit (the doc example uses 4).
- Env on both roles: `FI_PROVIDER=efa`, `FI_EFA_USE_DEVICE_RDMA=1`, `FI_EFA_ENABLE_SHM_TRANSFER=0` (SHM transfers break NIXL GPU buffer registration), `LD_LIBRARY_PATH=/opt/amazon/efa/lib:/usr/local/lib:/usr/lib`.
- The documented EFA setup needs `privileged: true`. That is a security decision for the user, not a default to add.

## Multinode decode: NIXL plugin ABI

On multinode decode the leader starts workers through `mpirun` and loads TRT-LLM's bundled NIXL. The container's default `NIXL_PLUGIN_DIR` points at system plugins that are ABI-incompatible. The docs' fix, on decode only:

```yaml
env:
  - name: NIXL_PLUGIN_DIR
    value: /opt/dynamo/venv/lib/python3.12/site-packages/tensorrt_llm/libs/nixl/plugins
```

Do not set it on prefill, which uses the system `nixl_cu13`. Path is from the docs at this version; verify it exists in the image (`kubectl exec ... -- ls`).

## GB200 NVL72

NCCL needs a `ComputeDomain` (`resource.nvidia.com/v1beta1`) with `numNodes` equal to the total nodes across prefill and decode, and both roles reference its `ResourceClaimTemplate`. NCCL env in the docs: `NCCL_MNNVL_ENABLE=1`, `NCCL_CUMEM_ENABLE=1`, `NCCL_NVLS_ENABLE=1`, `NVIDIA_GDRCOPY=1`. Without the ComputeDomain, workers fail with `NCCL error 'unhandled system error'` during model load. Other recipes in the repo use `UCX_TLS` settings such as `cuda_copy,cuda_ipc,tcp` with `UCX_CUDA_IPC_ENABLE_MNNVL=y` for NVLink KV transfer; these are model and rack specific and come with their recipe.

## NIXL versions in this release

Dynamo 1.5.1 pins NIXL v1.3.1, v1.3.2 and v1.4.0 across its images (container build context). The TRT-LLM runtime has its own bundled NIXL. Mixed versions across prefill and decode images are a risk; deploy both roles from the same image tag.

## Security

NIXL side channels and ports are unauthenticated. Keep them on a private pod network, apply `NetworkPolicy`, and do not expose worker ports.
