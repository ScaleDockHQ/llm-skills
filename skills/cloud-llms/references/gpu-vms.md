# Rented GPU VMs

> Verified against vLLM v0.31.0 docs (RunPod deployment guide, OpenAI-compatible server, security notes), runpodctl v2.15.0 README, RunPod Pods storage docs, vast-cli v1.8.3 README and Vast.ai storage docs, Lambda on-demand instance docs, CoreWeave CKS docs, AWS/Google Cloud/Azure spot and GPU docs, 2026-10-11

## What it is and when to choose it

A cloud machine with one or more GPUs, running the same self-hosted stack you would run on your own server: an engine (vLLM, SGLang, llama.cpp), optionally llama-swap, and the LiteLLM gateway. The stack itself is owned by the `self-hosted-llms` skill; this file covers what is different in the cloud.

Choose it for pilots before buying hardware, steady workloads where renting beats owning, burst capacity next to an owned server, or models that need datacenter GPUs.

| Provider type | Examples                                                         | Notes                                                             |
| ------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------- |
| GPU clouds    | Lambda, RunPod Pods, CoreWeave                                   | GPU-first; simpler pricing; CoreWeave is Kubernetes-centric (CKS) |
| Marketplace   | Vast.ai                                                          | Hosts of varying reliability; cheapest, least predictable         |
| Hyperscalers  | AWS EC2 GPU instances, Google Compute Engine GPUs, Azure GPU VMs | Your existing IAM, VPC and billing; tighter quotas                |

## Install / setup

1. **Quota first.** Hyperscalers often default GPU quotas to zero per region. Request them before launch (`cost-and-quotas.md`).
2. **Pick the GPU** by memory: weights + KV cache at your context length + headroom. Multi-GPU instances for tensor parallelism.
3. **Pick the image**: a CUDA-ready base or the pinned `vllm/vllm-openai:<version>` container.
4. **Storage for weights**: attach persistent storage so model downloads survive restarts (see pitfalls).
5. **Network**: open only SSH (from your IP) and the gateway port behind TLS. Never expose engine ports publicly.
6. **Deploy the stack** from `self-hosted-llms`, then register it in your main gateway (`gateway-hybrid.md`).

CLI examples (read-only first):

```bash
runpodctl pod list                       # RunPod: existing pods (API key from RUNPOD_API_KEY or ~/.runpod/config.toml)
vastai show instances                    # Vast.ai: existing instances
vastai search offers --help              # Vast.ai: filter syntax before searching
aws ec2 describe-instances --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Placement.AvailabilityZone]' --output text
gcloud compute instances list --format='table(name,zone,machineType.basename(),status)'
az vm list -d --query '[].{name:name,size:hardwareProfile.vmSize,state:powerState}' -o table
```

## Minimal working config

Start vLLM so it is reachable by the gateway, not the world:

```bash
# On the VM. The key is read from a file with restricted permissions, never typed inline.
export VLLM_API_KEY="$(cat ~/.config/llm/vllm.key)"
vllm serve <hf-org>/<model> \
  --host 0.0.0.0 --port 8000 \
  --served-model-name <alias> \
  --max-model-len <tokens> \
  --gpu-memory-utilization 0.90
```

Bind to `0.0.0.0` only when a firewall or security group restricts port 8000 to the gateway's address (or use a private network or an SSH tunnel). RunPod exposes HTTP ports through its proxy at `https://<pod-id>-8000.proxy.runpod.net` once the port is added to the pod's exposed HTTP ports.

## How it plugs into the stack

- Endpoint: `http://<vm-private-ip>:8000/v1` (preferred, over a private network or VPN) or the provider's proxy URL over TLS.
- Health: vLLM `/health`; models at `/v1/models`.
- Auth: `--api-key` / `VLLM_API_KEY` protects only the `/v1`, `/v2` and `/inference` path prefixes; other routes (notably `/invocations`) are not authenticated. Keep the engine on a private network behind the gateway.
- API coverage: OpenAI Chat Completions, Completions, Responses, Embeddings and the Anthropic Messages API from vLLM.

Gateway entry:

```yaml
- model_name: <alias>
  litellm_params:
    model: hosted_vllm/<alias>
    api_base: http://10.0.0.1:8000/v1
    api_key: os.environ/CLOUD_VLLM_API_KEY
```

## Operating

- **Ephemeral disks.** RunPod's container disk is lost on stop or restart; the volume disk survives until the pod is deleted; network volumes persist independently. Lambda instances can attach a persistent filesystem only at creation time. Vast.ai separates container storage from volumes. Hyperscaler instance-store (local NVMe) disks are wiped on stop. Put the Hugging Face cache (`HF_HOME`) on persistent storage.
- **Spot / interruptible instances** are cheaper but can be reclaimed with short notice (AWS Spot interruption notices, Google Spot VMs, Azure Spot VMs). Use them for batch or for replicas behind a gateway with fallbacks, not as the only replica for interactive traffic.
- **Egress.** Responses leaving the provider and cross-region traffic are billed on most clouds. Keep the gateway and the VM in the same region, or accept and budget the egress.
- **Stop when idle.** A stopped instance usually stops GPU billing but storage keeps billing; a terminated instance stops both and loses local disks.
- **Patching.** Drivers, CUDA, the engine image and the OS are yours to update.

## Tuning knobs worth knowing

- vLLM: `--max-model-len`, `--gpu-memory-utilization`, `--tensor-parallel-size`, `--max-num-seqs`, prefix caching; see `self-hosted-llms` for engine tuning.
- Instance choice: memory bandwidth drives decode speed; GPU memory drives max model and batch size.
- Region: pick one close to users and the gateway to cut network latency.

## Known pitfalls

- Re-downloading tens of gigabytes of weights on every restart because the cache is on an ephemeral disk.
- Binding to `127.0.0.1` behind a provider proxy, which returns 502 (vLLM's RunPod guide lists this, plus model still loading, port mismatch and GPU OOM).
- Leaving an instance running over a weekend.
- Relying on `--api-key` alone for security.
- Marketplace hosts with slow disks or networks; benchmark before trusting one (`benchmarking-cloud.md`).

## Official links

- vLLM on RunPod: https://docs.vllm.ai/en/latest/deployment/frameworks/runpod/
- vLLM security: https://docs.vllm.ai/en/latest/usage/security/
- runpodctl: https://github.com/runpod/runpodctl
- RunPod Pod storage: https://docs.runpod.io/pods/storage/types
- Vast.ai CLI: https://github.com/vast-ai/vast-cli
- Vast.ai storage: https://docs.vast.ai/guides/instances/storage/types
- Lambda on-demand instances: https://docs.lambda.ai/public-cloud/on-demand/
- CoreWeave Kubernetes Service: https://docs.coreweave.com/products/cks
- AWS accelerated computing instances: https://docs.aws.amazon.com/ec2/latest/instancetypes/ac.html
- AWS Spot interruptions: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-interruptions.html
- Google Cloud GPUs: https://docs.cloud.google.com/compute/docs/gpus
- Google Spot VMs: https://docs.cloud.google.com/compute/docs/instances/spot
- Azure VM sizes: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview
- Azure Spot VMs: https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms
