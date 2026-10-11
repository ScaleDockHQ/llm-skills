# Plugin model: ai-proxy and the OSS AI plugins

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

The 3.x model: attach plugins to a Service, Route or globally. `ai-proxy` receives an OpenAI-format request, rewrites it for the configured provider, injects credentials and returns an OpenAI-format response. The Service URL is irrelevant (use a placeholder); `ai-proxy` sets the upstream.

## Plugin tiers (from the plugin pages' `tier` field)

| Free (OSS)                                                                                                                      | Enterprise (`ai_gateway_enterprise`)                                                                                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ai-proxy`, `ai-prompt-decorator`, `ai-prompt-guard`, `ai-prompt-template`, `ai-request-transformer`, `ai-response-transformer` | `ai-proxy-advanced`, `ai-rate-limiting-advanced`, `ai-semantic-cache`, `ai-semantic-prompt-guard`, `ai-semantic-response-guard`, `ai-sanitizer`, `ai-prompt-compressor`, `ai-llm-as-judge`, `ai-mcp-proxy`, `ai-aws-guardrails`, `ai-azure-content-safety`, `ai-lakera-guard` |

Confirm the tier of any plugin on its page before recommending it; the free and paid split moves between releases. A plugin that is not in `GET /plugins/enabled` is unavailable in that build.

## ai-proxy essentials

- `config.route_type`: `llm/v1/chat`, `llm/v1/completions`, `llm/v1/embeddings`, plus (3.11+ per the docs) `llm/v1/responses`, `llm/v1/files`, `llm/v1/batches`, `llm/v1/assistants`, `audio/v1/audio/*` and `image/v1/images/*`. Which route types a provider supports differs; check the provider table in the docs.
- `config.model.provider`, `config.model.name`, `config.model.options` (for example `upstream_url`, `azure_instance`, `azure_deployment_id`, `anthropic_version`, `llama2_format`). `model_alias` maps a request's `model` to a target (3.x docs; confirm in the schema for your version).
- `config.auth`: `header_name` and `header_value` (for example `Authorization` and `Bearer <key>`), or `param_name`, `param_value` and `param_location`, or cloud identity fields (AWS, Azure, GCP service account JSON, `gcp_use_service_account`). Secret fields are `x-referenceable` (use a Vault reference) and `x-encrypted` (keyring). In decK files, inject from the environment with `${{ env "DECK_..." }}`.
- `config.llm_format` (3.10+): `openai` default; `anthropic`, `bedrock`, `cohere`, `gemini`, `huggingface` pass native formats through without conversion.
- `config.response_streaming`: `allow` (default), `deny`, `always`.
- `config.logging.log_statistics` (default false): token and model usage in log plugin output. `log_payloads` (default false): request and response bodies in logs and OTel traces, which exposes prompts; leave off unless approved.
- `config.max_request_body_size`: default 1048576 bytes; `0` is unlimited but still bounded by Nginx `client_max_body_size`. Large prompts get a 4xx until you raise both.
- The response carries `X-Kong-LLM-Model` (model selected) by default.

## Self-hosted upstreams

- vLLM, Ollama, llama.cpp, LM Studio (OpenAI-compatible): newer docs show `provider: vllm` with `options.upstream_url` as the full URL including the path (`.../v1/chat/completions`). On OSS 3.9.3 use `provider: llama2` with `llama2_format: openai` (tested).
- From a container, `localhost` is the container; use `host.docker.internal` with `extra_hosts: host-gateway`, a compose service name or a LAN address.

## Prompt plugins (OSS)

- `ai-prompt-decorator`: prepend or append system and user messages. `ai-prompt-template`: named templates filled from the request. `ai-prompt-guard`: allow and deny regex lists on prompts (a coarse filter, not a safety system). `ai-request-transformer` and `ai-response-transformer`: call an LLM to rewrite the request or response body.
- Plugin order matters: prompt plugins run before `ai-proxy`; use `ordering` only when the defaults are wrong.

## Consumers and inbound auth

`ai-proxy` has no inbound auth. Add `key-auth`, `jwt`, `openid-connect` (Enterprise) or another Kong auth plugin on the same Service or Route, with `hide_credentials: true` so the client key is not forwarded to the provider. Per-consumer limits use Consumers or Consumer Groups.

## Discover

```bash
curl -s http://127.0.0.1:8101/plugins/enabled | jq -r '.enabled_plugins[]' | grep '^ai-'
curl -s http://127.0.0.1:8101/schemas/plugins/ai-proxy | jq -r '.. | .one_of? // empty | @json' | head   # enum lists, including providers
curl -s http://127.0.0.1:8101/plugins | jq -r '.data[] | select(.name|startswith("ai-")) | [.name,.enabled,(.route.id // "-"),(.service.id // "-")] | @tsv'
docker run --rm -e KONG_DATABASE=off -v "$PWD/kong.rendered.yaml:/t.yml:ro" kong:3.9.3 kong config parse /t.yml
```
