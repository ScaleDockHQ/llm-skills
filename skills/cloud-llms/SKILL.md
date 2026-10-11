---
name: cloud-llms
description: Run and consume LLMs in the cloud - pick a tier, provision, deploy, connect to one gateway endpoint, secure, set budgets, benchmark, scale, update and tear down. Covers frontier APIs (OpenAI, Anthropic Claude, Google Gemini), managed open-model APIs (Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter, Hugging Face Inference Providers), hyperscalers (AWS Bedrock, Google Gemini Enterprise Agent Platform / Vertex AI, Microsoft Foundry / Azure OpenAI), managed endpoints (SageMaker, Agent Platform endpoints, Azure ML online endpoints, Hugging Face Inference Endpoints), rented GPU VMs (Lambda, RunPod, Vast.ai, CoreWeave, EC2/GCE/Azure GPU instances), serverless GPU (RunPod Serverless vLLM worker, Modal) and Kubernetes (NVIDIA GPU Operator, vLLM, production-stack, KServe, llm-d, LeaderWorkerSet). Use for cloud LLM setup, LiteLLM cloud providers and fallbacks, hybrid local plus cloud routing, quotas, rate limits, IAM, private endpoints, data retention, GPU cost, cold starts, egress, cloud benchmarking.
license: MIT
compatibility: Cloud CLIs as needed (aws, gcloud, az, kubectl, helm, runpodctl, vastai, hf, modal); bash, curl, jq. Network access to the chosen providers.
metadata:
  author: ScaleDockHQ
  version: "1.0.1"
---

# Cloud LLMs

Workflows for running and consuming language models in the cloud, from a single API key to a GPU cluster on Kubernetes, with every cloud model reachable through the same gateway endpoint as local models.

**Work through the workflow that matches the task.** Each step names the reference to load. Take flags, config keys and API shapes from the reference or the linked official docs; do not improvise them.

## Scope

In scope: frontier and open-model APIs, hyperscaler model platforms, managed endpoints for your own model, rented GPU VMs, serverless GPU, Kubernetes serving, cloud entries in the gateway, cloud security, budgets, quotas, benchmarking and teardown.

Out of scope, with the owning skill: deciding whether to use the cloud at all (`choosing-llm-hosting`), general gateway features such as virtual keys, routing strategies and API bridging (`llm-gateway`), the self-hosted stack itself on a server you control (`self-hosted-llms`), eval methods (`llm-evals`), tracing and dashboards (`llm-observability`).

## Cloud tiers

| Tier                   | Use when                                                    | Reference                         |
| ---------------------- | ----------------------------------------------------------- | --------------------------------- |
| Frontier API           | Only a frontier model passes your eval                      | `references/frontier-apis.md`     |
| Managed open-model API | Open models, no ops team                                    | `references/open-model-apis.md`   |
| Hyperscaler platform   | Existing cloud contract, IAM, private networking, residency | `references/hyperscalers.md`      |
| Managed endpoint       | Your own or fine-tuned model, managed serving               | `references/managed-endpoints.md` |
| Rented GPU VM          | Run your own stack on rented hardware                       | `references/gpu-vms.md`           |
| Serverless GPU         | Custom model, spiky traffic, cold starts acceptable         | `references/serverless-gpu.md`    |
| Kubernetes             | Many models or replicas, platform team, autoscaling         | `references/kubernetes.md`        |

If the tier is not decided yet, use `choosing-llm-hosting` first.

## Discover first

Read-only. Never print key values, tokens or credential files.

