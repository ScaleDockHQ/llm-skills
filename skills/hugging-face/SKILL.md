---
name: hugging-face
description: Use Hugging Face (huggingface.co) to download and upload models with the `hf` CLI, manage tokens and cache, call Inference Providers through router.huggingface.co, and run, pause or delete Inference Endpoints, with Spaces and Jobs covered briefly. Use when the user mentions Hugging Face, HF_TOKEN, `hf download`, huggingface-cli, huggingface_hub, gated models, Inference Providers, `:fastest` or `:cheapest`, Inference Endpoints, `hf endpoints`, scale-to-zero 502s, `huggingface/` LiteLLM models, or HF cache cleanup. For provider-neutral choices use cloud-llms; for gateways use llm-gateway; for owned GPUs use self-hosted-llms.
license: MIT
compatibility: Any OS with bash, curl and jq; the `hf` CLI (pip or uv install of huggingface_hub) is needed for download, upload, cache and endpoint management. Needs a Hugging Face account and a token in HF_TOKEN or a 0600 file. Ask before creating Inference Endpoints, Spaces hardware or Jobs, which bill by the minute, and before buying credits.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Hugging Face

Get model weights from the Hub, call hosted models through one token, run a dedicated Inference Endpoint when you need your own deployment, keep the cache and the bill under control, and delete what you started.

**Scope:** the Hub CLI (`hf`: auth, download, upload, repos, cache), Inference Providers (OpenAI-compatible router at `https://router.huggingface.co/v1`), Inference Endpoints (dedicated, autoscaling), and a brief look at Spaces and Jobs. Out of scope: choosing a hosting option (`choosing-llm-hosting`, `cloud-llms`), gateway design (`llm-gateway`, `litellm`), serving weights on your own GPUs (`self-hosted-llms`, `vllm`), fine-tuning (`fine-tuning-llms`, `trl`, `unsloth`), quantization (`model-quantization`).

Work through the steps in order. Load a reference only when a step names it. The legacy `huggingface-cli` command is replaced by `hf`; `hf inference-endpoints` is an alias of `hf endpoints`.

## Discover first

Read-only. Nothing here prints a token.

```bash
env | cut -d= -f1 | grep -i -E '^(HF_|HUGGING)' || echo "no HF env vars"
command -v hf curl jq || echo "install the CLI: pip install -U huggingface_hub  (or: uv tool install huggingface_hub)"
hf version
hf auth whoami                 # username and orgs; fails clearly when logged out
hf cache ls                    # what is already downloaded, and how large
hf endpoints ls --namespace '*'   # Inference Endpoints you may be paying for
hf jobs ls                     # running Jobs
```

## Decision flow

1. Need weights or a dataset locally: `hf download` into the cache or `--local-dir` (`references/hub-cli-and-tokens.md`).
2. Need a hosted model call, no infra: Inference Providers via the router with one token (`references/inference-providers.md`).
3. Need your own deployment, custom or gated weights, dedicated capacity: Inference Endpoints (`references/inference-endpoints.md`).
4. Need an app or a one-off compute run: Spaces or Jobs (`references/spaces-and-jobs.md`).
5. Pick provider routing: `:fastest` default, `:cheapest`, `:preferred`, or a named provider.
6. Through a gateway: LiteLLM `huggingface/...` or an OpenAI route with `api_base` (`references/litellm-and-clients.md`).
7. Disk full or bill rising: `references/limits-and-billing.md`, then `references/teardown.md`.

## Rules

- **Ask before billable resources.** Inference Endpoints, Spaces hardware and Jobs bill by the minute; credits and pay-as-you-go need approval.
- **Secrets never touch output.** Use `HF_TOKEN` or a `0600` file. Do not pass `--token hf_...` on the command line or print `hf auth` output beyond `whoami`. One token per app; prefer fine-grained tokens for production.
- **Pin revisions.** Use `--revision <sha>` for downloads and exact image tags for endpoints; branches move.
- **Budget first.** Know the hardware price (`hf endpoints hardware`), the quota, and the stop condition before deploying.
- **Always tear down.** Pause or delete endpoints, cancel Jobs, pause Spaces, prune the cache (`references/teardown.md`).
- **Scale-to-zero is not off.** A scaled-to-zero endpoint still counts against quota and answers 502 while it wakes; only pause or delete frees the slot.
- **Check licenses and gating** before downloading or redistributing weights.

## Workflows

### 1. Account and token

- [ ] Create a fine-grained token (needed permissions: "Make calls to Inference Providers", repo read or write) at Settings, Access Tokens -> `references/hub-cli-and-tokens.md`
- [ ] Store: `umask 077; read -rs K; printf '%s' "$K" > ~/.config/hf.token; unset K; export HF_TOKEN="$(cat ~/.config/hf.token)"`
- [ ] Verify: `hf auth whoami`.

### 2. Download and upload

- [ ] `hf download <repo> [--include '*.safetensors'] [--revision <sha>] [--local-dir <dir>]`, use `--dry-run` first on large repos -> `references/hub-cli-and-tokens.md`
- [ ] `hf upload <repo> <local> <path-in-repo>` (creates the repo if missing; use a private repo for non-public weights)

### 3. Call Inference Providers

- [ ] `base_url=https://router.huggingface.co/v1`, `api_key=$HF_TOKEN`, model `org/name[:policy]` -> `references/inference-providers.md`
- [ ] Verify with a one-token request and read `usage`.

### 4. Deploy an Inference Endpoint

- [ ] `hf endpoints hardware` (prices, quota), then `hf endpoints catalog deploy --repo ...` or `hf endpoints deploy ...` -> `references/inference-endpoints.md`
- [ ] Wait for `running`, call it with the HF token, set min and max replicas deliberately.

### 5. Connect to LiteLLM and clients

- [ ] Router model: `huggingface/<provider>/<org>/<model>`; endpoint: `huggingface/tgi` with `api_base` ending in `/v1/` -> `references/litellm-and-clients.md`

### 6. Monitor cost and disk

- [ ] Billing page, Inference Providers settings, `hf cache ls` -> `references/limits-and-billing.md`

### 7. Tear down

- [ ] `hf endpoints pause|delete`, `hf jobs cancel`, `hf spaces pause`, `hf cache rm|prune` -> `references/teardown.md`

### 8. Troubleshoot

- [ ] `references/troubleshooting.md`

## Reference index

- `references/hub-cli-and-tokens.md`: `hf` install, tokens, download, upload, repos, cache.
- `references/inference-providers.md`: router URL, provider policies, models list, billing routing.
- `references/inference-endpoints.md`: hardware, deploy, status, pause, scale to zero, update, delete.
- `references/spaces-and-jobs.md`: Spaces and Jobs, briefly.
- `references/limits-and-billing.md`: credits, pay-as-you-go, quotas, per-minute billing, spend visibility.
- `references/litellm-and-clients.md`: LiteLLM, OpenAI SDK, `InferenceClient`.
- `references/teardown.md`: stop and delete everything billable.
- `references/troubleshooting.md`: symptom to fix.

## Companion skills

- `cloud-llms`: choose providers and hybrid routing. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `llm-gateway`: one endpoint in front of Hugging Face and others. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `litellm`: proxy configuration in depth. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `choosing-llm-hosting`: decide between hosted and self-hosted. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `self-hosted-llms`, `vllm`: serve the weights yourself. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `fine-tuning-llms`: produce weights to upload. Install: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`.
- `model-quantization`: shrink weights before upload or deploy. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-evals`, `llm-observability`: quality and cost checks. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- `local-llms`: run downloaded weights on a laptop. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
