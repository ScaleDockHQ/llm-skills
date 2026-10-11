# Integrating MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

`mlc_llm serve` is OpenAI-compatible: base URL `http://HOST:8000/v1`, model = the id from `/v1/models` (for example the `HF://...` string).

## LiteLLM

```yaml
model_list:
  - model_name: mlc-llama3
    litellm_params:
      model: openai/HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC
      api_base: http://127.0.0.1:8000/v1
      api_key: os.environ/MLC_API_KEY # any non-empty value if the server has no key
```

See `templates/litellm-mlc.yaml` and the `litellm` skill. One `mlc_llm serve` process serves one model (plus optional embedding and draft models), so run one process per model or use a swapper.

## Clients

- OpenAI SDK: `OpenAI(base_url="http://127.0.0.1:8000/v1", api_key=os.environ["MLC_API_KEY"])`.
- Open WebUI and similar UIs: add an OpenAI connection with that base URL.
- IDE plugins: see `docs/deploy/ide_integration.rst` upstream.

## Process management

There is no official container image or Kubernetes manifest in the repo. Run under systemd (`templates/mlc-llm.service`) with the conda env's `mlc_llm`, a fixed `MLC_LLM_HOME` on persistent disk, and `MLC_JIT_POLICY=READONLY` after the first warm run. Probe readiness with `GET /v1/models` (there is no dedicated health route in the source tree).

Put TLS and auth on a reverse proxy (`caddy` skill); `--api-key` is a single shared bearer key and `/metrics` is not covered by it.

## llama-swap

No verified combination exists; llama-swap can launch `mlc_llm serve` with its `cmd` and `proxy` fields in principle, but readiness checks and slow JIT on first load need a long `healthCheckTimeout`. Test before relying on it.
