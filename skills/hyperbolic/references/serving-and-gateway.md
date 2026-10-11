# Serving on a Hyperbolic box and wiring it to a gateway

> Verified against hyperbolic.ai/docs on-demand/managing-instances, on-demand/storage-and-ports, on-demand/troubleshooting, securing-open-ports, docs.litellm.ai/docs/providers/openai_compatible, 2026-10-11

Hyperbolic gives you a root-capable Ubuntu machine with preinstalled GPU drivers. There is no managed model endpoint any more, so you run the serving stack yourself.

## On the box

```bash
ssh -i ~/.ssh/<your_key> ubuntu@<instance-ip>   # copy the exact string from the Active Instances page
nvidia-smi                                      # drivers are preinstalled, do not reinstall them
df -h                                           # onboard NVMe is fixed per configuration
```

- Run long jobs under `tmux`, `screen` or a service, never tied to the SSH session.
- Onboard storage is mounted under `/home/ubuntu`, with extra space often at `/mnt` or `/data`. Mount points vary, so check `lsblk`.
- Persistent volumes appear as a block device (for example `/dev/vdb`). A new volume must be formatted once, then mounted. The storage page has the exact steps: https://hyperbolic.ai/docs/on-demand/storage-and-ports.
- Put model weights and checkpoints on a persistent volume, or be ready to re-download after termination.
- For which engine to run, flags, quantization and sizing, load the `self-hosted-llms` skill (`npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`). Pin the engine image tag and the model revision.
- Start the server with an API key set on the server itself. Whatever flag your engine uses, verify it in that engine's docs.

## Opening a port

- On virtual machines, request the port at creation with `customPorts` (up to 20), or open it later in the instance details page (see "opening inbound ports" in the storage and ports doc).
- Bind the service to `0.0.0.0`, not `localhost`, or it is unreachable from outside.
- Do not leave a model port open to the world without an API key. For a host firewall recipe and for restricting SSH to your own IP, read https://hyperbolic.ai/docs/securing-open-ports (written for `us-central-1` bare metal, adapt carefully).
- Safer pattern: keep the port closed and tunnel from the gateway host:

```bash
ssh -N -L 8000:127.0.0.1:8000 -i ~/.ssh/<your_key> ubuntu@<instance-ip>
# then the gateway uses http://127.0.0.1:8000/v1
```

## LiteLLM entry

An engine that speaks the OpenAI API is added as an `openai/` model with a custom `api_base`. Check https://docs.litellm.ai/docs/providers/openai_compatible for current syntax.

```yaml
model_list:
  - model_name: hyperbolic-llm # name your clients use
    litellm_params:
      model: openai/<served-model-name> # must match the engine's served model name
      api_base: http://<instance-ip>:8000/v1 # or http://127.0.0.1:8000/v1 over the tunnel
      api_key: os.environ/HYPERBOLIC_BOX_KEY # the key you set on the server
```

- Verify the model list first: `curl -sS $API_BASE/models -H "Authorization: Bearer $HYPERBOLIC_BOX_KEY" | jq '.data[].id'`.
- The box disappears when you terminate it. Remove or disable the LiteLLM entry at teardown so clients do not hit a dead host. With `llm-gateway` loaded, add a fallback to a hosted model.
- Do not use the LiteLLM `hyperbolic/` provider for new work. It targets the retired inference API (see `references/inference-retired.md`).

## Monitoring on the box

- GPU: `nvidia-smi`, `nvidia-smi dmon`. Real-time GPU metrics are an option at creation (`monitoringEnabled`) on supported instances: https://hyperbolic.ai/docs/on-demand/monitoring.
- Benchmark before trusting the box: https://hyperbolic.ai/docs/on-demand/verifying-performance, and the `bench.sh` shipped in `self-hosted-llms`.

## Maintenance and data safety

- Scheduled maintenance is announced by email, at least a week ahead where possible. The notice says whether the instance reboots (data kept) or is reprovisioned (onboard data lost).
- Use the dashboard Reboot action instead of `sudo reboot`. Where Reboot is not shown, contact support.
- Back up checkpoints to a volume or object storage on a schedule.
