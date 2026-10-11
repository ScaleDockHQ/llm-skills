# exo: clients and gateways

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: README "Using the API", `docs/api.md`.

exo needs no key, so clients that insist on one accept any placeholder.

- **OpenAI SDK and tools:** base URL `http://<host>:52415/v1`, model = the Hugging Face id of the running instance.
- **Claude Messages clients:** base URL `http://<host>:52415` (endpoint `/v1/messages`).
- **Ollama clients (for example Open WebUI):** Ollama base URL `http://<host>:52415/ollama`.
- **LiteLLM (`litellm` skill):** register an OpenAI-compatible backend, keeping clients on aliases and adding auth and budgets exo lacks:

```yaml
model_list:
  - model_name: cluster-chat
    litellm_params:
      model: openai/mlx-community/Llama-3.2-1B-Instruct-4bit
      api_base: http://<exo-host>:52415/v1
      api_key: "none"
```

- **Remote access:** exo has no TLS or auth documented; use `tailscale` or `caddy` with auth rather than opening the port.
- Only a model with a live instance answers; a gateway should health-check `/v1/models` and handle instance restarts.
