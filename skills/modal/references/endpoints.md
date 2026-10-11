# Modal Endpoints

> Verified against Modal docs (Endpoints guide, Proxy Tokens, Endpoint integrations, Servers guide, CLI reference for `modal endpoint` and `modal workspace proxy-tokens`), modal 1.6.1, 2026-10-11

Modal Endpoints deploy a model from the Modal Library, or your own weights, as an inference API. Endpoints are built on Modal Servers (`vllm-server.md`).

## Shared vs Dedicated

|          | Shared Endpoints              | Dedicated Endpoints                               |
| -------- | ----------------------------- | ------------------------------------------------- |
| Best for | Fast, fully managed inference | Isolated capacity and custom models               |
| Models   | Selected Modal Library models | All Modal Library models, plus custom weights     |
| Billing  | Per token                     | Compute resources                                 |
| Capacity | Managed by Modal              | Configurable autoscaling, including scale-to-zero |

Check which mode a model supports in the Modal Library and read live pricing with `modal billing rates` or Modal's pricing page. Do not hardcode prices.

## Create, inspect, stop (Dedicated)

```bash
modal endpoint create --model <hf-repo-id>                       # name derived from the model
modal endpoint create --name qwen-chat --model <hf-repo-id> \
  --routing-region us-east --compute-region us-west              # compute region adds a price multiplier
modal endpoint create --name my-ft --model <base-hf-repo-id> \
  --custom-volume-name my-weights --custom-volume-path /models/ft   # custom weights from a Volume
modal endpoint info qwen-chat --json
modal endpoint list
modal endpoint logs qwen-chat -f
modal endpoint stats qwen-chat --since 2h
modal endpoint stop qwen-chat --yes        # permanent; terminates running containers
```

Options worth knowing from the CLI reference:

- `--routing-region` defaults to `us-west`. `--compute-region` may be repeated and `--colocate-compute` runs containers in the routing region; both incur a region selection price multiplier.
- `--unauthenticated` allows public HTTP requests. Avoid it unless the user wants a public URL.
- `--custom-hf-repo`, `--custom-hf-revision`, `--custom-hf-token` serve fine-tuned weights from a Hugging Face repo. Do not pass the token inline in a command you will log: read it from an env var in your own shell.
- `modal endpoint stats` is best-effort and may be delayed or incomplete.

Endpoints can also be created from the dashboard's Endpoints tab.

## Authentication: proxy tokens

Shared Endpoints always require a proxy token. Dedicated Endpoints require one by default.

```bash
modal workspace proxy-tokens create --name llm-gateway --json    # secret is shown only once; capture to a 0600 file
modal workspace proxy-tokens list
modal workspace proxy-tokens delete wk-<id> --yes
```

Pass the token in one of two forms:

```bash
# Single bearer value: ID and secret joined with a period. Works as an OpenAI API key.
Authorization: Bearer wk-<id>.ws-<secret>

# Or two headers
Modal-Key: wk-<id>
Modal-Secret: ws-<secret>
```

On workspaces with RBAC, tokens are scoped to Environments: use `modal workspace proxy-tokens allow <token-id> <environment>` and `revoke`. A valid token that is not scoped to the App's Environment gets a 403.

Workspace managers can block unauthenticated URLs per Environment (Settings, Environments). When blocking is on, `modal deploy` and `modal endpoint create` fail if proxy auth is not required.

## Calling an Endpoint

Text-generation models on Shared and Dedicated Endpoints can be called through:

- the OpenAI-compatible Chat Completions API (`/v1/chat/completions`),
- the OpenAI-compatible Responses API,
- the Anthropic-compatible Messages API,

and embedding models through the OpenAI-compatible Embeddings API. Set `model` to the value in the dashboard's request examples, or read it from the Models API:

```bash
# MODAL_PROXY_TOKEN_ID and MODAL_PROXY_TOKEN_SECRET come from your environment or a 0600 env file
curl -sS "$ENDPOINT_URL/v1/models" \
  -H "Authorization: Bearer $MODAL_PROXY_TOKEN_ID.$MODAL_PROXY_TOKEN_SECRET" | jq -r '.data[].id'

curl -sS "$ENDPOINT_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MODAL_PROXY_TOKEN_ID.$MODAL_PROXY_TOKEN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"model": "<model-name>", "messages": [{"role": "user", "content": "Hello!"}]}' \
  | jq -r '.choices[0].message.content'
```

`ENDPOINT_URL` comes from `modal endpoint info <name>` or the dashboard. The exact Anthropic and Responses request shapes follow the upstream APIs; read Modal's Endpoints guide for any Modal-specific fields before relying on them.

### Affinity routing

Send the same `Modal-Routing-Affinity-Key: <conversation-id>` header on every request of one conversation or agent run so requests land on the same container and reuse the prefix cache. Use one key per conversation, not per user, and a new key after compacting context. Affinity is best-effort and changes when the Endpoint scales or a container is replaced.

### Coding agents on Shared Endpoints

Modal documents OpenCode, Codex and Claude Code against Shared Endpoints at `https://inference.us-west.modal.direct`, with the `model` set to the Endpoint hostname and the combined proxy token as the key. See `litellm-and-clients.md` for the environment variables, and use a model that supports tool calling.

## When not to use Endpoints

Use your own Server (`vllm-server.md`) when you need engine flags, a parser or an engine Modal does not offer, custom auth logic, or code that runs alongside the model.
