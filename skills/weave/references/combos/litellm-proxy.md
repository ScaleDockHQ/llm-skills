# Weave with a LiteLLM proxy over vLLM or llama.cpp

> Verified against weave 0.53.12, LiteLLM v1.105.0 (`weave_otel` callback) and collector-contrib 0.162.0, 2026-10-11

Clients call the LiteLLM proxy (4000); the proxy forwards to vLLM (8000) or llama.cpp and emits one span per request; Weave stores them.

```yaml
# LiteLLM config.yaml
model_list:
  - model_name: local-chat
    litellm_params:
      model: openai/<served-model-name>
      api_base: http://node-a:8000/v1
      api_key: os.environ/VLLM_API_KEY
litellm_settings:
  callbacks: ["weave_otel"]
  turn_off_message_logging: true
```

```bash
# environment of the proxy, from a 0600 env file (names only here)
# WANDB_API_KEY  WANDB_PROJECT_ID=<entity>/<project>  [WANDB_HOST]
```

- Pass `metadata: {"session_id": "...", "display_name": "..."}` on requests to group turns into Weave threads and name calls.
- Content is off with `turn_off_message_logging: true`; verify with a canary because callbacks differ in how they honor it.
- To strip attributes centrally or fan out, send the proxy's OTLP to the Collector (`assets/otel-collector.yaml`) instead of straight to Weave.
- Metrics (queueing, KV cache) are not in Weave; use `prometheus-grafana-llm` beside it.

Install: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.
