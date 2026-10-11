# Deploying a model

> Verified against AIBrix v0.7.0 (docs, samples, chart, release assets), 2026-10-11

AIBrix does not wrap the engine in a new CRD for the simple case: you apply a normal Deployment (or a
`StormService`) with labels, and the controller builds the per-model `HTTPRoute` for the gateway.

## Required labels

On the pod template (and Deployment): `model.aibrix.ai/name: <model>` (the string clients send as `model`, unique
per model) and `model.aibrix.ai/port: "8000"`. Create a Service with the same name as the label. The vLLM
`--served-model-name` must be the same string. Start from `templates/model.yaml` (adapted from
`samples/quickstart/model.yaml`, vLLM image `vllm/vllm-openai:v0.11.0` in the sample; use a current tag).

## Per-model routing profile

```yaml
annotations:
  model.aibrix.ai/config: |
    {"profiles": {"default": {"routingStrategy": "least-latency"}}}
```

Guidance from the docs: `prefix-cache` for multi-turn chat, `least-request` for independent requests,
`least-latency` for interactive, `pd` for P/D disaggregation.

## Custom paths

Per-model routes cover the standard OpenAI paths (for example `/v1/chat/completions`, `/v1/completions`). Add more
with the Deployment annotation `model.aibrix.ai/model-router-custom-paths: /version,/score`.

## Runtime sidecar

`model.aibrix.ai/sidecar-injection: "true"` on a Deployment or StormService injects `aibrix-runtime` (metric
standardization, model download, adapter management). Override the image with
`model.aibrix.ai/sidecar-runtime-image`. The controller uses the runtime API on port 8080 when the sidecar exists and
`--enable-runtime-sidecar=true`, else the engine API on 8000.

## Check

```bash
kubectl get deploy,svc -l model.aibrix.ai/name
kubectl get httproute -n aibrix-system        # one <model>-router per model
kubectl describe httproute <model>-router -n aibrix-system | rg -i 'accepted|resolved'
```

## Secrets

Engine API keys: set `VLLM_API_KEY` from a Secret (`secretKeyRef`) instead of the inline `--api-key` used in some
samples. Hugging Face tokens the same way.

## Sources

- <https://aibrix.readthedocs.io/latest/production/model-deployment.html>
- <https://github.com/vllm-project/aibrix/tree/v0.7.0/samples/quickstart>
