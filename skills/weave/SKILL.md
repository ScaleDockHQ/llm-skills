---
name: weave
description: W&B Weave, Weights & Biases' toolkit for tracing and evaluating LLM apps and agents (weave.init, @weave.op, Evaluations). Use to trace OpenAI-compatible calls to vLLM, llama.cpp, Ollama or LiteLLM, send OTLP to trace.wandb.ai, redact PII, evaluate with scorers, use W&B Cloud or self-managed Weave, update the SDK, or fix no traces, Not authenticated, WANDB_API_KEY, 401 on OTLP. Not for choosing a tracing stack (llm-observability).
license: MIT
compatibility: Python 3.10+ (or Node 18+ for the TypeScript SDK) with pip or npm, bash, curl and optionally Docker for an OTel Collector. Needs a W&B API key or a self-managed instance. Sending traces to a hosted service and installs need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Weave

A working Weave setup (`wandb/weave`, Apache-2.0 SDK; the trace backend is W&B's) that traces LLM calls and agents from self-hosted endpoints and gateways, redacts what must not leave, evaluates changes, and is updated deliberately.

**Scope:** this one product: install, `weave.init`, ops, integrations, OTLP, PII redaction, evaluations, hosting options, update, troubleshoot. Choosing between Weave, Langfuse, Phoenix and others is `llm-observability`; self-hosted Langfuse is `langfuse`; running the LiteLLM proxy is `litellm`; eval methodology is `llm-evals`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
pip show weave 2>/dev/null | grep -E '^(Version|Requires-Python)'; python3 --version
env | cut -d= -f1 | grep -E '^(WANDB|WEAVE|OTEL_EXPORTER)' || true           # names only
ls ~/.netrc 2>/dev/null && grep -c 'api.wandb.ai' ~/.netrc 2>/dev/null          # login stored? (count only)
grep -rIl --include='*.py' -E 'weave\.init|@weave\.op' . 2>/dev/null | head
docker ps --format '{{.Names}}\t{{.Image}}' | grep -Ei 'otel|collector|wandb' || true
curl -s -o /dev/null -m 8 -w 'trace.wandb.ai HTTP %{http_code}\n' https://trace.wandb.ai/
curl -fsS https://pypi.org/pypi/weave/json | jq -r .info.version                 # newest SDK
```

Ask only what discovery cannot show: Cloud, Dedicated Cloud or Self-Managed W&B; which endpoints (vLLM, llama.cpp, Ollama, LiteLLM) and languages send traces; whether prompts may leave the network at all.

## Decision flow

1. **Data may not leave your network:** a W&B Self-Managed instance with Weave enabled (license, Kubernetes, ClickHouse), or a different backend (`langfuse`). -> `references/hosting-and-auth.md`
2. **Python app:** `weave.init("<entity>/<project>")`; OpenAI client with `base_url` for vLLM, llama.cpp, Ollama. -> `references/tracing-and-integrations.md`
3. **Other language, gateway or OTel source:** OTLP over HTTP protobuf to `/otel/v1/traces`. -> `references/otlp-and-gateways.md`
4. **Privacy first:** redaction, content stripping, disabling. -> `references/privacy.md`
5. **Judge a change:** evaluations and scorers. -> `references/evaluations.md`
6. **New SDK release:** -> `references/updating.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before sending data off the machine.** Weave Cloud is third-party hosting; get approval and decide content capture first.
- **Secrets never touch output.** `WANDB_API_KEY` lives in a `0600` env file or the secret store; never in code, logs or commands; check presence by name only. Weave auto-redacts keys named `api_key`, `auth_headers` and `authorization`, nothing else.
- **Content capture is a decision.** Ops record inputs, outputs and source code by default (`capture_code`). Turn on `redact_pii` and `postprocess_inputs`, or strip at a Collector, before real traffic.
- **Project is `entity/project`.** An unqualified name goes to the default entity.
- **OTLP is HTTP protobuf only.** Header `wandb-api-key`, resource attributes `wandb.entity` and `wandb.project`; the exporter must send protobuf.
- **Pin the SDK.** Exact `weave==x.y.z` in lock files; the SDK moves fast and settings are deprecated across versions.
- **Verify upstream.** Docs moved to docs.coreweave.com under W&B; check them and PyPI at use time.

## Workflows

### First trace

- [ ] `pip install weave` (pin), `wandb login` or `WANDB_API_KEY` from a file -> `references/hosting-and-auth.md`.
- [ ] `weave.init("<entity>/<project>")`, decorate one function with `@weave.op`, run it -> `references/tracing-and-integrations.md`.
- [ ] Open the printed link; confirm inputs, outputs, latency and token usage.

### Self-hosted model endpoint

- [ ] Point the OpenAI client at the local server (`base_url`, dummy `api_key`) after `weave.init` -> `references/tracing-and-integrations.md`.
- [ ] LiteLLM proxy: `callbacks: ["weave_otel"]` -> `references/otlp-and-gateways.md`.

### Privacy

- [ ] `settings={"redact_pii": True}` plus `postprocess_inputs`; canary request; check the UI -> `references/privacy.md`.

### Update

- [ ] Read the SDK release notes, bump the pin, rerun a canary trace -> `references/updating.md`.

## Reference index

| File                                     | Read when                                                                              |
| ---------------------------------------- | -------------------------------------------------------------------------------------- |
| `references/hosting-and-auth.md`         | Cloud, Dedicated, Self-Managed, API keys, login, base URLs                             |
| `references/tracing-and-integrations.md` | `weave.init`, ops, OpenAI-compatible local servers, LiteLLM SDK, attributes, disabling |
| `references/otlp-and-gateways.md`        | OTLP endpoint and auth, Collector, LiteLLM proxy `weave_otel`, non-Python sources      |
| `references/privacy.md`                  | Redaction, key redaction, postprocessing, content stripping, retention                 |
| `references/evaluations.md`              | `weave.Evaluation`, scorers, datasets                                                  |
| `references/updating.md`                 | Versions, deprecations, rollback                                                       |
| `references/troubleshooting.md`          | Symptom to cause to fix                                                                |
| `references/combos/litellm-proxy.md`     | LiteLLM proxy in front of vLLM or llama.cpp, traced into Weave                         |

Templates: `assets/otel-collector.yaml` (validated), `assets/litellm-weave.yaml`. Script: `scripts/check.sh` (names and reachability only).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-observability`: choosing a stack, metrics, gateway logging.
- `langfuse`: the self-hostable alternative.
- `litellm`: the gateway that can export to Weave.
- `llm-evals`: eval methodology and golden sets.
