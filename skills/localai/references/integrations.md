# Integrate LocalAI

> Verified against LocalAI v4.11.0, 2026-10-11

## OpenAI SDK and curl

`base_url` is `http://<host>:8080/v1`; the key is any configured `LOCALAI_API_KEY` entry (or a dummy value when auth is off). Examples in `references/api.md`. Anthropic SDK clients can use `POST /v1/messages` against the same server with `x-api-key`.

## LiteLLM

Template: `templates/litellm-localai.yaml`. Use the `openai/` prefix so LiteLLM speaks the OpenAI protocol, and the model YAML `name` as the id.

```yaml
model_list:
  - model_name: local-chat
    litellm_params:
      model: openai/qwen3-4b
      api_base: http://localai:8080/v1
      api_key: os.environ/LOCALAI_API_KEY
```

Raise LiteLLM's request timeout above the model cold-load time (first call loads the model). Skill: `litellm` (`npx skills add ScaleDockHQ/llms-skills --skill litellm`).

## systemd

Template: `templates/local-ai.service`. It uses an `EnvironmentFile` mode `0600` for `LOCALAI_API_KEY` and `HF_TOKEN`, dedicated user, and `Restart=on-failure`. Optional socket activation: a `local-ai.socket` with `ListenStream=8080` and enabling the socket only (see `references/serve-config.md`).

## Docker Compose

Template: `templates/docker-compose.yml`: four named volumes, loopback port, GPU reservation, `/readyz` healthcheck, env file for secrets.

## Kubernetes

Upstream Helm chart `go-skynet/local-ai` and example manifests. Needed: PVCs for the four paths, a Secret for `LOCALAI_API_KEY`, GPU resource requests, a readiness probe on `/readyz` and a long startup probe (backend and model downloads), `strategy: Recreate` for a single GPU. For scale-out use distributed mode, not replicas sharing one volume.

## Reverse proxy and tunnels

Set `LOCALAI_BASE_URL` and forward `X-Forwarded-Proto` and `X-Forwarded-Host`; disable proxy response buffering for streaming. Skills: `caddy`, `cloudflare-tunnel`, `tailscale` (`npx skills add ScaleDockHQ/llms-skills --skill caddy`).

## Ollama-compatible clients

The `/api/*` Ollama routes are always registered. Setting `LOCALAI_OLLAMA_API_ROOT_ENDPOINT=true` replaces the web UI at `/` with an Ollama-style health check, which some Ollama clients probe.

## Other engines as backends

LocalAI can run `ik-llama-cpp`, `vllm`, `sglang` and others as backends: `references/combos/ik-llama-cpp-backend.md`. To compose several separate servers behind one endpoint instead, use `llama-swap` or `litellm`.
