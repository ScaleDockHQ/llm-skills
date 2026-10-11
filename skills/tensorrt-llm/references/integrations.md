# Integrations

> Verified against TensorRT-LLM v1.2.1 (`trtllm-serve` routes), DGX Spark playbook (Open WebUI section), Dynamo v1.5.1 examples, and this repo's earlier llama-swap notes, 2026-10-11

`trtllm-serve` is a plain OpenAI-compatible HTTP server with no auth, so integrations sit behind a gateway or on loopback.

## llama-swap (several engines on one GPU box)

TensorRT-LLM images are the heaviest with the slowest cold starts: give them an exclusive group, long `healthCheckTimeout`, and a persistent weight cache. v1.2.1 names the model after the path or id you pass, so use `useModelName`:

```yaml
models:
  gpt-oss:
    cmd: /opt/llm-stack/start-model.sh run gpt-oss ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop gpt-oss
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /health
    useModelName: openai/gpt-oss-120b
    ttl: 0
    unloadTimeout: 90
```

The wrapper runs `docker run -d --name "$MODEL_ID" ... trtllm-serve ... --port 8000` with `-p "127.0.0.1:${PORT}:8000"` (see `serve-config.md`, container wrapper pattern). `docker logs -f gpt-oss` or llama-swap's `/logs/stream/gpt-oss` for logs; `curl -s http://127.0.0.1:8080/upstream/gpt-oss/metrics` for engine stats. Skill: `npx skills add ScaleDockHQ/llms-skills --skill llama-swap`. Stack-level plumbing: `self-hosted-llms`.

## LiteLLM

```yaml
- model_name: gpt-oss
  litellm_params:
    model: openai/gpt-oss
    api_base: http://127.0.0.1:8080/v1 # llama-swap, or http://127.0.0.1:8000/v1 for trtllm-serve directly
    api_key: os.environ/LLAMA_SWAP_API_KEY # any non-empty value is accepted upstream
```

LiteLLM also bridges Anthropic `/v1/messages` onto chat completions, which `trtllm-serve` does not offer. Skill: `npx skills add ScaleDockHQ/llms-skills --skill litellm`; gateway design: `llm-gateway`.

## Open WebUI

From NVIDIA's Spark playbook (single node):

```bash
docker run -d -e OPENAI_API_BASE_URL="http://localhost:8355/v1" -v open-webui:/app/backend/data \
  --network host --add-host=host.docker.internal:host-gateway --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

The UI is then on port 8080. Pin the Open WebUI image instead of `main` for anything beyond a trial.

## Cursor, Claude Code, other OpenAI clients

Point a client at the gateway's `/v1` base URL with the gateway key, not at `trtllm-serve`. Client set-up lives in `llm-clients` (`npx skills add ScaleDockHQ/llms-skills --skill llm-clients`). Tools and reasoning need the matching `--tool_parser` and `--reasoning_parser`.

## systemd, compose, Kubernetes

- `templates/trtllm-serve.service`: a unit wrapping `docker run` for one model, reading `HF_TOKEN` from a `0600` environment file.
- `templates/docker-compose.yml`: one service with the required `ipc`, `ulimits` and GPU reservation.
- `templates/k8s-deployment.yaml`: single-node Deployment and Service (untested). For multi-node, disaggregation, KV routing and autoscaling use Dynamo (`references/combos/dynamo.md`).

## Tunnels and exposure

Never publish `trtllm-serve` directly. Bind loopback or a private interface and front it with a gateway plus Cloudflare Tunnel or Tailscale (`cloudflare-tunnel`, `tailscale` skills, or `self-hosted-llms`).

## Official links

- Open WebUI on the playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/trt-llm
- OpenAI compatibility examples: https://github.com/NVIDIA/TensorRT-LLM/tree/main/examples/serve/compatibility
