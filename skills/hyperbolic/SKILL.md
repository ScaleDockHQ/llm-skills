---
name: hyperbolic
description: Hyperbolic GPU cloud - rent, run and tear down on-demand or reserved H100/H200/B200/B300 VMs and bare metal to self-host LLMs, via app.hyperbolic.ai or the api.hyperbolic.ai v2 API. Use for "Hyperbolic", "hyperbolic.xyz", "rent a GPU on Hyperbolic", HYPERBOLIC_API_KEY, spot or reserved rentals, storage volumes, instance SSH, balance or auto top-up, or "Hyperbolic inference API stopped working" (the serverless API is retired). Not for hosted per-token models (use cloud-llms) or serving on the box (use self-hosted-llms).
license: MIT
compatibility: macOS or Linux shell with curl, jq and ssh. Needs a Hyperbolic account with a funded balance and an API key in a 0600 file or HYPERBOLIC_API_KEY. Creating rentals, reservations, volumes or auto top-up costs money and needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Hyperbolic

Rent a Hyperbolic GPU, run an open model on it, expose it behind your gateway, watch the spend and terminate it. Hyperbolic is now a GPU cloud: the serverless inference API and playground are retired, so this skill covers renting GPUs and nothing else.

**Scope:**

- In: account and API key, finding capacity, creating and terminating rentals (virtual machine or bare metal), spot and reserved terms, storage volumes, SSH keys, balance and auto top-up, handing the box to a serving stack.
- Out: choosing a hosting tier (`choosing-llm-hosting`), per-token hosted APIs (`cloud-llms`), vLLM/SGLang tuning and sizing (`self-hosted-llms`), the gateway itself (`llm-gateway`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print environment variable names, never values.

```bash
env | cut -d= -f1 | grep -iE '^HYPERBOLIC' || echo "no HYPERBOLIC_* vars"
ls -l ~/.config/hyperbolic/ 2>/dev/null          # expect a 0600 key file if you keep one
export HYPERBOLIC_API_KEY="$(cat ~/.config/hyperbolic/api_key)"   # never echo it
curl -sS https://api.hyperbolic.ai/v2/users/me -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq 'keys'   # field names only
curl -sS https://api.hyperbolic.ai/v2/customer/balance -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq .
curl -sS "https://api.hyperbolic.ai/v2/on-demand/rentals/active" -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq .
```

Any rental already listed is billing now. Report it before doing anything else.

## Decision flow

1. User code calls `api.hyperbolic.xyz/v1/chat/completions` or the playground and fails: that product is retired (`references/inference-retired.md`). Offer a rented GPU with `self-hosted-llms`, or a hosted provider from `cloud-llms`.
2. Short experiment, no commitment: on-demand VM. Interruptible and cheaper: spot where the console offers it.
3. A 24/7 service: compare reserved terms with on-demand in the console. Reserved is paid up front and cannot be terminated early.
4. 8+ GPUs or InfiniBand: bare metal, whole nodes (multiples of 8).
5. Checkpoints or weights that must survive termination: attach a storage volume.
6. A cluster you manage with kubectl: managed Kubernetes (beta), see the console docs.

## Rules

- **Ask before creating billable resources.** Show GPU type, count, region, term, hourly rate and the exact request, then wait for a yes. Same for reservations, volumes and auto top-up.
- **Secrets never print.** The API key lives in a `0600` file or an environment variable. Public SSH keys only; never upload a private key.
- **Budget first.** Check the balance and the hourly rate before creating. Rentals end when the balance is no longer positive, so set an alert level, or auto top-up only if the user wants it. See `references/billing-and-teardown.md`.
- **Pin versions on the box.** Pin the vLLM image tag and the model revision. Do not install or upgrade GPU drivers; they are preinstalled.
- **Treat onboard NVMe as scratch.** It does not survive termination or reprovisioning. Copy results to a volume or object storage first.
- **Do not expose the model port raw.** Bind to `0.0.0.0` only with an API key on the server and a firewall (`references/serving-and-gateway.md`).
- **Always tear down.** Every session ends with a terminate and a check that no rental is active.
- **Use v2.** The quickstart still shows older `/v1/marketplace/...` calls. The API reference marks those deprecated.

## Workflows

### 1. Account and auth

- [ ] Sign up at app.hyperbolic.ai; deposit credit (free tier cannot launch GPUs). Create an API key in settings and save it once, it cannot be viewed again.
- [ ] Add an SSH public key under Settings, SSH Keys.
- [ ] Verify with `GET /v2/users/me`. Details: `references/setup-and-auth.md`.

### 2. Find capacity and rent

- [ ] `GET /v2/on-demand/rental-options`, filter with jq on `gpuType`, `region`, `enabled`, `costPerHourCents`.
- [ ] Get approval, then `POST /v2/on-demand/rentals`. Details: `references/rentals-api.md`.
- [ ] Wait for Ready; SSH is only available then. Billing starts at Ready.

### 3. Serve a model

- [ ] SSH in as `ubuntu`, run `nvidia-smi`, start the server with a pinned image and a server-side API key. See `references/serving-and-gateway.md` and the `self-hosted-llms` skill.

### 4. Connect to LiteLLM or OpenAI clients

- [ ] Open the one port you need (custom ports are set at creation on VMs), then add an `openai/` model entry with `api_base` set to the box. See `references/serving-and-gateway.md`.

### 5. Scale

- [ ] More GPUs: a larger rental, or a second rental behind the gateway. Multi-node needs bare metal or a cluster-capable region.

### 6. Monitor cost

- [ ] `GET /v2/on-demand/active-rental-summary` for count and hourly cost, `GET /v2/customer/balance` for balance.

### 7. Update

- [ ] Change the model or image on the box and restart. A new GPU type means a new rental, then terminate the old one.

### 8. Tear down

- [ ] Copy anything you need off the box, `POST /v2/on-demand/rentals/terminate`, delete unused storage volumes, re-run the active list. Details: `references/billing-and-teardown.md`.

### 9. Troubleshoot

- [ ] SSH, stuck pending, no GPUs in `nvidia-smi`, unexpected termination: `references/troubleshooting.md`.

## Reference index

- `references/setup-and-auth.md`: account tiers, API key, SSH keys, hosts and auth header.
- `references/rentals-api.md`: v2 endpoints, create-rental fields, spot and reserved.
- `references/serving-and-gateway.md`: running vLLM on the box and wiring it to LiteLLM.
- `references/billing-and-teardown.md`: when billing starts, balance rules, terminate and verify.
- `references/inference-retired.md`: what happened to the serverless API and what to use now.
- `references/troubleshooting.md`: common failures and API error codes.

## Companion skills

- `cloud-llms`: hosted APIs and other cloud tiers. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM in front of the rented box. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `self-hosted-llms`: vLLM, SGLang and sizing on a GPU server. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `choosing-llm-hosting`: pick between laptop, owned GPUs and cloud. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `llm-observability`: traces and spend once the box is serving. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`.
