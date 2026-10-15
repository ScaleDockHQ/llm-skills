---
name: lambda-cloud
description: Run LLMs on Lambda Cloud (Lambda, lambda.ai) GPU instances, 1-Click Clusters and filesystems through the Cloud API. Use for "launch a Lambda instance", "cloud.lambda.ai/api/v1", "Lambda On-Demand Cloud", "1-Click Cluster", "Lambda filesystem", "serve vLLM on Lambda", "insufficient-capacity", "global/quota-exceeded", terminating Lambda instances, or connecting a Lambda GPU box to LiteLLM. Notes that the hosted Lambda Inference API was announced as sunset. For provider choice and cross-provider workflow use cloud-llms; for the gateway use llm-gateway; for the serving engine use self-hosted-llms.
license: MIT
compatibility: Needs bash, curl and jq, an SSH client and a Lambda Cloud account with an API key in a 0600 file or environment variable. Launching, restarting and terminating instances, creating filesystems and reserving clusters bill money and need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Lambda Cloud

Get an LLM running on a rented Lambda GPU instance (or cluster), reachable through an OpenAI-compatible endpoint, with spend under control and a verified teardown. Lambda sells GPU virtual machines, not per-token inference.

**Scope:** Lambda On-Demand Cloud (ODC) instances, 1-Click Clusters (1CC), filesystems, firewall rulesets, SSH keys and the Cloud API at `https://cloud.lambda.ai/api/v1`. Out of scope: choosing a provider and the cross-provider flow (`cloud-llms`), the gateway itself (`llm-gateway`), vLLM flags and tuning (`self-hosted-llms`), picking hosting at all (`choosing-llm-hosting`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print the key.

```bash
command -v curl jq ssh
# key present? (names only, never values)
env | cut -d= -f1 | grep -i -E 'LAMBDA' || echo "no LAMBDA_* env var"
KEYFILE="${LAMBDA_API_KEY_FILE:-$HOME/.config/lambda/api-key}"
[ -f "$KEYFILE" ] && stat -f '%Lp' "$KEYFILE" 2>/dev/null || stat -c '%a' "$KEYFILE" 2>/dev/null
# what is already running (these bill by the minute)
curl -sS -H "Authorization: Bearer $(cat "$KEYFILE")" https://cloud.lambda.ai/api/v1/instances \
  | jq '.data[] | {id,name,status,region:.region.name,type:.instance_type.name}'
curl -sS -H "Authorization: Bearer $(cat "$KEYFILE")" https://cloud.lambda.ai/api/v1/file-systems | jq '.data[]|{id,name,region:.region.name}'
```

The API allows about one request per second. A key file must be mode `600`.

## Decision flow

1. Need hosted per-token inference? Lambda's Inference API and Lambda Chat were announced as sunset (see `references/troubleshooting.md`). Use `cloud-llms` to pick a managed API instead.
2. One model, one to eight GPUs: On-Demand Cloud instance, then `references/instances-api.md` and `references/serving-and-litellm.md`.
3. Multi-node (16 to 512 GPUs, InfiniBand): 1-Click Cluster reservation, console only, then `references/storage-and-clusters.md`.
4. Weights or caches that must survive termination: a filesystem attached at launch (cannot be attached later).
5. Unsure about price or capacity: read `references/limits-and-billing.md`. Do not guess prices; query `/instance-types`.

## Rules

- **Ask before creating billable resources.** Instances, filesystems and cluster reservations bill; show type, region, count and filesystem, then wait for approval.
- **Secrets never touch output.** Read the API key from a `0600` file or `LAMBDA_API_KEY`; never `echo` it, never put it in a URL, never commit it. API keys have full account access, so one key per tool and delete unused ones.
- **Pin what you serve.** Pin the image family (for example `lambda-stack-24-04`), the vLLM version and the model revision.
- **Open ports deliberately.** Only SSH (22) is open by default. Create a firewall ruleset for the serving port with a source CIDR, or tunnel over SSH. A raw vLLM `--api-key` is not enough on the open internet (see `self-hosted-llms`).
- **Terminate through the API or console only.** `shutdown` or `poweroff` inside the VM leaves it in an alert state and billing continues.
- **Billing runs until terminated.** There is no stop or pause for ODC instances: only launch, restart, terminate. Filesystems bill while they exist.
- **Always tear down.** Follow `references/teardown.md` and verify nothing is left.

## Workflows

### Account and auth

- [ ] Create an SSH key and an API key in the console, save the API key to a `0600` file -> `references/setup-and-auth.md`
- [ ] Check read-only calls work (`/instance-types`, `/instances`) -> `references/setup-and-auth.md`

### Launch an instance and serve a model

- [ ] Pick type and region from live capacity -> `references/instances-api.md`
- [ ] Optionally create a filesystem and a firewall ruleset first -> `references/storage-and-clusters.md`
- [ ] Get approval, launch, poll until `active` -> `references/instances-api.md`
- [ ] Start vLLM in Docker or a venv, verify `/v1/models` -> `references/serving-and-litellm.md`

### Connect to a gateway or client

- [ ] Add a `hosted_vllm/` entry to LiteLLM, or point an OpenAI SDK at the instance -> `references/serving-and-litellm.md`

### Scale, monitor cost, update

- [ ] Scale by launching more instances behind the gateway; one SSH key per launch call -> `references/instances-api.md`
- [ ] Check live status and cost drivers -> `references/limits-and-billing.md`
- [ ] Update by launching a new instance, shifting gateway traffic, then terminating the old one

### Tear down

- [ ] Back up what you need, terminate instances, delete filesystems and firewall rulesets, verify -> `references/teardown.md`

### Troubleshoot

- [ ] Match the error code or symptom -> `references/troubleshooting.md`

## Reference index

- `references/setup-and-auth.md`: account, API keys, SSH keys, workspaces, roles, auth header, rate limits.
- `references/instances-api.md`: instance types, images, launch, list, restart, terminate, tags, user data.
- `references/serving-and-litellm.md`: vLLM on an instance, firewall, OpenAI client, LiteLLM entry.
- `references/storage-and-clusters.md`: filesystems, S3 adapter, 1-Click Clusters, multi-node serving.
- `references/limits-and-billing.md`: quota, capacity, billing model, how to see spend.
- `references/teardown.md`: stop all billing and verify.
- `references/troubleshooting.md`: error codes and symptoms, the Inference API sunset.

## Companion skills

- `cloud-llms`: cross-provider workflow, tiers, budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM gateway in front of the instance. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM and engine choice, tuning, hardening. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `choosing-llm-hosting`: laptop vs owned GPU vs cloud. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
- `llm-evals`: check quality and speed on the new box. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`.
- `llm-observability`: traces and metrics for the endpoint. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
