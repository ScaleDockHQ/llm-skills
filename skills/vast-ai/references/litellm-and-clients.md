# Vast.ai behind LiteLLM and OpenAI-compatible clients

> Verified against docs.vast.ai guides/serverless (OpenAI proxy), guides/instances/connect/networking, vastai CLI 1.8.3, LiteLLM `openai/` and `hosted_vllm/` provider docs as used by the `litellm` skill, 2026-10-11

Vast has no dedicated LiteLLM provider. Treat Vast LLM endpoints as OpenAI-compatible servers with an explicit `api_base`. Gateway design belongs to the `llm-gateway` and `litellm` skills.

## Rented instance running vLLM

Reach it through a stable address. The raw `http://<public_ipaddr>:<external-port>` changes with every new rental. For a longer run, connect the instance to a private network (Tailscale) or tunnel it, and point the gateway at that.

```yaml
model_list:
  - model_name: qwen3-8b-vast
    litellm_params:
      model: hosted_vllm/<served-model-name> # the model id from GET /v1/models
      api_base: http://<host>:<external-port>/v1 # or the Tailscale / tunnel URL
      api_key: os.environ/VLLM_API_KEY # the key passed to `vllm serve --api-key`
      timeout: 300
      num_retries: 2
```

- Direct ports are plain HTTP, so on untrusted networks use an SSH tunnel (`ssh -N -L 8000:localhost:8000 ...`, then `api_base: http://127.0.0.1:8000/v1`), Tailscale or Cloudflare Tunnel.
- A gateway on another machine cannot use a `localhost` tunnel; run the tunnel on the gateway host or use Tailscale.
- Add a fallback to another model: marketplace hosts can go offline.

## Serverless endpoint via the OpenAI proxy

```yaml
- model_name: qwen3-8b-vast-sls
  litellm_params:
    model: openai/Qwen/Qwen3-8B # ignored by the proxy, still sent; use any non-empty name
    api_base: https://openai.vast.ai/<ENDPOINT_NAME>/v1 # confirm whether /v1 belongs in the base or the path for your client
    api_key: os.environ/VAST_API_KEY # Vast API key; prefer a scoped key (misc permission)
    timeout: 600 # cold workers take minutes
    num_retries: 3
```

Base URL format from the docs: `https://openai.vast.ai/<ENDPOINT_NAME>`; calls go to `/v1/chat/completions` and `/v1/completions` under it. If your client appends `/v1` itself, use the bare base; if LiteLLM errors with `404`, switch between the two forms and test with `curl` first (below). The proxy supports only chat and completions: no embeddings, vision, audio or images, and `parallel_tool_calls` is unsupported. Streaming works. The `model` field is ignored.

## Hybrid with a local model

```yaml
router_settings:
  fallbacks: [{ "qwen3-8b-local": ["qwen3-8b-vast-sls"] }]
```

The full hybrid example is the `cloud-llms` skill's `assets/litellm-hybrid.yaml`; use the entries above in place of its Vast block.

## Plain clients

```bash
export OPENAI_BASE_URL="https://openai.vast.ai/<ENDPOINT_NAME>/v1"
export OPENAI_API_KEY="$(cat ~/.config/vastai/vast_api_key)"
curl -s "$OPENAI_BASE_URL/chat/completions" -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}'
```

If that `404`s, try without `/v1` in the base and with `/v1/chat/completions` in the path (the documented form: `https://openai.vast.ai/<ENDPOINT_NAME>` plus `/v1/chat/completions`).

Handing the Vast API key to a client lets it spend credits and manage instances unless scoped; create a restricted key and give clients only that.

## Verify

```bash
curl -s "http://<host>:<external-port>/v1/models" -H "Authorization: Bearer $VLLM_API_KEY" | jq '.data[].id'   # instances
vastai show endpoints                                                                                            # serverless
```

Expect one model id (instances). For Serverless, a successful short chat completion proves the path; the first call may take minutes if all workers are cold.