```bash
# Which cloud CLIs are installed
for c in aws gcloud az kubectl helm runpodctl vastai hf modal litellm; do
  command -v "$c" >/dev/null && echo "found: $c"
done

# Who am I, which account/project/region (identity only, no secrets)
aws sts get-caller-identity --query '[Account,Arn]' --output text 2>/dev/null
aws configure get region 2>/dev/null
gcloud config list --format='value(core.account,core.project,compute.region)' 2>/dev/null
az account show --query '{subscription:name,id:id}' -o tsv 2>/dev/null
kubectl config current-context 2>/dev/null
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu' 2>/dev/null
runpodctl pod list 2>/dev/null
vastai show instances 2>/dev/null
hf auth whoami 2>/dev/null
modal profile current 2>/dev/null

# Provider keys present (names only)
env | cut -d= -f1 | grep -E '_(API_KEY|TOKEN)$|^AWS_PROFILE$' | sort

# Existing gateway config and health
grep -l 'model_list' ./*.y*ml ~/.config/litellm/*.y*ml 2>/dev/null
curl -s -o /dev/null -w '%{http_code}\n' "${LLM_BASE_URL:-http://localhost:4000}/health/liveliness"
```

From the output, note: authenticated clouds, default account/project/region, existing GPU nodes, existing gateway and its model aliases. Ask only for what is still missing: the target workload, data classification, region constraints, and budget ceiling.

## Rules

- **Least privilege, short-lived credentials.** Prefer IAM roles, workload identity and managed identities over static keys; scope keys per project.
- **Budgets and alerts before traffic.** Set cloud budgets, provider spend limits and gateway budgets before the first real request.
- **Pin model versions.** Use dated or versioned model IDs and image tags, never "latest", in anything that serves users.
- **Know the data path.** For every provider: retention, region, training use, and every hop (gateway, logs, traces).
- **Request quota before you need it.** GPU and model quotas start low and increases take time.
- **Scale to zero only where cold starts are acceptable.** Interactive users should not wait for weights to load.
- **Idle GPUs and egress are the hidden bill.** Stop what is idle; keep traffic in-region.
- **Measure before and after.** Benchmark every deploy, scale or update with the same protocol.
- **Secrets never touch output.** No keys in logs, shell history, manifests, tickets or chat; reference them by name.
- **Downtime is a decision.** Updates and teardowns that interrupt traffic are scheduled and announced, or done with a fallback in place.

## Workflows

### 1. Pick a tier

