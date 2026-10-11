# Integrations

> Verified against KTransformers v0.7.1 (kt-kernel README, model tutorials; client settings are generic OpenAI-compatible settings), 2026-10-11

The server speaks OpenAI Chat Completions on `http://<host>:30000/v1`. Upstream documents `kt chat` and curl; the snippets below use each client's
generic OpenAI-compatible provider settings and were not run against a live KT server.

## `kt chat`

`kt chat` opens an interactive terminal chat against a running server (`--host`, `--port`, `--model`, `--temperature`); it needs the `openai` Python package.

## OpenAI SDK

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:30000/v1", api_key="not-used")   # real key only if a proxy or --api-key requires one
print(client.chat.completions.create(model="qwen3", messages=[{"role": "user", "content": "hi"}]).choices[0].message.content)
```

## LiteLLM

```yaml
model_list:
  - model_name: kt-qwen3
    litellm_params:
      model: openai/qwen3 # the --served-model-name
      api_base: http://127.0.0.1:30000/v1
      api_key: not-used
```

Cap concurrency at the gateway (`max_parallel_requests`) to match `--max-running-requests`. Skill: `npx skills add ScaleDockHQ/llms-skills --skill litellm`.

## Open WebUI, coding agents

Add an OpenAI-compatible connection to the base URL with the served model name. Upstream notes that GLM-5.3-flash works with coding agents through the OpenAI-compatible
API; set the correct `--tool-call-parser` and expect slow prefill on long agent contexts. Skills for the clients: `open-webui`, `claude-code`, `codex-cli`, `opencode`.
Claude Code needs an Anthropic-style endpoint, so front KT with LiteLLM.

## llama-swap

A KT server is heavy (large RAM, long load): swap whole processes only if you can afford minutes per swap. Use `python -m sglang.launch_server ...` as the command with
`--port ${PORT}` and probe `/health` plus `/v1/models`. Skill: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`.

## Kubernetes

No upstream manifests exist for 0.7. Needs huge-RAM nodes, exclusive CPU (`cpu-manager-policy: static` with Guaranteed QoS), NUMA topology awareness (`topology-manager-policy`),
hugepages optional, `nvidia.com/gpu`, and `--ipc host`-like shared memory. Treat as an advanced, unverified deployment.
