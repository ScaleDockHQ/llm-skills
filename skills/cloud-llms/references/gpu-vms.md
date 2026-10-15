# Rented GPU VMs

> Verified against vLLM v0.31.0 docs (RunPod deployment guide, OpenAI-compatible server, security notes), runpodctl v2.15.0 README, vast-cli v1.8.3 README, Lambda on-demand instance docs, CoreWeave CKS docs, 2026-10-11

A cloud machine with GPUs running the same stack you would run on your own server: an engine, optionally llama-swap, and the LiteLLM gateway. The stack is owned by `self-hosted-llms`; this file is the cloud-side stack note.

Depth: install the provider skill (`npx skills add ScaleDockHQ/llm-skills --skill <skill>`): `runpod`, `lambda-cloud`, `vast-ai`, `coreweave`, `nebius`, `crusoe` and `hyperbolic`. Hyperscaler GPU instances (EC2, GCE, Azure VMs) have no skill yet; use their CLIs (`aws ec2`, `gcloud compute`, `az vm`).

## How it plugs into this stack

- Quota first: hyperscalers often default GPU quotas to zero per region (`cost-and-quotas.md`).
- Run the engine from `self-hosted-llms` and bind it to a private address; restrict the port to the gateway with a firewall, VPN or SSH tunnel.
- Endpoint: `http://<vm-private-ip>:8000/v1` (preferred) or the provider's proxy URL over TLS. Health: `/health`; models: `/v1/models`.
- `--api-key` protects only the `/v1`, `/v2` and `/inference` prefixes; other routes such as `/invocations` are not authenticated. Never rely on it alone.

```yaml
- model_name: <alias>
  litellm_params:
    model: hosted_vllm/<alias>
    api_base: http://10.0.0.1:8000/v1
    api_key: os.environ/CLOUD_VLLM_API_KEY
```

- Put `HF_HOME` on persistent storage; ephemeral disks re-download weights on every restart.
- Spot or interruptible instances only behind a gateway with fallbacks.
- Keep the gateway and VM in one region to avoid egress; stop or terminate idle instances (stopped usually still bills storage).
- Lambda has no stop, only terminate; running `shutdown` inside the VM keeps billing. On CoreWeave CKS do not install the NVIDIA GPU Operator. Nebius stopped VMs still count toward quota; Crusoe detached persistent disks still bill.
- Vast.ai: only destroying an instance or endpoint stops all billing; a stopped instance still bills storage and may lose its GPU. Runpod `--api-key` on a vLLM pod protects only `/v1`, `/v2` and `/inference`.
- Benchmark marketplace hosts before trusting them (`benchmarking-cloud.md`).

## Official links

- vLLM on RunPod: https://docs.vllm.ai/en/latest/deployment/frameworks/runpod/
- vLLM security: https://docs.vllm.ai/en/latest/usage/security/
