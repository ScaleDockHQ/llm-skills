---
name: runpod-serverless-vllm
description: Stack recipe for vLLM on Runpod Serverless (worker-vllm) behind a LiteLLM gateway, with spend caps, cold-start handling and teardown. Use to stand up a scale-to-zero OpenAI-compatible LLM endpoint end to end, "worker-vllm plus LiteLLM", runpodctl serverless, api.runpod.ai/openai/v1, cold start timeouts, max workers cost cap. Not for deep Runpod, vLLM or LiteLLM detail (use runpod, vllm, litellm) or other clouds (cloud-llms).
license: MIT
compatibility: Needs bash, curl, jq, runpodctl, Docker or pip for LiteLLM, network access to runpod.io and api.runpod.ai, and a Runpod account with credits. Creating endpoints and starting the gateway bills or exposes resources, so each needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Runpod Serverless vLLM

A scale-to-zero, OpenAI-compatible LLM endpoint: Runpod Serverless running worker-vllm, fronted by a LiteLLM gateway with timeouts, retries, a fallback and a hard worker cap. Each component's depth lives in its product skill.

**Scope:** this opinionated combination of Runpod Serverless, worker-vllm (vLLM) and LiteLLM. Use `runpod` for account, Pods and every Runpod detail, `vllm` for engine flags, `litellm` and `llm-gateway` for gateway design.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Print names, never values.

```bash
command -v runpodctl && runpodctl version
env | cut -d= -f1 | grep -E '^(RUNPOD|HF|LITELLM)_' || echo "no matching env vars"
ls -l ~/.config/runpod/api-key 2>&1                     # permissions only; want -rw-------
runpodctl user | jq 'del(.email, .id)'                  # balance, spend per hour, spend limit
runpodctl serverless list; runpodctl network-volume list
docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null | grep -i litellm
curl -s https://api.github.com/repos/runpod-workers/worker-vllm/releases/latest | jq -r .tag_name   # newest worker-vllm tag
```

## Decision flow

1. **Is this the right stack?** Bursty or low-duty traffic, tolerates a cold start of minutes, wants an OpenAI-compatible API: yes. Steady high traffic, strict latency or a tool-parser the worker lacks: use a Pod or a load-balancing endpoint (`runpod`), or another stack (`choosing-llm-hosting`).
2. **Account, key and budget** with `runpod` workflow 1; set the spend limit before creating anything.
3. **Pick model and GPU:** model, `MAX_MODEL_LEN` and VRAM per `choosing-hardware` and `vllm`.
4. **Deploy** the endpoint with a pinned worker-vllm tag, `--workers-min 0`, a low `--workers-max` and cached models (`references/recipe.md`).
5. **Gateway:** LiteLLM `openai/<model>` entry with a long timeout, retries and a fallback (`references/gateway.md`).
6. **Verify** with the smoke tests in `references/recipe.md`, then watch cost.
7. **Teardown or pause:** `references/operations.md` and the `runpod` teardown reference.

## Rules

- **Ask before anything billable.** State GPU type, `--workers-max`, active workers (default 0), model and a stop time, then wait.
- **Cap workers before traffic.** `--workers-max` is the spend cap. Keep active workers at 0 unless asked.
- **Pin versions.** `runpod/worker-v1-vllm:<release>` from the releases page, never `:latest`; pin the model revision.
- **Secrets stay secret.** Use a Restricted API key from a `0600` file; `HF_TOKEN` via a Runpod secret. Never print keys or put them in prompts.
- **Give the gateway a long timeout.** The first request after idle waits for worker boot plus model load.
- **Remember the idle caps.** Runpod lowers max workers automatically after idle days; raise it again before relying on the endpoint.
- **Do not hardcode prices.** Read them from the console or `runpodctl gpu list`.
- **Always tear down.** Endpoints, templates and volumes: `references/operations.md`.
- **Verify upstream.** worker-vllm, runpodctl and vLLM move fast; re-read the release notes.

## Build the stack

- [ ] Account, Restricted key, spend limit -> `runpod` skill
- [ ] Create template and endpoint (min 0, low max, cached model) after approval -> `references/recipe.md`
- [ ] Smoke test `/openai/v1/models` and one completion with a long timeout -> `references/recipe.md`
- [ ] Add the LiteLLM entry, retries and a fallback -> `references/gateway.md`
- [ ] Cost and health checks -> `references/operations.md`
- [ ] Verify: the gateway answers after a cold start, `runpodctl serverless health <id>` shows workers scale to 0 when idle, spend per hour returns to baseline.

## Reference index

- `references/recipe.md`: end-to-end deploy and smoke test with the commands that tie the skills together.
- `references/gateway.md`: LiteLLM config, timeouts, retries, fallback, client check.
- `references/operations.md`: cost watching, updating, idle-cap behaviour, teardown order.

## Companion skills

- `runpod`: all Runpod detail (account, runpodctl, Pods, limits, errors). Install: `npx skills add ScaleDockHQ/llms-skills --skill runpod`.
- `vllm`: engine flags, tool parsers, tuning. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `litellm`: gateway install, keys, budgets, fallbacks. Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
- `llm-gateway`: gateway design. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway`.
- `choosing-hardware`: GPU sizing. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-hardware`.
- `cloud-llms`: other providers and fallback targets. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
