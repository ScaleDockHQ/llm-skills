# Lambda Cloud: instances through the API

> Verified against Lambda Cloud API docs (OpenAPI spec 1.10.0: instance-types, images, instances, instance-operations, firewall-rulesets) and On-Demand Cloud overview and Creating and managing instances pages, 2026-10-11

All calls assume `LAMBDA_API_KEY` is exported from a `0600` file (see `setup-and-auth.md`). Nothing below prints the key.

## Pick a type and region from live data

Do not copy a price table. The API returns current price and capacity.

```bash
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instance-types \
  | jq -r '.data | to_entries[]
      | select(.value.regions_with_capacity_available|length>0)
      | [.key, .value.instance_type.gpu_description, (.value.instance_type.specs.gpus|tostring)+" GPU",
         (.value.instance_type.price_cents_per_hour|tostring)+" cents/h",
         ([.value.regions_with_capacity_available[].name]|join(","))] | @tsv'
```

`price_cents_per_hour` is US cents per hour. An empty `regions_with_capacity_available` means no capacity right now. The docs list instance families such as B200, GH200, H100 SXM and PCIe, A100, A10, A6000 and V100, with 1, 2, 4 or 8 GPUs on some types; the live call is authoritative. GH200 has an ARM CPU, so verify your stack runs on arm64 first.

Regions seen in the docs include `us-east-1`, `us-west-1`, `us-south-1`, `europe-central-1`, `asia-northeast-1` and others; list them with `GET /regions`.

## Images

```bash
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/images | jq '.data[]|{family,name,architecture}'
```

Documented image families: `lambda-stack-24-04`, `lambda-stack-22-04`, `lambda-stack-legacy-22-04` (V100), `gpu-base-24-04`, `gpu-base-22-04`, `ubuntu-24-04`, `ubuntu-22-04`. If you omit `image` the latest Lambda Stack image is used, which preinstalls NVIDIA driver, CUDA, cuDNN, NCCL, container toolkit, Docker and PyTorch. Pin a family explicitly for reproducibility.

## Launch (billable, ask first)

`POST /instance-operations/launch`. Required: `region_name`, `instance_type_name`, `ssh_key_names` (exactly one). Optional: `file_system_names`, `file_system_mounts`, `hostname`, `name`, `image` (`{"family": ...}` or `{"id": ...}`), `user_data` (cloud-init, plain text), `tags`, `firewall_rulesets` (must be in the same region).

```bash
cat > /tmp/launch.json <<'EOF'
{
  "region_name": "us-east-1",
  "instance_type_name": "gpu_1x_example",
  "ssh_key_names": ["my-key"],
  "file_system_names": ["models"],
  "name": "llm-serve-1",
  "image": {"family": "lambda-stack-24-04"},
  "tags": [{"key": "owner", "value": "me"}, {"key": "purpose", "value": "llm-serve"}],
  "firewall_rulesets": [{"id": "<ruleset-id>"}]
}
EOF
curl -sS -X POST -H "Authorization: Bearer $LAMBDA_API_KEY" -H 'Content-Type: application/json' \
  -d @/tmp/launch.json https://cloud.lambda.ai/api/v1/instance-operations/launch | jq
```

Replace the placeholders with values from `/instance-types`, `/ssh-keys` and `/file-systems`. The response is `{"data": {"instance_ids": [...]}}`. Tag keys starting `lambda-ai-` are reserved. Launch is limited to one request per 12 seconds.

Billing begins when the instance is launched and passes health checks.

## Poll until active

```bash
ID=<instance-id>
until [ "$(curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instances/$ID | jq -r .data.status)" = active ]; do sleep 15; done
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instances/$ID | jq '.data|{ip,private_ip,status}'
```

Statuses: `booting`, `active`, `unhealthy`, `terminated`, `terminating`, `preempted`. Instance IP is `ip`; user is `ubuntu`: `ssh ubuntu@<ip>`. JupyterLab may take a few minutes after launch.

## List, restart, update, terminate

- List: `GET /instances` (all, oldest first, unless you pass `page_size` or `page_token`; then newest first, 1-100 per page). Filter a cluster with `cluster_id`.
- Details: `GET /instances/{id}`.
- Update name or tags: `POST /instances/{id}` with `name` and or `tags`; a provided `tags` list replaces existing tags.
- Restart: `POST /instance-operations/restart` with `{"instance_ids":[...]}`.
- Terminate: `POST /instance-operations/terminate` with `{"instance_ids":[...]}`. This erases the instance's root disk; see `teardown.md`.

Instances can only be launched, restarted or terminated. There is no stop or snapshot; keep state in a filesystem or a container image, and back up data.

## Firewall rulesets

Only TCP 22 (SSH) and ICMP are open by default. Create a ruleset in the target region (`POST /firewall-rulesets`, or the console Firewall page), then pass its id at launch. Allow the serving port from a specific source CIDR, not `0.0.0.0/0`, or skip the rule and use `ssh -L 8000:localhost:8000`. See the API browser for the rule body schema.

## Sources

- https://docs.lambda.ai/api/cloud
- https://docs.lambda.ai/public-cloud/on-demand/
- https://docs.lambda.ai/public-cloud/on-demand/creating-managing-instances/
