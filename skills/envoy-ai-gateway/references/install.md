# Install Envoy AI Gateway (Agent Router)

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs and repo with Envoy Gateway v1.9.2, 2026-10-11

Two paths: the full gateway on Kubernetes (controller plus Envoy Gateway), or standalone `aigw run` for one host or local testing. Standalone uses the same CRD-shaped configuration, so it is also the quickest way to test a config before deploying it.

## Kubernetes

Requirements for v1.2.x: Kubernetes v1.32+, Envoy Gateway v1.9.2+ (Envoy Proxy v1.39.x), Gateway API v1.6.1, Inference Extension v1.6.2. Use a clean Envoy Gateway; the AI Gateway needs its own values file and a customized existing install can conflict.

```bash
# Read-only preflight
kubectl version -o json | jq -r '.serverVersion.gitVersion'
helm list -A | grep -E 'gateway-helm|aieg' || echo "none installed"
kubectl get ns envoy-gateway-system envoy-ai-gateway-system 2>&1 | head
```

### 1. Envoy Gateway with the project values

```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.2 \
  --namespace envoy-gateway-system --create-namespace \
  -f https://raw.githubusercontent.com/theagentrouter/agent-router/v1.2.0/manifests/envoy-gateway-values.yaml
kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

The docs show `main` in the values URL; pin it to the release tag so the file matches the controller version. Addon values files extend the same release (add more `-f` flags; re-run the same command):

- Usage-based rate limiting: `examples/token_ratelimit/envoy-gateway-values-addon.yaml` (points the Envoy Gateway rate limit service at Redis, default URL `redis.redis-system.svc.cluster.local:6379`).
- InferencePool: `examples/inference-pool/envoy-gateway-values-addon.yaml`.

### 2. AI Gateway CRDs, then controller

```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v1.2.0 --namespace envoy-ai-gateway-system --create-namespace
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v1.2.0 --namespace envoy-ai-gateway-system --create-namespace
kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
kubectl get pods -n envoy-ai-gateway-system
```

If an older install used only `ai-gateway-helm`, run the CRDs chart once with `--take-ownership` to move CRD ownership, then upgrade the main chart. Chart values for tracing, resources and the controller live in the chart (`helm show values oci://docker.io/envoyproxy/ai-gateway-helm --version v1.2.0`).

Charts and images stay under the `envoyproxy` Docker Hub org and chart names despite the rename. `v0.0.0-latest` and `latest` tags track main and are overwritten; do not use them.

### 3. First route (test upstream)

```bash
kubectl apply -f https://raw.githubusercontent.com/theagentrouter/agent-router/v1.2.0/examples/basic/basic.yaml
kubectl wait pods --timeout=2m -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system --for=condition=Ready
SVC=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n envoy-gateway-system "svc/$SVC" 8080:80 &
curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"some-cool-self-hosted-model","messages":[{"role":"user","content":"Hi."}]}' \
  http://localhost:8080/v1/chat/completions
```

`basic.yaml` creates a GatewayClass, a Gateway, an `EnvoyProxy`, a `ClientTrafficPolicy` (50Mi buffer), a route and a test upstream. For real traffic start from `assets/gateway-vllm.yaml`.

Over HTTP/2, Envoy has a second cap (`initialStreamWindowSize`, `initialConnectionWindowSize`); the docs recommend `16Mi` and `24Mi` in the `ClientTrafficPolicy` `http2` block to avoid `413 request_payload_too_large` after raising `bufferLimit`.

### Uninstall

```bash
helm uninstall aieg -n envoy-ai-gateway-system
helm uninstall aieg-crd -n envoy-ai-gateway-system   # deletes the CRDs and all custom resources
helm uninstall eg -n envoy-gateway-system
```

Ask first; removing the CRDs chart deletes every route, backend and policy.

## Standalone `aigw`

Linux and macOS only. Experimental per the docs.

```bash
# Binary from the release, or Docker, or go install
gh release download v1.2.0 -R theagentrouter/agent-router -p 'aigw-darwin-arm64' -D /tmp
#   assets: aigw-darwin-arm64, aigw-linux-amd64, aigw-linux-arm64
docker pull envoyproxy/ai-gateway-cli:v1.2.0

# Auto-configuration from the OpenAI SDK variables
OPENAI_BASE_URL=http://localhost:11434/v1 OPENAI_API_KEY=unused aigw run       # Ollama
OPENAI_API_KEY="$(cat ~/.config/openai/key)" aigw run                          # OpenAI
AZURE_OPENAI_ENDPOINT=https://<res>.openai.azure.com AZURE_OPENAI_API_KEY="$(cat ~/.config/azure/key)" \
  OPENAI_API_VERSION=2024-12-01-preview aigw run                              # Azure
```

It listens on `:1975` (OpenAI-style at `/v1`, MCP at `/mcp`) and serves admin on `:1064` (`/metrics`, `/health`). One catch-all backend takes every model name; for per-model routing use a config file:

```bash
aigw run config.yaml            # same CRD YAML; `${VAR:=default}` is expanded
aigw run --mcp-config mcp-servers.json
```

Start from `examples/aigw/ollama.yaml` in the repo and change the `x-ai-eg-model` match. Config, data, state and runtime directories follow XDG (`AIGW_CONFIG_HOME`, `AIGW_DATA_HOME`, `AIGW_STATE_HOME`, `AIGW_RUNTIME_DIR`, or `--config-home` and friends). `aigw` downloads an Envoy binary on first run.

Docker container variant (`assets/docker-compose.yaml`): bind the published ports to `127.0.0.1` since there is no inbound auth, and reach the host's Ollama through `host.docker.internal:host-gateway`, not `localhost`.

```bash
docker run --rm -p 127.0.0.1:1975:1975 -p 127.0.0.1:1064:1064 \
  -e OPENAI_BASE_URL=http://host.docker.internal:11434/v1 -e OPENAI_API_KEY=unused \
  --add-host host.docker.internal:host-gateway envoyproxy/ai-gateway-cli:v1.2.0 run
```

## Verify

```bash
curl -fsS http://127.0.0.1:1064/health            # standalone
kubectl get gateway,aigatewayroute,aiservicebackend -A
kubectl get gateway -A -o json | jq -r '.items[]|.metadata.name+" "+(.status.conditions[]|select(.type=="Programmed").status)'
```
