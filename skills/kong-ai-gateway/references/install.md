# Install Kong AI Gateway

> Verified against Kong AI Gateway 2.2.0, Kong Gateway OSS 3.9.3, Kong Gateway EE 3.16.0.0, 2026-10-11

Pick the form first (SKILL.md, decision 1). Every path below needs approval before it changes a host or cluster.

## Path A: Kong Gateway OSS, DB-less, ai-proxy (free, one host)

Needs Docker and decK (`deck version`). Use `assets/docker-compose.yaml` and `assets/kong-ai-proxy.yaml`.

```bash
umask 077
export DECK_UPSTREAM_URL=http://host.docker.internal:8000/v1/chat/completions   # your vLLM or Ollama /v1/chat/completions
deck file render assets/kong-ai-proxy.yaml -o kong.rendered.yaml                  # holds secrets: keep 0600, never commit
docker run --rm -e KONG_DATABASE=off -v "$PWD/kong.rendered.yaml:/t.yml:ro" kong:3.9.3 kong config parse /t.yml   # validate
docker compose -f assets/docker-compose.yaml up -d
curl -s http://127.0.0.1:8100/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"hi"}]}'
```

Notes:

- OSS 3.9.3 has `ai-proxy`, `ai-prompt-decorator`, `ai-prompt-guard`, `ai-prompt-template`, `ai-request-transformer` and `ai-response-transformer`. The `ai-proxy` provider list in 3.9.3 is `openai, azure, anthropic, cohere, mistral, llama2, gemini, bedrock, huggingface`; self-hosted OpenAI-compatible servers use `llama2` with `llama2_format: openai`. A `vllm` provider is rejected by 3.9.3 (tested), though the docs for newer releases list it.
- DB-less config is read at boot or posted to the Admin API `/config`. After changing the file, `docker compose restart kong` or `curl -X POST http://127.0.0.1:8101/config -F config=@kong.rendered.yaml`.
- The OSS Admin API has no auth. Never publish 8001 beyond loopback.
- With a database (Postgres) you can manage entities with `deck gateway sync`. DB-less uses `deck file render` plus the file.

## Path B: Kong Gateway Enterprise 3.x (`ai-proxy-advanced`, rate limiting, cache, guardrails, MCP)

The paid plugins need an Enterprise license. The docs' compose uses `kong/kong-gateway:3.16.0.0` with Postgres, `KONG_LICENSE_DATA` from the environment, Admin API on 8001/8444 and Kong Manager on 8002/8445. Get the license file from Kong, keep it `0600`, and pass it by environment variable, never inline.

```bash
export KONG_LICENSE_DATA="$(cat ~/.config/kong/license.json)"      # path is yours; never echo it
```

Fetch the current compose file from the Docker install page (`https://developer.konghq.com/gateway/install/docker/`) and read it before running it. Check `docker run --rm kong/kong-gateway:3.16.0.0 kong version` for the tag you pin. Without a valid license Enterprise features do not work; what the image does unlicensed is not documented in the pages read, so test in a throwaway container before relying on it.

Config goes through decK against the Admin API: `deck gateway diff kong.yaml` then `deck gateway sync kong.yaml` (see `assets/kong-ai-proxy-advanced.yaml`).

## Path C: Kong AI Gateway 2.x with Konnect (control plane in Konnect, data plane anywhere)

Needs a Konnect account and a personal access token (`KONNECT_TOKEN`). The 2.x data plane is the `kong/kong-ai-gateway` image (tag `2.2.0`, variants `-ubuntu`, `-rhel`, `-distroless`, and `-fips-140-3` forms; a plain `2.2.0-debian` does not exist).

Fastest local start, from the docs: the quickstart provisions a control plane named `ai-quickstart` and a local data plane, then prints `AI_GATEWAY_ID`, `KONNECT_PROXY_URL` and related variables:

```bash
export KONNECT_TOKEN=...                                          # from ~/.config file, never pasted into chat
curl -Ls https://get.konghq.com/ai > /tmp/kong-ai-quickstart.sh   # read it before running
bash /tmp/kong-ai-quickstart.sh -k "$KONNECT_TOKEN"
```

Then create entities with `kongctl` v1.20.2 or newer (`kongctl version`): `kongctl apply -f assets/ai-gateway-2.kongctl.yaml --pat "$KONNECT_TOKEN"` and review the plan before confirming. See `references/ai-gateway-2.md`.

### Kubernetes with Helm (data plane only)

Chart `kong/kong-ai-gateway` (0.2.1 at write time; chart default image tag was 2.0.3, so set the tag). It deploys a Konnect-only hybrid data plane and needs a client mTLS certificate Konnect trusts for the control plane.

```bash
helm repo add kong https://charts.konghq.com && helm repo update
helm search repo kong/kong-ai-gateway --versions | head -5
helm show values kong/kong-ai-gateway | head -80
helm install my-ai-gateway kong/kong-ai-gateway -n kong --create-namespace -f assets/helm-values-kong-ai-gateway.yaml
```

### Kubernetes with Kong Operator (CRDs)

The docs enable the AI Gateway controllers on the `kong/kong-operator` chart (1.5.0-rapid.2.0 in the docs):

```bash
helm upgrade --install kong-operator kong/kong-operator -n kong-system --create-namespace \
  --version 1.5.0-rapid.2.0 --set env.ENABLE_CONTROLLER_KONNECT=true --set env.ENABLE_CONTROLLER_AIGATEWAYDATAPLANE=true
kubectl get crd | grep -E 'aigateway|aigatewaydataplane'
```

Resources: `KonnectAPIAuthConfiguration`, `KonnectAIGateway`, `AIGatewayModelProvider`, `AIGatewayModel` (group `aiconfiguration.konghq.com/v1alpha1`) and `AIGatewayDataPlane` (`aigateway.konghq.com/v1alpha1`). Provider secrets need the label `konghq.com/secret=true`. Follow the docs page "Deploy Kong AI Gateway with Kong Operator" for the manifests.

## Discover

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -i kong
kong version 2>/dev/null; docker run --rm kong:3.9.3 kong version
curl -s http://127.0.0.1:8101/ | jq -r '.version, .configuration.database'
curl -s http://127.0.0.1:8101/plugins/enabled | jq -r '.enabled_plugins[]' | grep '^ai-'
kubectl get deploy,svc -A 2>/dev/null | grep -i kong
deck version; kongctl version
```
