---
name: fal
description: fal (fal.ai) genmedia model APIs and fal serverless - call 1,000+ hosted image, video, audio and 3D models through the queue API or fal-client, run an OpenRouter-backed LLM endpoint, deploy your own Python fal.App on GPUs, control spend and delete. Use for "fal.ai", FAL_KEY, queue.fal.run, fal.run, fal-client, "fal deploy", genmedia CLI, concurrent_requests_limit. Local image or video - self-hosted-genmedia. LLM gateways - llm-gateway. Other clouds - cloud-llms.
license: MIT
compatibility: macOS or Linux shell with curl and jq. fal-client needs Python or Node. The fal serverless CLI needs Python 3.8+. Needs a fal account and a key in a 0600 file or FAL_KEY. Serverless deploys need account approval. Deploys, scaling above zero and credit purchases need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# fal

Use fal for generative media: call hosted models through the queue API, optionally reach LLMs through fal's OpenRouter-backed endpoint, or deploy your own Python app on fal GPUs. fal is genmedia-first, so for chat LLMs it is rarely the best home.

**Scope:**

- In: fal account and keys, Model APIs (queue, sync, webhooks), the `fal-client` libraries, the `genmedia` CLI, serverless apps (`fal run`, `fal deploy`, `fal apps`), concurrency and cost, retention, teardown, LiteLLM.
- Out: running image and video models on your own GPUs (`self-hosted-genmedia`), picking a provider (`cloud-llms`, `choosing-llm-hosting`), gateway routing and budgets (`llm-gateway`), serving LLMs yourself (`self-hosted-llms`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Names only for environment variables.

```bash
env | cut -d= -f1 | grep -iE '^FAL' || echo "no FAL_* vars"
command -v fal && fal --version
command -v genmedia && genmedia --version
pip show fal-client 2>/dev/null | head -2
fal auth whoami 2>&1 | head -3
fal apps list 2>&1 | head -20          # serverless apps and their scale settings
```

Apps with `min_concurrency` above zero hold GPUs and bill. Report them first.

## Decision flow

1. A hosted model from the catalog: Model APIs through `https://queue.fal.run/<model-id>`. Prefer the queue over sync for anything slow.
2. Chat or text through a gateway: the OpenRouter-router endpoint (`references/model-apis.md`). It is token-billed and needs verifying against the model page.
3. Custom code, weights or a model fal does not host: serverless `fal.App`. This needs serverless access approval (`references/serverless.md`).
4. Need full control or no vendor: `self-hosted-genmedia` or rent a GPU (`cloud-llms`).
5. Many users: check concurrency limits first (`references/billing-and-teardown.md`).

## Rules

- **Ask before creating billable resources.** Deploys, `min_concurrency` above zero, higher concurrency through credit purchase and large batch jobs need approval, with the machine type and scale bounds shown.
- **Secrets never print.** The key is `FAL_KEY`, read from a `0600` file. Use a key preset with the least scope (`API` for calls, `SERVERLESS` or `DEPLOY` for deploys) and an expiry.
- **Never ship `FAL_KEY` to a browser.** Proxy client calls through your server.
- **Pin versions.** Pin `fal`, `fal-client` and every package in the app's `requirements`.
- **Budget before traffic.** Prepaid credit, a low `max_concurrency` and a short `keep_alive` (`references/billing-and-teardown.md`).
- **Mind retention.** Request payloads are stored by default and CDN media expires. Set the expiry headers for sensitive data.
- **Always tear down.** Scale to zero or delete apps and revoke temporary keys, then verify.
- **Look prices up.** Use the pricing endpoint, model page and machine-types page. Never hardcode rates.

## Workflows

### 1. Account and auth

- [ ] Create a key and install a client. See `references/setup-and-auth.md`.

### 2. Call a model

- [ ] Find the endpoint ID, read its schema, submit to the queue, poll or use a webhook. See `references/model-apis.md`.

### 3. Deploy your own app

- [ ] Request serverless access, write a `fal.App`, test with `fal run`, deploy with `fal deploy`. See `references/serverless.md`.

### 4. Connect to LiteLLM or OpenAI clients

- [ ] Use LiteLLM's `fal_ai/` provider for images, or the OpenRouter-router endpoint for text. See `references/litellm-and-llms.md`.

### 5. Scale

- [ ] `fal apps scale` with concurrency and keep-alive. See `references/serverless.md`.

### 6. Monitor cost

- [ ] Pricing and usage lookups. See `references/billing-and-teardown.md`.

### 7. Update

- [ ] `fal deploy` again with a rolling strategy, check revisions, roll back with `fal apps set-rev`.

### 8. Tear down

- [ ] `fal apps delete`, revoke keys, confirm with `fal apps list`. See `references/billing-and-teardown.md`.

### 9. Troubleshoot

- [ ] Map `error_type` and status in `references/troubleshooting.md`.

## Reference index

- `references/setup-and-auth.md`: keys, presets, clients, `genmedia` CLI, serverless CLI install.
- `references/model-apis.md`: queue, sync, status, webhooks, headers, retries, LLM endpoint.
- `references/serverless.md`: `fal.App`, `fal deploy`, `fal apps`, scaling attributes.
- `references/billing-and-teardown.md`: billing, concurrency, retention, price lookup, deletion.
- `references/litellm-and-llms.md`: LiteLLM `fal_ai/` and the OpenAI-compatible LLM route.
- `references/troubleshooting.md`: error types and fixes.

## Companion skills

- `self-hosted-genmedia`: run image, video and audio models on your own GPUs. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-genmedia`.
- `cloud-llms`: compare fal with other cloud options. Install: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms`.
- `llm-gateway`: LiteLLM routing and budgets. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway`.
- `choosing-llm-hosting`: laptop, owned GPUs or cloud. Install: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`.
- `llm-observability`: traces and cost. Install: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`.
