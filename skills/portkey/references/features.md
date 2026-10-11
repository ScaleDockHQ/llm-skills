# Portkey guardrails, MCP gateway and other features

> Verified against Portkey AI Gateway v1.15.2 (README, plugins/, src/middlewares/requestValidator/schema/config.ts) and docs.portkey.ai (product/mcp-gateway, product/ai-gateway/*), 2026-10-11

## Guardrails

The repo has a plugin system (`plugins/`: default, portkey, plus partner plugins such as aporia, pillar, patronus, pangea, panw-prisma-airs, lasso, javelin, azure, bedrock, mistral). `conf.json` `plugins_enabled` lists which are loaded at build time. Configs accept `input_guardrails`, `output_guardrails`, `before_request_hooks` and `after_request_hooks`. The README example denies any reply containing a word:

```json
{
  "retry": { "attempts": 5 },
  "output_guardrails": [
    {
      "default.contains": { "operator": "none", "words": ["Apple"] },
      "deny": true
    }
  ]
}
```

Guardrail IDs (`pg-...`) and the managed catalog of 40+ checks, PII redaction and partner guardrails are configured in the hosted app. Partner plugins need that partner's credentials under `credentials` in `conf.json`. Test any guardrail end to end on your tag; the open-source feature comparison page does not list guardrails as included.

## MCP Gateway

A hosted control plane for MCP servers: authentication at the gateway, access control by team and tool, per-call logs, identity forwarding. Works with Claude Desktop, Cursor, VS Code and any MCP client. Docs: https://portkey.ai/docs/product/mcp-gateway. It is not part of the open-source 1.x gateway; do not promise it for a self-hosted install.

## Multi-format API

`/v1/chat/completions`, `/v1/responses` and `/v1/messages` all route to any provider; non-native providers get the request transformed to Chat Completions. Tools built for the Anthropic Messages format work with other backends through `/v1/messages`.

## Metadata, trace IDs

`x-portkey-metadata` takes a JSON object of custom keys (flat, primitive values) used in logs, cache keys and conditional routing. `x-portkey-trace-id` ties several requests into one trace.

## Prompts

`/v1/prompts/:id/completions` renders saved prompt templates. Template management is a hosted feature.

## Other

Multimodal endpoints (images, speech, transcription), files and batches (some require Enterprise to unify), fine-tune routes, and `/v1/realtime` over WebSocket exist in the gateway source; verify per provider before relying on them.
