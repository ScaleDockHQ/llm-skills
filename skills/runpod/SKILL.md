---
name: runpod
description: Run LLMs on Runpod GPU Pods and Serverless (worker-vllm, vLLM, OpenAI-compatible endpoints) with runpodctl, then connect them to a gateway and tear down. Use for Runpod setup, runpodctl, API keys, network volumes, serverless vLLM, load-balancing endpoints, proxy.runpod.net 502, spend limits, LiteLLM api.runpod.ai, REST v1 retirement. Not for other clouds (use cloud-llms), gateway design (llm-gateway) or engine flags (vllm).
license: MIT
compatibility: Needs bash, curl, jq and runpodctl (brew, conda or install script), network access to runpod.io and api.runpod.ai, and a Runpod account with prepaid credits. Creating Pods, endpoints or volumes bills the account, so each needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Runpod

Get an LLM running on Runpod (a Pod or a Serverless vLLM endpoint), reachable by OpenAI-compatible clients and your gateway, with budget limits set and everything torn down when the work is done. Spell it **Runpod**, not "RunPod".

**Scope:** Runpod Pods, Serverless queue and load-balancing endpoints, worker-vllm, `runpodctl`, API keys and secrets, network volumes, billing controls and teardown.

**Out of scope:** choosing between providers (`cloud-llms`, `choosing-llm-hosting`), gateway routing and keys (`llm-gateway`, `litellm`), vLLM engine tuning (`vllm`), GPU sizing (`choosing-hardware`), training jobs (`fine-tuning-llms`), image or video models (`self-hosted-genmedia`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print variable names, never values, and never `cat` key files.

```bash
command -v runpodctl && runpodctl version
env | cut -d= -f1 | grep -E '^(RUNPOD|HF|OPENAI|LITELLM)_' || echo "no matching env vars"
ls -l ~/.config/runpod/api-key ~/.runpod/config.toml 2>&1     # permissions only; want -rw-------
runpodctl user | jq 'del(.email, .id)'                         # balance, spend per hour, spend limit
runpodctl pod list
runpodctl serverless list
runpodctl network-volume list
runpodctl gpu list
```

Find out what already exists and what it costs per hour before proposing anything. If `runpodctl` is missing or has no credentials, go to workflow 1.

## Decision flow

1. **One-off job, dev box or an always-on single model?** Use a **Pod** (`references/pods.md`).
2. **Bursty or spiky traffic, can tolerate a cold start, needs an OpenAI-compatible API?** Use **Serverless worker-vllm** (`references/serverless-vllm.md`). This is the default for LLM serving.
3. **Own server code or want no queue?** Use a **load-balancing endpoint** with `vllm/vllm-openai` (`references/serverless-vllm.md`).
4. **Only need a popular model, no hosting?** Use Runpod **Public Endpoints** (see the bottom of `references/serverless-vllm.md`), or a managed API through `cloud-llms`.
5. **Model weights large and reused?** Use a **network volume** (Pods) or **cached models** (Serverless).
6. **Clients and gateway:** go to `references/litellm-and-clients.md`.
7. **Something broke:** `references/troubleshooting.md`.
8. **Done or pausing:** `references/teardown.md`.

## Rules

- **Ask before anything billable.** Pods, endpoints, network volumes and active workers cost money. State GPU, count, max workers, storage and a stop time, then wait for approval.
- **Secrets stay secret.** API keys come from a `0600` file or environment variables, never from the command line when avoidable, never printed, committed or pasted in prompts. Use a **Restricted** API key and Runpod secrets (`{{ RUNPOD_SECRET_name }}`) for `HF_TOKEN`.
- **Pin versions.** Use `runpod/worker-v1-vllm:<release>` and `vllm/vllm-openai:<version>`, never `latest`, and pin model revisions where you can.
- **Budget controls before traffic.** Check the spend limit with `runpodctl user`, set low-balance alerts, set `max workers` and `active workers = 0`, and set `max_tokens` in clients.
- **Always tear down.** Stopped Pods still bill for storage, network volumes bill while they exist, and `wait_timeout` leaves a live resource. Finish every session with workflow 8.
- **Do not hardcode prices or quotas.** They change; read them from the console or `runpodctl gpu list`.
- **Protect endpoints.** Treat `*.proxy.runpod.net` and `api.runpod.ai` URLs as internet-facing. Keep auth on, and prefer a gateway in front.

## Workflows

### 1. Account and auth

- [ ] Account exists, credits added, low-balance alert on (human steps in the console).
- [ ] User created a **Restricted** API key and saved it to `~/.config/runpod/api-key` with `0600` (see `references/setup-and-auth.md`).
- [ ] `export RUNPOD_API_KEY="$(cat ~/.config/runpod/api-key)"`, then `runpodctl user` succeeds.
- [ ] Note the spend limit and `currentSpendPerHr` baseline.

### 2. Deploy a Pod

- [ ] `runpodctl gpu list` and `runpodctl template search vllm`; pick a GPU with enough VRAM (`choosing-hardware`).
- [ ] Get approval, then `runpodctl pod create ... --wait` with a pinned vLLM image and port `8000/http`.
- [ ] Start `vllm serve ... --host 0.0.0.0 --api-key ...` and test `https://<pod-id>-8000.proxy.runpod.net/v1/models`.
- [ ] Record the Pod id for teardown.

### 3. Deploy Serverless vLLM

- [ ] Choose `MODEL_NAME`, `MAX_MODEL_LEN`, GPU type, and a cap of `--workers-max` (start at 1 or 2).
- [ ] Create a Serverless template and endpoint with `--workers-min 0` after approval.
- [ ] Set `HF_TOKEN` via a Runpod secret for gated models; enable cached models for faster cold starts.
- [ ] Smoke test `GET /openai/v1/models` and one `chat/completions` call with a long timeout.

### 4. Connect to LiteLLM and clients

- [ ] Add a `model_list` entry (`openai/<served-name>`, `api_base` ending `/openai/v1`, `api_key: os.environ/RUNPOD_API_KEY`) from `references/litellm-and-clients.md`.
- [ ] Set a long gateway `timeout` for cold starts, add a fallback, and test through the gateway.

### 5. Scale

- [ ] `runpodctl serverless update <id> --workers-max <n>`; consider 1 active worker only when latency needs it.
- [ ] Re-check the 429 limits and the idle scale-down (max workers drops after 3 and 7 idle days).

### 6. Monitor cost

- [ ] `runpodctl user` (spend per hour), `runpodctl billing pods|serverless|network-volume`, `runpodctl serverless health <id>`.
- [ ] Use `llm-observability` for request-level cost and latency tracking.

### 7. Update

- [ ] Change the pinned image tag or env on a new template, point the endpoint at it, test, then delete the old template.
- [ ] For REST v1 or GraphQL scripts, migrate to REST API v2 before November 15, 2026.

### 8. Tear down

- [ ] Follow `references/teardown.md`: delete endpoints, Pods, network volumes, templates; revoke temporary keys.
- [ ] Verify empty lists and a near-zero `currentSpendPerHr`; remove gateway entries.

### 9. Troubleshoot

- [ ] Logs first (`runpodctl pod logs`, `runpodctl serverless logs`), then `references/troubleshooting.md`.

## Reference index

| File                                | Load when                                                                                 |
| ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `references/setup-and-auth.md`      | Account, API keys, secrets, runpodctl install and env vars, REST v1/v2 and GraphQL status |
| `references/pods.md`                | Renting a Pod, storage types, vLLM on a Pod, proxy URLs, network volumes                  |
| `references/serverless-vllm.md`     | worker-vllm, env vars, load-balancing endpoints, scaling defaults, cached models, Flash   |
| `references/litellm-and-clients.md` | Calling endpoints, rate limits, LiteLLM entries, OpenAI SDK and other clients             |
| `references/limits-and-costs.md`    | Billing, spend limits, platform limits, Pod vs Serverless cost                            |
| `references/teardown.md`            | Removing every billable resource and verifying nothing accrues                            |
| `references/troubleshooting.md`     | Symptom to cause to fix, with real error strings                                          |

## Companion skills

- `cloud-llms`: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms` (compare providers, hybrid setups)
- `llm-gateway`: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway` (one endpoint, keys, budgets)
- `choosing-llm-hosting`: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms` (the same stack on your own server)
- `llm-clients`: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`
- `llm-observability`: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`
- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `fine-tuning-llms`: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`
- `model-quantization`: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`
- `vllm`: `npx skills add ScaleDockHQ/llms-skills --skill vllm`
