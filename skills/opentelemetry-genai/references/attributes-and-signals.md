# GenAI signals and attributes

> Verified against open-telemetry/semantic-conventions-genai (main, 2026-10-09: docs/gen-ai, model/gen-ai, docs/registry), 2026-10-11

All names are Development status. Query them by exact string and re-check on each upgrade.

## Spans

| Span type (semconv id)                     | Name pattern                                                          | Kind                                    | Use                                                       |
| ------------------------------------------ | --------------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| `gen_ai.client.inference`                  | `{gen_ai.operation.name} {gen_ai.request.model}` (e.g. `chat gpt-4o`) | CLIENT (INTERNAL for in-process models) | One call to a model                                       |
| `gen_ai.embeddings.client`                 | `embeddings {model}`                                                  | CLIENT                                  | Embedding calls                                           |
| `gen_ai.retrieval.client`                  | per conventions                                                       | CLIENT                                  | Vector DB or retriever calls                              |
| `gen_ai.fetch_response.client`             | `fetch_response`                                                      | CLIENT                                  | Fetching a stored response (no inference, no token usage) |
| `gen_ai.memory.client`                     | per conventions                                                       | CLIENT                                  | Memory store operations                                   |
| `gen_ai.create_agent.client`               | `create_agent ...`                                                    | CLIENT                                  | Creating a remote agent                                   |
| `gen_ai.invoke_agent.client` / `.internal` | `invoke_agent {agent name}`                                           | CLIENT / INTERNAL                       | Agent invocations                                         |
| `gen_ai.execute_tool.internal`             | `execute_tool {tool name}`                                            | INTERNAL                                | Tool execution                                            |
| `gen_ai.invoke_workflow.internal`          | `invoke_workflow {name}`                                              | INTERNAL                                | Workflow or graph run                                     |
| `gen_ai.plan.internal`                     | per conventions                                                       | INTERNAL                                | Planning steps                                            |

Provider pages refine inference spans for OpenAI, Anthropic, Azure AI Inference and AWS Bedrock. MCP has its own page.

## `gen_ai.operation.name` values

`chat`, `text_completion`, `generate_content`, `embeddings`, `retrieval`, `execute_tool`, `invoke_agent`, `invoke_workflow`, `create_agent`, `fetch_response`, `plan`, memory operations (`create_memory`, `create_memory_store`, `delete_memory`, `delete_memory_store`, `search_memory`, `update_memory`). Use `chat` for chat-completion style calls, including OpenAI-compatible servers.

## Key attributes on inference spans

| Attribute                                                                                                     | Level                                | Notes                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `gen_ai.operation.name`, `gen_ai.provider.name`                                                               | Required                             | Provider examples: `openai`, `anthropic`, `aws.bedrock`, `gcp.gen_ai`. OpenAI-compatible servers are usually reported as `openai` |
| `gen_ai.request.model`, `gen_ai.response.model`                                                               | Conditionally required / Recommended | The served model name, not the weights file                                                                                       |
| `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`                                                     | Recommended                          | Input includes cached tokens; output includes reasoning tokens                                                                    |
| `gen_ai.usage.cache_read.input_tokens`, `...cache_write.input_tokens`, `gen_ai.usage.reasoning.output_tokens` | Recommended                          | Newer breakdown; per-modality variants exist (`text`, `image`, `audio`)                                                           |
| `gen_ai.request.*`, `gen_ai.response.finish_reasons`, `gen_ai.response.id`                                    | Recommended                          | Temperature, max tokens, top-p and so on                                                                                          |
| `gen_ai.conversation.id`                                                                                      | Conditionally required               | Session or thread correlation                                                                                                     |
| `gen_ai.prompt.name`                                                                                          | Conditionally required               | Named prompt template                                                                                                             |
| `error.type`                                                                                                  | Conditionally required               | Stable attribute from the core conventions                                                                                        |
| `server.address`, `server.port`                                                                               | Recommended                          | Where the model endpoint lives                                                                                                    |
| `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`, `gen_ai.tool.definitions`    | **Opt-In**                           | Content. Structured (JSON) values per `model/gen-ai/*.json` schemas                                                               |
| `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result`                                                       | **Opt-In**                           | Tool I/O on `execute_tool` spans                                                                                                  |

## Metrics

| Metric                                                                                                                               | Type                        | Unit                                |
| ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------- | ----------------------------------- |
| `gen_ai.client.inference.duration`                                                                                                   | Histogram                   | `s`                                 |
| `gen_ai.client.inference.time_to_first_chunk`, `.time_per_output_chunk`                                                              | Histogram                   | `s`                                 |
| `gen_ai.client.inference.usage.input_tokens`, `.usage.output_tokens`                                                                 | Counter                     | `{token}`                           |
| `gen_ai.client.inference.usage.cache_read.input_tokens`, `.cache_write.input_tokens`, `.reasoning.output_tokens`                     | Counter                     | `{token}`                           |
| `gen_ai.client.inference.operation.input_tokens`, `.operation.output_tokens`                                                         | per-operation token metrics | `{token}`                           |
| `gen_ai.client.operation.duration`                                                                                                   | Histogram                   | `s` (non-inference operations only) |
| `gen_ai.server.request.duration`, `gen_ai.server.time_to_first_token`, `gen_ai.server.time_per_output_token`                         | Histogram                   | `s` (model servers)                 |
| `gen_ai.invoke_agent.duration`, `.inference_calls`, `.tool_calls`, `gen_ai.invoke_workflow.duration`, `gen_ai.execute_tool.duration` | agent metrics               | various                             |

Token metrics carry `gen_ai.token.modality` as a required attribute. Older instrumentations still emit `gen_ai.client.token.usage` (histogram) and `gen_ai.client.operation.duration` for chat; dashboards must handle both while you migrate.

## Events and logs

- `gen_ai.client.inference.operation.details`: log record with the full request and response, emitted only when `OTEL_INSTRUMENTATION_GENAI_EMIT_EVENT=true`; content inside follows the capture mode. Requires a logs pipeline; many LLM backends accept traces only.
- `gen_ai.client.operation.exception`: exceptions.
- `gen_ai.evaluation.result`: evaluator scores linked to a span.

## Content structure

`gen_ai.input.messages` is a list of messages with `role` and typed `parts` (text, tool call and response, reasoning, blob, URI and file parts; see the JSON schemas in `model/gen-ai/`), serialized as JSON when the transport only supports scalar attributes. Backends that expected the old flattened `gen_ai.prompt.0.content` need an updated mapper; Phoenix 15.10.0+ converts the canonical form at ingest; check each backend release notes (see `backends-and-gateways.md`).

## Look things up

```bash
git clone --depth 1 https://github.com/open-telemetry/semantic-conventions-genai /tmp/semconv-genai
rg -n 'gen_ai\.[a-z_.]+' -o -N --no-filename /tmp/semconv-genai/docs/registry/attributes/gen-ai.md | sort -u
```
