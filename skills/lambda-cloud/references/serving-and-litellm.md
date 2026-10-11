# Lambda Cloud: serve a model and connect clients

> Verified against Lambda docs tutorials (Serving Llama 3.1 with Docker, Deploying Nemotron 3 Nano using vLLM, Serving Llama 3.1 405B on a 1-Click Cluster), vLLM OpenAI-compatible server docs v0.28.0 and the LiteLLM hosted_vllm usage in skills/cloud-llms assets, 2026-10-11

Lambda gives you a VM with drivers and Docker. You run the engine. Engine flags, tuning and hardening belong to the `self-hosted-llms` skill; this file covers what is Lambda-specific.

## Serve with vLLM in Docker (single instance)

SSH in (`ssh ubuntu@<ip>`), then keep the Hugging Face cache on persistent storage if you mounted a filesystem (default mount path `/lambda/nfs/<FILESYSTEM_NAME>`).

```bash
export HF_HOME=/lambda/nfs/models/hf          # persistent filesystem, survives termination
read -rs HF_TOKEN && export HF_TOKEN          # only for gated models; typed, never logged
sudo docker run -d --name vllm --gpus all --ipc=host \
  -v "$HF_HOME":/root/.cache/huggingface -p 8000:8000 \
  --env HF_TOKEN \
  vllm/vllm-openai:<pinned-tag> --model <org/model> --api-key "$VLLM_API_KEY"
```

Pin `<pinned-tag>` to a released vLLM version and the model to a revision. Lambda's Llama tutorial uses the same shape (`--gpus all --ipc=host`, mount the HF cache, publish 8000) and adds `--tensor-parallel-size 8` for a 70B model on an 8-GPU instance. The Nemotron tutorial instead installs vLLM with `uv pip install vllm --torch-backend=auto` and runs `vllm serve <model> --port 8000 --served-model-name <alias>` in a venv. Either works; Docker is easier to pin and remove.

Verify on the box:

```bash
curl -s http://localhost:8000/v1/models -H "Authorization: Bearer $VLLM_API_KEY" | jq '.data[].id'
```

## Expose it safely

The default firewall opens only SSH. Choose one:

1. SSH tunnel (no new exposure): `ssh -N -L 8000:localhost:8000 ubuntu@<ip>`, then clients use `http://localhost:8000/v1`.
2. Firewall ruleset allowing TCP 8000 only from your gateway's IP (create it in the instance's region, attach at launch; see `instances-api.md`).

The vLLM docs warn that `--api-key` only protects `/v1`, `/v2` and `/inference` paths and other routes (such as `/invocations`) stay unauthenticated, so do not rely on it alone; put a reverse proxy or the LiteLLM gateway in front and restrict the source CIDR.

## OpenAI-compatible clients

```python
import os
from openai import OpenAI
client = OpenAI(base_url="http://<instance-ip-or-tunnel>:8000/v1", api_key=os.environ["VLLM_API_KEY"])
print(client.chat.completions.create(model="<served-model-name>",
      messages=[{"role": "user", "content": "ping"}], max_tokens=16).choices[0].message.content)
```

## LiteLLM entry

Use the `hosted_vllm/` provider for a self-run vLLM server (same form as `cloud-llms/assets/litellm-hybrid.yaml`):

```yaml
model_list:
  - model_name: chat
    litellm_params:
      model: hosted_vllm/<served-model-name>
      api_base: http://<instance-private-or-tunnel-address>:8000/v1
      api_key: os.environ/LAMBDA_VLLM_API_KEY
      timeout: 120
```

Instance IPs change when you relaunch, so keep `api_base` in config or an env var and update it after each relaunch. Add a fallback to a managed API for outages or capacity failures (`llm-gateway`).

## Multi-node (1-Click Cluster)

Lambda's 405B tutorial uses vLLM's `run_cluster.sh` to start a Ray cluster over the InfiniBand fabric (`-e NCCL_IB_HCA=^mlx5_0`, `--privileged`), serves with `--tensor-parallel-size 8 --pipeline-parallel-size 2` and stores weights on the shared filesystem. See `storage-and-clusters.md`.

## Hosted inference

Lambda's own hosted Inference API (`https://api.lambda.ai/v1`, LiteLLM prefix `lambda_ai/`) was announced as sunset; do not build on it. See `troubleshooting.md`.

## Sources

- https://docs.lambda.ai/education/large-language-models/serving-llama-3-1-docker/
- https://docs.lambda.ai/education/large-language-models/deploying-nemotron-3-nano/
- https://docs.lambda.ai/education/large-language-models/serving-llama-3-1-405b/
- https://docs.vllm.ai/en/v0.28.0/serving/online_serving/openai_compatible_server/
