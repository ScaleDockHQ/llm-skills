---
name: vercel-ai-sdk
description: Vercel AI SDK (npm `ai`, @ai-sdk/*), the TypeScript toolkit for LLM apps, pointed at self-hosted endpoints. Use to wire generateText, streamText, tools or Output.object to vLLM, llama.cpp, Ollama, LiteLLM or llama-swap through createOpenAICompatible or @ai-sdk/anthropic, map model names, keep keys out of code, or fix 404s on /responses, missing usage, empty tool calls, JSON failures. Not for gateways (litellm) or other clients (llm-clients).
license: MIT
compatibility: Needs Node.js 22+ (AI SDK 7), pnpm or npm, and curl and jq for the probe script. Installing packages or editing app config needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Vercel AI SDK

A TypeScript app using the AI SDK (`ai`, repo `vercel/ai`) that talks to your own OpenAI- or Anthropic-compatible endpoint with correct base URL, auth, model names, structured output, tool calling and streaming, and a probe that proves it.

**Scope:** configuring the AI SDK against custom endpoints and fixing the failures that follow. Running the endpoints belongs to the engine skills (`vllm`, `llama-cpp`, `ollama`), the gateway to `litellm` and `llama-swap`. Other SDKs, coding agents and chat UIs are in `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
node --version; (pnpm --version || npm --version) 2>/dev/null
jq -r '.dependencies,.devDependencies | to_entries[]? | select(.key|test("^(ai|@ai-sdk/|ollama-ai-provider|ai-sdk-)")) | "\(.key) \(.value)"' package.json 2>/dev/null
grep -rnE "baseURL|createOpenAI|createAnthropic|createOpenAICompatible|AI_GATEWAY|OPENAI_BASE_URL|ANTHROPIC_BASE_URL" --include='*.ts' --include='*.tsx' --include='*.env*' -l . 2>/dev/null | grep -v node_modules | head
env | cut -d= -f1 | grep -E '^(OPENAI|ANTHROPIC|AI_GATEWAY|LLM)_' || true     # names only
pnpm view ai version 2>/dev/null || npm view ai version                       # newest release
```

Ask only what discovery cannot show: which endpoint and API it serves (Chat Completions, Responses or Messages), whether a gateway sits in front, and which model names it exposes (`curl "$BASE/models"`).

## Decision flow

1. **Endpoint speaks Chat Completions (vLLM, llama-server, Ollama `/v1`, LiteLLM, llama-swap):** `createOpenAICompatible`. -> `references/custom-endpoints.md`
2. **Endpoint speaks Anthropic Messages (`/v1/messages`):** `createAnthropic` with `authToken`, base URL **with** `/v1`. -> `references/custom-endpoints.md`
3. **Endpoint speaks Responses (`/v1/responses`):** `createOpenAI`, default `openai(id)`. -> `references/custom-endpoints.md`
4. **Ollama-native `/api`:** community provider only if you need native options. -> `references/custom-endpoints.md`
5. **Need JSON objects, tools or streaming usage:** set the capability flags and test per model. -> `references/structured-output-tools-streaming.md`
6. **Aliases, per-model defaults, fallbacks:** `customProvider`. -> `references/custom-endpoints.md`
7. **New major or old code:** -> `references/updating.md`
8. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Package installs, `.env` edits and production config need approval.
- **Secrets never touch output.** Read keys from `process.env` or a `0600` file; never hardcode, log or echo them. Check presence by name only.
- **Never rely on bare model strings.** `model: "vendor/name"` goes through the global provider (Vercel AI Gateway by default), not your endpoint. Pass a provider model object.
- **Pick the factory that matches the API.** `openai(id)` calls Responses; chat-only endpoints need `openai.chat(id)` or `createOpenAICompatible`.
- **Base URL shape differs by package.** OpenAI-compatible and OpenAI take `.../v1`; `@ai-sdk/anthropic` also takes `.../v1`, unlike the Anthropic SDK.
- **Test per model alias.** Chat working proves nothing about tools, `json_schema` or streamed usage; run `scripts/probe.sh` and one integration test.
- **Verify upstream.** Versions and options come from ai-sdk.dev docs (append `.md` or send `Accept: text/markdown`) and npm at use time.

## Workflows

### Connect an app to a self-hosted endpoint

- [ ] Run discovery; note Node version and installed `ai` and `@ai-sdk/*` versions.
- [ ] Probe the endpoint outside the SDK: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh` -> `references/custom-endpoints.md`.
- [ ] Install `ai` and the matching provider package; copy `templates/provider.ts`.
- [ ] Call `generateText` once, then `streamText` with `onError`.
- [ ] Add `Output.object` and a tool, and set flags per probe results -> `references/structured-output-tools-streaming.md`.

### Gateway aliases

- [ ] Use one `createOpenAICompatible` instance per gateway; model ids are the gateway's aliases, not engine names.
- [ ] Optional `customProvider` for friendly names and default settings.

### Debug

- [ ] Reproduce with `scripts/probe.sh`; if curl works and the SDK does not, compare URL shape, factory and capability flags -> `references/troubleshooting.md`.

## Reference index

| File                                              | Read when                                                                 |
| ------------------------------------------------- | ------------------------------------------------------------------------- |
| `references/custom-endpoints.md`                  | Provider choice, base URLs per backend, auth, model-name mapping          |
| `references/structured-output-tools-streaming.md` | `Output.object`, tools, `stopWhen`, streaming usage and errors, reasoning |
| `references/updating.md`                          | Package versions, v6 to v7 changes that touch custom endpoints            |
| `references/troubleshooting.md`                   | Symptom to cause to fix                                                   |
| `references/combos/litellm-and-llama-swap.md`     | Gateway in front of engines: aliases, keys, bridging                      |

Templates: `templates/provider.ts`, `templates/env.example`. Script: `scripts/probe.sh` (chat, tools, `json_schema`, streamed usage, Messages).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: other SDKs, coding agents and chat UIs against the same endpoint.
- `litellm`: the gateway that gives one key, stable aliases and API bridging.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`: the engines and their tool-calling flags.
- `langfuse`: tracing AI SDK calls via OpenTelemetry.
