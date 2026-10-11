# Guardrails, semantic cache, MCP and A2A

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

All items here except `ai-prompt-guard`, `ai-prompt-decorator` and `ai-prompt-template` are Enterprise (3.x) or policies/entities on AI Gateway 2.x. Read each plugin's page and reference before configuring; the fields below are only the orientation.

## Guardrails

| Need                                                       | Plugin or policy                                                  | Notes                                                                                                                                            |
| ---------------------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Regex allow or deny on prompts                             | `ai-prompt-guard` (free)                                          | coarse; not a safety control                                                                                                                     |
| Embedding similarity allow or deny on prompts or responses | `ai-semantic-prompt-guard`, `ai-semantic-response-guard`          | needs an embeddings model and vector DB                                                                                                          |
| PII redaction                                              | `ai-sanitizer`                                                    | calls a separate AI PII Anonymizer service at `host` and `port`; requests fail while it is unreachable (docs example sets `stop_on_error: true`) |
| Managed content filters                                    | `ai-aws-guardrails`, `ai-azure-content-safety`, `ai-lakera-guard` | external service credentials and latency; the AWS one has its own latency metric                                                                 |
| Judge a response with an LLM                               | `ai-llm-as-judge`                                                 | adds a model call per request                                                                                                                    |
| Shrink prompts                                             | `ai-prompt-compressor`                                            | changes the text the model sees                                                                                                                  |

## Semantic cache (`ai-semantic-cache`)

Stores prompts and responses as vectors and returns a stored answer for a similar prompt. It needs an embeddings model and a vector database (Redis with search, or pgvector). Keep the embedding model and the index dimension in sync; changing the model without recreating the index gives `expected N dimensions, not M`. A cache can leak one tenant's answer to another, so scope it per consumer or use separate caches for different data classes, and do not cache prompts that carry secrets or personal data.

## MCP and A2A

- `ai-mcp-proxy` (Enterprise 3.x): converts a REST API behind Kong into MCP tools, or fronts an upstream MCP server; ACLs through `default_acl` and `tools.acl`. 2.x equivalent: AI MCP Server (`type` per mode, plus `upstream-server`, with `access` and `tools.access`).
- `ai-a2a-proxy` and the 2.x AI Agent: gateway control and analytics for Agent-to-Agent traffic.
- MCP and A2A have their own OTel metrics (`kong.gen_ai.mcp.*`, `mcp.client.operation.duration`, `kong.gen_ai.a2a.*`).

## Discover

```bash
curl -s http://127.0.0.1:8101/plugins | jq -r '.data[] | select(.name|test("semantic|guard|sanitizer|mcp|a2a|judge|compressor")) | [.name,.enabled] | @tsv'
curl -s http://127.0.0.1:8101/plugins/enabled | jq -r '.enabled_plugins[]' | grep -E 'ai-(semantic|mcp|a2a|sanitizer|llm-as)'
```
