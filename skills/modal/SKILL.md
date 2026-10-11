---
name: modal
description: Run LLMs on Modal serverless GPUs with the modal CLI and Python SDK (vLLM Servers, Endpoints, web functions, Volumes), connect them to a gateway and tear down. Use for Modal setup, modal deploy, @app.server, modal.direct URLs, proxy auth tokens, modal endpoint, modal app stop, Volumes, GPU scaling, 503/401/403/429 errors. Not for other clouds (use cloud-llms), gateway design (llm-gateway) or vLLM flags (vllm).
license: MIT
compatibility: Needs Python 3.10-3.14 with the modal package (1.6.1), bash, curl, jq, network access to modal.com and a Modal workspace with a payment method for GPUs. Deploying apps or endpoints bills the workspace, so each needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Modal

Get an LLM serving on Modal, either as your own vLLM Server or a managed Endpoint, reachable by OpenAI-compatible clients and your gateway, with scaling caps and budgets set and everything stopped when done.

**Scope:** the `modal` CLI and Python SDK, vLLM on Modal (`@app.server`, web functions), Modal Endpoints (Shared and Dedicated), proxy auth tokens, Volumes and Secrets, autoscaling, GPUs, billing controls and teardown.

**Out of scope:** choosing between providers (`cloud-llms`, `choosing-llm-hosting`), gateway routing and keys (`llm-gateway`, `litellm`), vLLM engine tuning (`vllm`), GPU sizing (`choosing-hardware`), training recipes (`fine-tuning-llms`, `unsloth`), image or video models (`self-hosted-genmedia`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print variable names, never values.

```bash
command -v modal || python3 -m modal --version
env | cut -d= -f1 | grep -E '^(MODAL|HF|OPENAI|LITELLM)_' || echo "no matching env vars"
ls -l ~/.modal.toml ~/.config/modal 2>&1                         # permissions only; want 0600 and 0700
modal token info
modal app list
modal endpoint list
modal volume list
modal secret list
modal environment list
```

Learn which workspace and environment are active and what is already running before proposing anything. If `modal` is missing or unauthenticated, go to workflow 1.

## Decision flow

1. **Just want a hosted model with no code?** Use **Shared Endpoints** (per token) or a **Dedicated Endpoint** (GPU time, scale to zero) (`references/endpoints.md`).
2. **Custom model, flags, LoRA or weights, or a private deployment?** Write a vLLM **Server** with `@app.server` (`references/scaling-and-volumes.md`).
3. **Need an arbitrary web API or older Function style?** Use a **web function** (`@modal.web_server`, ASGI) (`references/scaling-and-volumes.md`).
4. **Large weights or compile caches?** Put them in **Volumes** (`references/scaling-and-volumes.md`).
5. **Latency or cost tuning?** `references/scaling-and-volumes.md`.
6. **Clients and gateway:** `references/litellm-and-clients.md`.
7. **Something broke:** `references/troubleshooting.md`.
8. **Done or pausing:** `references/teardown.md`.

## Rules

- **Ask before anything billable.** `modal deploy`, `modal run` with a GPU, Dedicated Endpoints and `min_containers` cost money. State GPU, count, `max_containers`, region and a stop time, then wait for approval.
- **Secrets stay secret.** Tokens come from `0600` files, stdin (`modal token set --token-id - --token-secret -`) or environment variables; never print, commit or paste them. Use Modal Secrets for `HF_TOKEN`.
- **Private by default.** Servers and Endpoints need proxy auth. Never set `unauthenticated=True` or `--unauthenticated`, or skip `requires_proxy_auth=True` on web functions, without explicit approval.
- **Pin versions.** `modal==<version>`, `vllm==<version>`, the CUDA base image and the Hugging Face model revision.
- **Budget controls before traffic.** Set `max_containers`, a short `scaledown_window`, `min_containers=0`, a workspace budget or spend limit, and client `max_tokens`.
- **Always tear down.** `modal app stop` and `modal endpoint stop` are permanent; Volumes bill until deleted. Finish every session with workflow 8.
- **Do not hardcode prices or quotas.** Read them with `modal billing rates` or the pricing page.

## Workflows

### 1. Account and auth

- [ ] Modal account exists with a payment method (human step).
- [ ] `python3 -m venv .venv && pip install "modal==1.6.1"`; `modal --version`.
- [ ] Human runs `modal setup`, or an agent uses a token from a `0600` file (see `references/setup-and-auth.md`); `modal token info` works.
- [ ] Hugging Face token stored as `modal secret create huggingface-secret HF_TOKEN=...` for gated models.

### 2. Deploy a vLLM Server

- [ ] Pick model, pinned revision and GPU (`choosing-hardware`; Modal suggests starting with `L40S`).
- [ ] Write the `@app.server` app from `references/vllm-server.md` with `max_containers=1`, Volumes for caches, and no `unauthenticated`.
- [ ] After approval: `modal deploy file.py`; note the printed URL.
- [ ] Create a proxy token (`modal workspace proxy-tokens create`) and save it to a `0600` file.
- [ ] Poll `/health` (expect `503` until ready), then `GET /v1/models` and one `max_tokens: 8` request.

### 3. Create a managed Endpoint

- [ ] `modal endpoint create --name ... --model ...` after approval; inspect with `modal endpoint info`.
- [ ] Use the endpoint name as `model`; test `GET /v1/models` with the proxy token.

### 4. Connect to LiteLLM and clients

- [ ] Add a `model_list` entry (`hosted_vllm/<served-name>` or `openai/<endpoint-name>`, `api_base` ending `/v1`, `api_key: os.environ/MODAL_PROXY_TOKEN`) from `references/litellm-and-clients.md`.
- [ ] Set `num_retries` and a long `timeout` for `503` cold starts; add a fallback.

### 5. Scale

- [ ] Tune `target_concurrency`, `scaledown_window`, `max_containers`, `buffer_containers`; `min_containers=1` only when latency needs it.
- [ ] Use `update_autoscaler()` for quick experiments (reverts on the next deploy).

### 6. Monitor cost

- [ ] `modal billing summary`, `modal billing report` (Team or Enterprise), tag apps, `modal server stats`, `modal endpoint stats`.
- [ ] Use `llm-observability` for request-level tracing and `llm-evals` before swapping models.

### 7. Update

- [ ] Bump pinned versions in code, `modal deploy --strategy rolling`, smoke test, and use `modal app history` if you need to compare versions.
- [ ] Rolling back needs a Team or Enterprise plan (`modal app rollback`).

### 8. Tear down

- [ ] Follow `references/teardown.md`: stop apps and Endpoints, delete Volumes, Secrets and proxy tokens, remove gateway entries.
- [ ] Verify `modal app list`, `modal endpoint list` and `modal volume list` are as expected.

### 9. Troubleshoot

- [ ] Logs first (`modal app logs`, `modal deploy --stream-logs`), then `references/troubleshooting.md`.

## Reference index

| File                                | Load when                                                                           |
| ----------------------------------- | ----------------------------------------------------------------------------------- |
| `references/setup-and-auth.md`      | Install, tokens, environments, Secrets, plan and billing prerequisites              |
| `references/vllm-server.md`         | `@app.server` vLLM example, deploy, update and roll back, web functions             |
| `references/endpoints.md`           | Shared and Dedicated Endpoints, proxy tokens, Claude Code, Codex and OpenCode setup |
| `references/scaling-and-volumes.md` | Autoscaling, cold starts, GPUs, Volumes, budgets, billing CLI, limits               |
| `references/litellm-and-clients.md` | LiteLLM entries, OpenAI SDK and curl, health checks                                 |
| `references/teardown.md`            | Stopping every billable resource and verifying                                      |
| `references/troubleshooting.md`     | Symptom to cause to fix, with real error strings                                    |

## Companion skills

- `cloud-llms`: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms` (compare providers, hybrid setups)
- `llm-gateway`: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway` (one endpoint, keys, budgets)
- `choosing-llm-hosting`: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `llm-clients`: `npx skills add ScaleDockHQ/llms-skills --skill llm-clients`
- `llm-observability`: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`
- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `fine-tuning-llms`: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`
- `model-quantization`: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`
- `vllm`: `npx skills add ScaleDockHQ/llms-skills --skill vllm`
