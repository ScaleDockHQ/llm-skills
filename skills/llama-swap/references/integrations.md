# Integrating llama-swap

> Verified against llama-swap v263 and LiteLLM v1.105.0 (docs), 2026-10-11

## Engines

Any OpenAI- or Anthropic-compatible server works; llama-server is best supported. Pattern per engine:

| Engine                                       | `cmd` pattern                                                                                    | `checkEndpoint`           | Notes                                                                                                                                                                               |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| llama.cpp                                    | `llama-server --port ${PORT} -m model.gguf` (or the unified image's binary)                      | `/health`                 | Set `disableKeepAlives: true` if a request after a stream gets 502 EOF.                                                                                                             |
| vLLM                                         | `docker run --name ${MODEL_ID} ... vllm/vllm-openai ...` with `cmdStop: docker stop ${MODEL_ID}` | `/health` or `/v1/models` | Slow compile: raise `healthCheckTimeout`. The unified image includes `vllm-wrapper` for vLLM sleep mode (vLLM started with `--enable-sleep-mode`); vLLM itself is not in the image. |
| SGLang, TensorRT-LLM, TabbyAPI, Ollama       | Docker/Podman with `cmdStop`                                                                     | engine's health route     | Python engines should run under Docker or Podman for clean shutdown.                                                                                                                |
| stable-diffusion.cpp, whisper.cpp, audio.cpp | in the unified image                                                                             | per server                | Routes: `/sdapi/v1/*`, `/v1/audio/*`, `/audioapi/v1/tasks/run`.                                                                                                                     |
| ComfyUI                                      | see `combos/comfyui-images.md`                                                                   |                           |                                                                                                                                                                                     |

Container `cmd` skeleton:

```yaml
models:
  small-gguf:
    proxy: "http://127.0.0.1:${PORT}"
    cmd: |
      docker run --name ${MODEL_ID} --init --rm --gpus all
      -p 127.0.0.1:${PORT}:8080 -v /srv/models:/models:ro
      <engine image> <engine flags>
    cmdStop: docker stop ${MODEL_ID}
    unloadTimeout: 90
```

Use the engine skill for the image tag and flags (`vllm`, `llama-cpp`, `sglang`).

## LiteLLM, Open WebUI and other clients

See `combos/litellm.md`. Clients that list models read `/v1/models`; enable `includeAliasesInList` if they must see variant aliases, and `sendLoadingState` so a cold swap shows progress.

## Caddy, Cloudflare Tunnel, Tailscale

Put these in front of the gateway or llama-swap's loopback port; they carry no llama-swap-specific settings except streaming (no buffering, long read timeouts). Use the `caddy`, `cloudflare-tunnel` and `tailscale` skills. Cloudflare returns 524 when the origin stays silent too long, which a cold swap can cause: use `sendLoadingState: true`.

## Kubernetes (kubeswap)

The unified image ships `kubeswap`, a wrapper used as `cmd`/`cmdStop` so each model runs as a Deployment in a dedicated namespace:

```yaml
cmd: >-
  kubeswap serve --listen 127.0.0.1:${PORT} --model <id> --namespace <ns>
  --image <backend image> --volume pvc:<models-pvc>:/models:ro -- <engine args>
cmdStop: kubeswap delete --model <id> --namespace <ns> --wait 60s
proxy: "http://127.0.0.1:${PORT}"
```

It needs namespaced RBAC (deployments, services, PVCs, pods, pods/log) and a Kubernetes client. The pod's readiness answers the health check, so `checkEndpoint` can stay `/health`. See upstream `docs/kb/guides/operations/kubeswap-kubernetes.md` and `storage-options-kubernetes.md`.

## Remote peers

Chain llama-swap instances or add hosted providers with `peers:` (see `config-schema.md`). Example guide: upstream `docs/kb/examples/peers-and-multi-host.md`.

## Sources

- <https://github.com/mostlygeek/llama-swap/tree/main/docs/kb>
- <https://github.com/mostlygeek/llama-swap/blob/main/docker/unified/README.md>
- <https://docs.litellm.ai/docs/providers/openai_compatible>