- [ ] Run [Discover first](#discover-first).
- [ ] Confirm the data class and region; read the provider's data terms → `references/security-compliance.md`.
- [ ] Choose the tier from the table above (or run `choosing-llm-hosting`).
- [ ] Shortlist models; plan an eval on real tasks (`llm-evals`).

### 2. Provision

- [ ] Create or select the account/project/subscription and region.
- [ ] Create least-privilege identities and store secrets in a secret manager → `references/security-compliance.md`.
- [ ] Check and request quotas (model TPM/RPM, GPU instances) → `references/cost-and-quotas.md`.
- [ ] Set budgets and alerts → `references/cost-and-quotas.md`.
- [ ] API tiers: create keys, enable model access → `references/frontier-apis.md`, `references/open-model-apis.md`, `references/hyperscalers.md`.
- [ ] GPU tiers: pick instance type, disk for model cache, network rules → `references/gpu-vms.md`, `references/kubernetes.md`.

### 3. Deploy (your own model)

- [ ] Managed endpoint → `references/managed-endpoints.md`.
- [ ] GPU VM: run the self-hosted stack (`self-hosted-llms`) with cloud specifics → `references/gpu-vms.md`.
- [ ] Serverless → `references/serverless-gpu.md`.
- [ ] Kubernetes: `assets/k8s/vllm-deployment.yaml` or `assets/k8s/kserve-inferenceservice.yaml` → `references/kubernetes.md`.
- [ ] Pin the image tag and model revision; verify `/health` and `/v1/models`.

### 4. Connect to the gateway

- [ ] Add cloud entries next to local models in the same LiteLLM config: `assets/litellm-hybrid.yaml` → `references/gateway-hybrid.md`.
- [ ] Map aliases clients already use; add fallbacks that respect the data floor.
- [ ] Test each alias with a minimal request; confirm the response comes from the expected backend.

### 5. Secure

- [ ] Private networking where available (PrivateLink, Private Service Connect, Private Link) → `references/security-compliance.md`.
- [ ] No public engine ports; only the gateway is exposed, behind TLS and auth.
- [ ] Logging and tracing retention set; PII handling decided.

### 6. Set budgets

- [ ] Cloud budget alerts at several thresholds → `references/cost-and-quotas.md`.
- [ ] Provider spend limits where offered.
- [ ] Gateway budgets per provider/model/key → `references/gateway-hybrid.md` (details in `llm-gateway`).

### 7. Benchmark

- [ ] Run `scripts/bench.sh` against the gateway and directly against the backend → `references/benchmarking-cloud.md`.
- [ ] Record median TTFB, decode tok/s, prefill tok/s and aggregate tok/s under concurrency, with region and time of day.

### 8. Scale

- [ ] APIs: raise rate-limit tier or quota; add a second provider or region as a fallback.
- [ ] GPUs: add replicas; autoscale on queue depth, not GPU utilization → `references/kubernetes.md`.
- [ ] Re-benchmark after scaling.

### 9. Update

- [ ] New model or version: add it under a test alias, eval, then repoint the alias.
- [ ] New engine image: roll out one replica first, benchmark, then the rest.
- [ ] Keep the previous version as a fallback until the change is proven.

### 10. Tear down

- [ ] Remove the gateway entries first so no client traffic reaches the backend.
- [ ] Delete endpoints, instances, node pools, load balancers, volumes and snapshots.
- [ ] Revoke keys and delete identities created for the deployment.
- [ ] Check the billing console the next day for anything still accruing → `references/cost-and-quotas.md`.

When something fails at any step → `references/troubleshooting.md`.

## References

- `references/frontier-apis.md`: OpenAI, Anthropic, Google Gemini; keys, rate-limit tiers, batch APIs, prompt caching, data retention.
- `references/open-model-apis.md`: Together AI, Fireworks AI, Groq, DeepInfra, OpenRouter, Hugging Face Inference Providers; verified OpenAI-compatible base URLs.
- `references/hyperscalers.md`: AWS Bedrock, Gemini Enterprise Agent Platform (Vertex AI), Microsoft Foundry / Azure OpenAI; model access, regions, quotas, private networking, IAM.
- `references/managed-endpoints.md`: SageMaker, Agent Platform (Vertex AI) endpoints, Azure ML online endpoints, Hugging Face Inference Endpoints.
- `references/gpu-vms.md`: Lambda, RunPod pods, Vast.ai, CoreWeave, hyperscaler GPU instances; ephemeral disks, spot, quotas, egress.
- `references/serverless-gpu.md`: RunPod Serverless vLLM worker, Modal; cold starts, scale to zero.
- `references/kubernetes.md`: GPU Operator, vLLM manifests, production-stack, KServe, llm-d, LeaderWorkerSet, model caching, autoscaling.
- `references/gateway-hybrid.md`: LiteLLM entries for cloud providers, fallbacks and budgets next to local models.
- `references/cost-and-quotas.md`: budgets, alerts, quota requests, cost formulas, teardown checks.
- `references/security-compliance.md`: IAM, secret managers, private endpoints, logging and PII, residency.
- `references/benchmarking-cloud.md`: protocol, network latency, provider variance, `scripts/bench.sh`.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/example.md`: anonymized hybrid with a local DGX Spark primary and cloud overflow plus frontier behind one LiteLLM endpoint.
- `assets/litellm-hybrid.yaml`, `assets/k8s/vllm-deployment.yaml`, `assets/k8s/kserve-inferenceservice.yaml`.

Companion skills: `choosing-llm-hosting`, `self-hosted-llms`, `llm-gateway`, `llm-evals`, `llm-observability`, `llm-clients`, `local-llms`, `model-quantization`, `fine-tuning-llms`, `self-hosted-genmedia`. Install with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.
