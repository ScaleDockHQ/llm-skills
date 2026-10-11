# DeepInfra private deployments and GPU instances

> Verified against DeepInfra docs (Deploy Private Models, Custom LLMs, GPU Instances, API reference: Deploy create LLM, GPU availability, stop, start, delete), 2026-10-11

Both resources bill per GPU-hour while running. Get the user's approval, a time budget and a stop condition before creating anything.

## Private LLM deployment

- Pick a GPU: the API enum lists `L4-24GB`, `L40S-48GB`, `A100-80GB`, `H100-80GB`, `H200-141GB`, `B200-180GB`, `B300-270GB`, `RTXPRO6000-96GB`, `other`; the guide text lists A100, H100, H200, B200 and B300. Check availability first:

```bash
curl -sS https://api.deepinfra.com/deploy/llm/gpu_availability -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq .
```

- Create (Dashboard, Deployments, New, Custom LLM, or API). Fixed parameters: `model_name`, `gpu`, `num_gpus` (1 to 8; weights must fit with room for KV cache), `hf.repo` (public or private Hugging Face repo; pass an HF token only as a variable, never inline), optional `container_image`, `extra_args`, and `standard_args` knobs (`max_context_size`, `max_concurrent_requests`, `gpu_memory_fraction`, `kv_cache_dtype`, `enable_prefix_caching`, `quantization` and others). Dynamic: `settings.min_instances` (0 means scale to zero) and `max_instances`.

```bash
curl -sS -X POST https://api.deepinfra.com/deploy/llm \
  -H "Content-Type: application/json" -H "Authorization: Bearer $DEEPINFRA_API_KEY" \
  -d '{"model_name":"my-model","gpu":"A100-80GB","num_gpus":2,"hf":{"repo":"<org/model>"},"settings":{"min_instances":0,"max_instances":1}}' \
  | jq '{deploy_id, status}'
```

The response is a `DeploymentOut` with `deploy_id`, `status` (for example `deployed`), `instances` (running, pending, warming) and `fail_reason`. A 402 means payment is required.

- The model's name for inference is `YOUR_GITHUB_USERNAME/model-name`; you can also use `deploy_id:<id>` as the `model` before it is running.
- Monitor: `GET /deploy/list`, `GET /deploy/{deploy_id}` (status route in the API reference), logs and stats under Dedicated Models.
- Change scale while running: `PUT /deploy/{deploy_id}` with `{"settings": {"min_instances": 1, "max_instances": 2}}`.
- Stop: `POST /deploy/{deploy_id}/stop`; resume: `POST /deploy/{deploy_id}/start`. Delete: `DELETE /deploy/{deploy_id}`.
- Limits in the guide: 4 GPU per user by default, GPU availability not guaranteed during scale-up (billed only for what runs), weekly invoices, quantization listed as not yet supported in the Custom LLM guide while the API exposes a `quantization` knob. Unverified: which applies; check the deploy-create page.

Unverified: whether `min_instances: 0` fully stops billing, and cold-start time. Treat scale to zero as an optimization and still delete or stop deployments when finished.

## LoRA adapters

LoRA language and image deployments are described under https://docs.deepinfra.com/private-models/lora.md and `lora-image.md`. They sit on supported base models; same per-hour caution applies. Unverified: billing details.

## GPU instances (rented containers)

Dedicated B200 and B300 configs with SSH, billed by the hour only while running. List current configs in the Dashboard (GPU Instances, New Container); the docs show configs like `1xB200-180GB` and `8xB200-180GB`. Do not copy prices.

```bash
curl -sS -X POST https://api.deepinfra.com/v1/containers \
  -H "Authorization: Bearer $DEEPINFRA_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"my-box","gpu_config":"1xB200-180GB","container_image":"di-cont-ubuntu-torch:latest","cloud_init_user_data":"#cloud-config\nusers:\n- name: ubuntu\n  shell: /bin/bash\n  sudo: '"'"'ALL=(ALL) NOPASSWD:ALL'"'"'\n  ssh_authorized_keys:\n  - <PUBLIC KEY LINE>"}' | jq .
curl -sS https://api.deepinfra.com/v1/containers/CONTAINER_ID -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq '{id, status}'
ssh ubuntu@<container-ip>
```

Use a public SSH key only; never paste a private key. States: `creating`, `starting`, `running`, `shutting_down`, `failed`, `deleted`. Terminate with `DELETE /v1/containers/{id}`; all container data is permanently lost, so copy results out first. Accept the NVIDIA license and mining-policy prompts in the UI flow.

## Official links

- Private models: https://docs.deepinfra.com/private-models/overview.md
- Custom LLMs: https://docs.deepinfra.com/private-models/custom-llms.md
- GPU instances: https://docs.deepinfra.com/gpu-instances/overview.md
