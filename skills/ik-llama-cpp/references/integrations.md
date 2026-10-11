# Integrating ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c) and docker/README.md, 2026-10-11

`llama-server` speaks the OpenAI API, so anything that takes a base URL and model name works: `http://HOST:8080/v1`, model = the `-a` alias.

## llama-swap

Upstream ships a `swap` image (`cpu-swap`, `cu12-swap`) that runs llama-swap in front of `llama-server`. See `references/combos/llama-swap.md`, and the `llama-swap` skill for general config.

## LiteLLM

```yaml
model_list:
  - model_name: local-ik
    litellm_params:
      model: openai/my-model # the -a alias
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/IK_LLAMA_API_KEY # any non-empty value if the server has no key
```

Use the `litellm` skill for routing, budgets and keys.

## Clients

- OpenAI SDK: `OpenAI(base_url="http://127.0.0.1:8080/v1", api_key=os.environ["IK_LLAMA_API_KEY"])`.
- Open WebUI: add an OpenAI connection with that base URL.
- Coding agents: use `--jinja`, a model with a native tool format, and `-cram` to reuse prompt caches.

## Containers and Kubernetes

Use the `server` image tags with GPU runtime. There are no upstream Kubernetes manifests; keep one replica per GPU set, mount models read-only, and probe `/health` (503 while loading). Set a long `startupProbe` for large MoE models; a cold load of hundreds of GB can take many minutes (`-dexp`, `-prexp` shorten it).

Put TLS and auth on a reverse proxy (`caddy` skill) rather than exposing the server.
