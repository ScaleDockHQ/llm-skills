---
name: modal-vllm
description: Stack recipe for vLLM on Modal serverless GPUs (@app.server or a managed Endpoint) behind a LiteLLM gateway, with proxy-token auth, scale-to-zero, cold-start handling and teardown. Use to stand up a private OpenAI-compatible LLM end to end, "vLLM on Modal plus LiteLLM", modal deploy vllm, modal.direct URL, proxy token, 503 cold start. Not for deep Modal, vLLM or LiteLLM detail (use modal, vllm, litellm) or other clouds (cloud-llms).
license: MIT
compatibility: Needs Python 3.10-3.14 with the modal package, bash, curl, jq, Docker or pip for LiteLLM, network access to modal.com and a Modal workspace with a payment method. Deploying apps and starting the gateway bills or exposes resources, so each needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Modal vLLM

A private, scale-to-zero, OpenAI-compatible LLM: vLLM on Modal (your own `@app.server`, or a Dedicated Endpoint) behind a LiteLLM gateway that holds the proxy token, with timeouts, retries and a fallback. Each component's depth lives in its product skill.

**Scope:** this opinionated combination of Modal, vLLM and LiteLLM. Use `modal` for the CLI, SDK, Volumes, autoscaling and every Modal detail, `vllm` for engine flags, `litellm` and `llm-gateway` for gateway design.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print names, never values.

```bash
command -v modal || python3 -m modal --version
env | cut -d= -f1 | grep -E '^(MODAL|HF|LITELLM)_' || echo "no matching env vars"
modal token info
modal app list; modal endpoint list; modal volume list; modal secret list
modal workspace proxy-tokens list
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i litellm
curl -s https://pypi.org/pypi/modal/json | jq -r .info.version      # newest modal
```

## Decision flow

1. **Is this the right stack?** Bursty traffic, tolerates cold starts, wants Python-defined infrastructure and per-second GPU billing: yes. Steady high traffic or strict latency: keep a container warm (`modal`) or use another stack (`choosing-llm-hosting`).
2. **Endpoint or your own Server?** A hosted model with no code or custom weights from a Volume: a Dedicated Endpoint. Own flags, parser, auth or code: a vLLM Server (`references/recipe.md`).
3. **Account and auth** with `modal` workflow 1; create a Modal Secret for `HF_TOKEN` if the model is gated.
4. **Deploy** with a pinned `modal`, `vllm`, CUDA base image and model revision; `max_containers=1` first (`references/recipe.md`).
5. **Proxy token** into a `0600` file; the gateway holds it, clients never do (`references/gateway.md`).
6. **Gateway:** LiteLLM entry with a long timeout, retries on 503, and a fallback (`references/gateway.md`).
7. **Verify, then operate and tear down** (`references/operations.md`).

## Rules

- **Ask before anything billable.** `modal deploy`, Dedicated Endpoints and `min_containers` cost money. State GPU, count, `max_containers`, region and a stop time, then wait.
- **Private by default.** Never set `unauthenticated=True` or `--unauthenticated` without explicit approval; require a proxy token.
- **Pin versions.** `modal`, `vllm` (copy the pin from Modal's current vLLM example), the CUDA base image and the model revision.
- **Secrets stay secret.** The proxy token joins ID and secret with a period; build it in an environment variable, never in YAML, logs or prompts. `HF_TOKEN` goes in a Modal Secret.
- **Expect 503 during cold start.** The gateway must retry with a generous timeout; Modal Servers have no built-in queue or retries.
- **Cap containers and shorten the idle window** before traffic.
- **Do not hardcode prices.** Read them with `modal billing rates` or the pricing page.
- **Always tear down.** `modal app stop` and `modal endpoint stop` are permanent; Volumes bill until deleted.
- **Verify upstream.** Modal's vLLM example changes its model, vLLM pin and flags; re-read it before writing code.

## Build the stack

- [ ] Account, token, Secret, budget -> `modal` skill
- [ ] Choose Server or Endpoint and write or create it after approval -> `references/recipe.md`
- [ ] Create the proxy token, smoke test `/health`, `/v1/models` and one completion -> `references/recipe.md`
- [ ] Add the LiteLLM entry, retries and fallback -> `references/gateway.md`
- [ ] Cost, update and teardown -> `references/operations.md`
- [ ] Verify: the gateway answers after a cold start, `modal app list` shows containers scale to zero when idle, nothing public without a token.

## Reference index

- `references/recipe.md`: Server or Endpoint, deploy steps and smoke tests.
- `references/gateway.md`: LiteLLM config, proxy token handling, timeouts, fallback.
- `references/operations.md`: cost watching, updates and rollback, teardown order.

## Companion skills

- `modal`: all Modal detail (CLI, SDK, Servers, Endpoints, Volumes, errors). Install: `npx skills add ScaleDockHQ/llm-skills --skill modal`.
- `vllm`: engine flags, tool parsers, tuning. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `litellm`: gateway install, keys, budgets, fallbacks. Install: `npx skills add ScaleDockHQ/llm-skills --skill litellm`.
- `llm-gateway`: gateway design. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `choosing-hardware`: GPU sizing. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-hardware`.
- `cloud-llms`: other providers and fallback targets. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
