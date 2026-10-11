# MCP gateway and InferencePool

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs, release notes and examples (mcp, inference-pool), 2026-10-11

## MCP gateway

`MCPRoute` (v1beta1 preferred, v1alpha1 deprecated) puts several MCP servers behind one Streamable HTTP endpoint, with OAuth, tool filtering and upstream credentials. Clients connect to the route's `path` (for example `http://<gateway>/mcp`). Tool names are prefixed with the backend name (`github__issue_read`) so calls route to the right server.

```yaml
apiVersion: aigateway.envoyproxy.io/v1beta1
kind: MCPRoute
metadata: { name: mcp, namespace: default }
spec:
  parentRefs:
    - { name: llm, kind: Gateway, group: gateway.networking.k8s.io }
  path: /mcp
  backendRefs:
    - name: github
      kind: Backend
      group: gateway.envoyproxy.io
      path: /mcp/x/issues/readonly
      toolSelector: { includeRegex: [".*issues?.*"] } # exactly one of include / includeRegex
      securityPolicy:
        apiKey: { secretRef: { name: github-token } } # injected upstream
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata: { name: github, namespace: default }
spec:
  endpoints: [{ fqdn: { hostname: api.githubcopilot.com, port: 443 } }]
```

An HTTPS MCP upstream also needs a `BackendTLSPolicy` (see `providers-and-auth.md`).

Options, by version:

- `toolSelector` (`include`, `includeRegex`) and `promptSelector` (include/exclude plus regex, v1.2.0) filter what clients see.
- `forwardHeaders` passes named client headers to one backend (per-user tokens). Values go through verbatim, so send `Bearer ...` yourself. With `securityPolicy.apiKey.injectionPolicy: IfNotPresent` (v1.2.0) a caller's token wins and a shared service key is the fallback; not with `queryParam`.
- `prefixMode: Never` (v1.2.0, route or backendRef) removes the `<backend>__` prefix; only safe when tool names do not collide.
- `securityPolicy.oauth`: `issuer`, `audiences`, `protectedResourceMetadata`, optional `authorizationServerMetadataUrl` for non-standard metadata locations. Implements the MCP authorization-code-with-PKCE flow; the gateway answers 401 with `WWW-Authenticate` and serves resource metadata. **In v1.2.0 the token's `iss` must equal `oauth.issuer` exactly** (trailing slash included) or the gateway returns 401.
- `securityPolicy.authorization.rules`: scopes, claims and tool targets, plus CEL. CEL that references `auth.jwt` requires `securityPolicy.oauth` in v1.2.0.
- `securityPolicy.mergeType` and `backendTrafficPolicy.mergeType` (v1.2.0) keep Gateway-level policies from being replaced by the generated ones (`Replace` is rejected).
- Sessions: the gateway encodes backend session IDs into one session. Since v1.2.0 the chart generates a random encryption seed in Secret `<controller fullname>-mcp-session-encryption` and reuses it on upgrade; the old default `default-insecure-seed` is gone. Pods that share sessions must share the seed.

Check MCP traffic:

```bash
kubectl get mcproute -A
kubectl describe mcproute -n default mcp | sed -n '/Conditions/,$p'
curl -sS -X POST http://127.0.0.1:8080/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}' | head -c 400
```

### Standalone

`aigw run --mcp-config mcp-servers.json` serves the same at `http://localhost:1975/mcp`:

```json
{
  "mcpServers": {
    "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "headers": { "Authorization": "Bearer ${GITHUB_ACCESS_TOKEN}" },
      "includeTools": ["issue_read", "list_issues"]
    }
  }
}
```

`type` accepts `http`, `streamable-http`, `streamable_http` or `streamableHttp`. `--mcp-json '<inline json>'` does the same inline. Bearer headers are lifted into injected API keys; keep the token in an environment variable, not in the file.

The docs also describe an A2A (agent-to-agent) capability; check its page for the current resource kinds before using it.

## InferencePool

For self-hosted GPU replicas, route to a Gateway API Inference Extension `InferencePool` instead of a single `AIServiceBackend`. An endpoint picker (EPP) chooses the replica per request from live metrics (queue depth, KV cache, LoRA state). Concepts and EPP tuning: skill `gateway-api-inference-extension`.

Setup (v1.2.x pairs with Inference Extension v1.6.2):

```bash
# 1. Inference Extension CRDs and controller manifests (version from the compatibility matrix)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v1.6.2/manifests.yaml
# 2. Envoy Gateway with BOTH the base values and the InferencePool addon values (see install.md)
# 3. Your InferencePool + EPP (examples/inference-pool/base.yaml shows two)
```

Route to it from an `AIGatewayRoute` (model-based matching, token limits and metrics still apply) or from a plain `HTTPRoute`:

```yaml
rules:
  - matches:
      [
        {
          headers:
            [
              {
                type: Exact,
                name: x-ai-eg-model,
                value: meta-llama/Llama-3.1-8B-Instruct,
              },
            ],
        },
      ]
    backendRefs:
      - {
          group: inference.networking.k8s.io,
          kind: InferencePool,
          name: vllm-llama3-8b-instruct,
        }
```

Notes: `modelNameOverride`, `priority` and the `weight`-based fallback are ignored for InferencePool refs. An InferencePool without `endpointPickerRef` is `Accepted=False` (`EndpointPickerRefMissing`) as of v1.2.0. `appProtocol: kubernetes.io/h2c` is honored for cleartext HTTP/2 model servers. Use the AIGatewayRoute form when you want gateway-level token accounting and mixed InferencePool and provider backends in one route. For the model servers themselves see `vllm` and `llm-d`.

```bash
kubectl get inferencepool -A
kubectl get inferencepool -A -o json | jq -r '.items[]|.metadata.name+" "+([.status.parents[]?.conditions[]?|select(.type=="Accepted")|.status]|join(","))'
```
