# Integrations

> Verified against LMDeploy v0.18.0 (docs `integration/claude_code.md`, `integration/codex.md`, `llm/api_server.md`, `llm/proxy_server.md`, `k8s/`), 2026-10-11

## OpenAI SDK and curl

```bash
export OPENAI_BASE_URL=http://127.0.0.1:23333/v1
export OPENAI_API_KEY="$(cat ~/.config/lmdeploy/key 2>/dev/null || echo none)"   # any string when no --api-keys
curl -s "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.data[].id'
```

`model_name = client.models.list().data[0].id` is the pattern upstream uses to find the ID.

## LiteLLM

Use the generic OpenAI-compatible provider (nothing LMDeploy-specific is required):

```yaml
model_list:
  - model_name: qwen-local
    litellm_params:
      model: openai/qwen # the --model-name value
      api_base: http://127.0.0.1:23333/v1
      api_key: os.environ/LMDEPLOY_API_KEY # or any placeholder when --api-keys is unset
```

Declare tool-calling capability in the router; `/v1/models` does not report it. See the `litellm` skill.

## llama-swap

Configure `cmd` as the `lmdeploy serve api_server ... --server-port ${PORT}` line and `proxy` as
`http://127.0.0.1:${PORT}`, with a long health-check timeout because of cold start. Not tested against a live
llama-swap here; see the `llama-swap` skill.

## Claude Code (Anthropic messages)

Upstream documents `ANTHROPIC_BASE_URL` pointing at the **server root** (not `/v1`); Claude Code appends
`/v1/messages`. Start the server with a tool parser, verify with a `curl` to `/v1/messages` (header
`anthropic-version: 2023-06-01`), then in `~/.claude/settings.json` set `env` keys such as `ANTHROPIC_BASE_URL`,
`ANTHROPIC_AUTH_TOKEN` (placeholder or your key), `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
`ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`,
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`, all set to the served model name. Full example: upstream
`docs/en/integration/claude_code.md`.

## Codex (Responses)

LMDeploy exposes `POST /v1/responses`; configure a custom model provider in Codex pointing at the server. Upstream
steps and the `config.toml` snippet are in `docs/en/integration/codex.md`. Responses support is a text-first subset
(see `api.md`).

## Open WebUI and other chat UIs

Point the OpenAI connection at `http://<host>:23333/v1`. Use `/v1/models` to confirm the ID.

## Prometheus and Grafana

`lmdeploy/monitoring` in the repo ships a Docker Compose Prometheus (9090) and Grafana (3000) stack with a prebuilt
dashboard (`observability.md`).

## Kubernetes

The repo ships `k8s/deployment.yaml` and `k8s/service.yaml` (image `openmmlab/lmdeploy:latest`, hostPath model
cache, HF token substituted with `sed` into the manifest). Use `templates/k8s-deployment.yaml` here instead:
pinned tag, Secret from a file, PVC cache, probes, `Recreate` strategy. Multi-replica routing: one `Service` over
replicas, or the LMDeploy proxy; for llm-aware routing see `gateway-api-inference-extension` and `llm-d`.
