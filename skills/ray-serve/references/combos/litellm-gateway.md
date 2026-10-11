# Combo: LiteLLM in front of Ray Serve

> Verified against Ray 2.59.0 and LiteLLM docs (provider `openai`, custom `api_base`), 2026-10-11

Ray Serve does not check API keys, so authentication, per-key budgets and fallbacks belong in a gateway.

1. Expose the Serve service on ClusterIP only (`<rayservice>-serve-svc:8000`); never the dashboard.
2. Register the model in LiteLLM with the `openai/` prefix and the in-cluster URL; the model name is the `model_id` from `LLMConfig`.

```yaml
model_list:
  - model_name: qwen-0.5b
    litellm_params:
      model: openai/qwen-0.5b
      api_base: http://ray-serve-llm-serve-svc.default.svc:8000/v1
      api_key: os.environ/RAY_SERVE_PLACEHOLDER_KEY # any non-empty value; Serve ignores it
```

3. Raise LiteLLM's timeouts above cold-start time when `min_replicas` is 0.
4. Multi-LoRA adapters appear as `<model_id>:<adapter>`; add one entry per adapter you want to publish.

Gateway details: skills `litellm` and `llm-gateway`.
