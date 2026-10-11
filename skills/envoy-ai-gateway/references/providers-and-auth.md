# Providers, backends and upstream auth

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs and examples/basic manifests, 2026-10-11

## Resource model

| Resource                | Job                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------ |
| `AIGatewayRoute`        | Entry point on a Gateway: input schema, match rules (by model), backends, costs      |
| `AIServiceBackend`      | One upstream with an output `schema`; references an Envoy Gateway `Backend`          |
| `BackendSecurityPolicy` | Upstream credentials for one or more `AIServiceBackend`s (via `targetRefs`)          |
| `Backend` (Envoy GW)    | The actual endpoint: `fqdn` hostname and port, or IP                                 |
| `BackendTLSPolicy`      | TLS validation to the upstream (needed for HTTPS providers)                          |
| `GatewayConfig`         | Per-Gateway extproc env vars, resources, metadata forwarding (annotation on Gateway) |
| `QuotaPolicy`           | Token budget per backend and model (v1alpha1 only)                                   |
| `MCPRoute`              | MCP gateway route (see `mcp-and-inference.md`)                                       |

API group `aigateway.envoyproxy.io`, version `v1beta1` (v1alpha1 deprecated). A route's `parentRefs` points at a Gateway; the generated `HTTPRoute` has the same name as the `AIGatewayRoute`.

```bash
kubectl get aigatewayroute,aiservicebackend,backendsecuritypolicy,backend -A
kubectl describe aiservicebackend -n <ns> <name>      # status conditions, schema errors
```

## Schema per provider (`AIServiceBackend.spec.schema`)

The schema is the upstream's API dialect; clients keep speaking OpenAI (or Anthropic) to the gateway and the gateway translates.

| Upstream                                                                          | `schema`                                                                                                             | Credentials type (BackendSecurityPolicy) |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| OpenAI                                                                            | `{name: OpenAI, prefix: /v1}` (prefix optional; default is `/v1`)                                                    | `APIKey`                                 |
| Any OpenAI-compatible server                                                      | `{name: OpenAI, prefix: /v1}` (vLLM, Ollama, llama.cpp, SGLang)                                                      | none, or `APIKey`                        |
| Azure OpenAI                                                                      | `{name: AzureOpenAI, version: 2025-01-01-preview}` or `OpenAI` with prefix `/openai/v1`                              | `AzureAPIKey` or `AzureCredentials`      |
| AWS Bedrock                                                                       | `{name: AWSBedrock}`; Claude via `{name: AWSAnthropic, version: bedrock-2023-05-31}`                                 | `AWSCredentials`                         |
| Bedrock OpenAI-compatible (1.2)                                                   | `{name: AWSOpenAI}`                                                                                                  | `AWSCredentials`                         |
| Google Vertex AI                                                                  | `{name: GCPVertexAI}`; Claude `{name: GCPAnthropic, version: vertex-2023-10-16}`                                     | `GCPCredentials`                         |
| Anthropic                                                                         | `{name: Anthropic}`                                                                                                  | `AnthropicAPIKey`                        |
| Cohere                                                                            | `{name: Cohere, version: v2}` or `OpenAI` with prefix `/compatibility/v1`                                            | `APIKey`                                 |
| Gemini (AI Studio), Groq, Together, Mistral, DeepSeek, DeepInfra, SambaNova, Grok | `OpenAI` with the provider's prefix (for example Gemini `/v1beta/openai`, Groq `/openai/v1`, DeepInfra `/v1/openai`) | `APIKey`                                 |

Check the supported-providers page for the provider's exact prefix; it changes. Supported endpoints include chat completions, completions, embeddings, Responses, image generation, audio, Cohere rerank (`/cohere/v2/rerank`) and Anthropic Messages (`/v1/messages`, with count tokens) for Anthropic, GCP Anthropic and AWS Anthropic backends. Not every provider supports every endpoint; the endpoints page lists which.

## Self-hosted OpenAI-compatible backend (vLLM, Ollama)

Inside the cluster, point `Backend` at the Service FQDN. Outside, use the host or IP.

```yaml
apiVersion: aigateway.envoyproxy.io/v1beta1
kind: AIServiceBackend
metadata: { name: vllm, namespace: default }
spec:
  schema: { name: OpenAI }
  backendRef: { name: vllm, kind: Backend, group: gateway.envoyproxy.io }
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata: { name: vllm, namespace: default }
spec:
  endpoints:
    - fqdn: { hostname: vllm.llm.svc.cluster.local, port: 8000 }
```

No security policy is needed when the server is unauthenticated. For a server with `--api-key`, attach an `APIKey` policy. Use `modelNameOverride` on the route's `backendRef` when the served name differs from the client-facing alias (see `routing-and-fallback.md`). For pools of GPU replicas with prefix-aware picking, use an InferencePool instead (`mcp-and-inference.md`).

## Hosted provider with API key

```yaml
apiVersion: aigateway.envoyproxy.io/v1beta1
kind: BackendSecurityPolicy
metadata: { name: openai-apikey, namespace: default }
spec:
  targetRefs:
    - { group: aigateway.envoyproxy.io, kind: AIServiceBackend, name: openai }
  type: APIKey
  apiKey:
    secretRef: { name: openai-apikey } # Secret key: apiKey
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata: { name: openai, namespace: default }
spec:
  endpoints:
    - fqdn: { hostname: api.openai.com, port: 443 }
---
apiVersion: gateway.networking.k8s.io/v1
kind: BackendTLSPolicy
metadata: { name: openai-tls, namespace: default }
spec:
  targetRefs:
    - { group: gateway.envoyproxy.io, kind: Backend, name: openai }
  validation:
    wellKnownCACertificates: System
    hostname: api.openai.com
```

Create the Secret without printing it:

```bash
kubectl create secret generic openai-apikey -n default \
  --from-file=apiKey=<(tr -d '\n' < ~/.config/openai/key)
```

Anthropic uses `type: AnthropicAPIKey` with `anthropicAPIKey.secretRef`; Azure uses `AzureAPIKey` or `AzureCredentials` (`clientID`, `tenantID`, `clientSecretRef`, or OIDC); Vertex uses `GCPCredentials` with `projectName`, `region` and either `credentialsFile.secretRef` or workload identity federation. The `basic.yaml`-style examples in `examples/basic/` (`openai`, `anthropic`, `aws`, `aws-irsa`, `aws-pod-identity`, `azure_openai`, `gcp_vertex`, `cohere`, `tars`) are the authoritative starting points.

## AWS Bedrock credentials

```yaml
spec:
  targetRefs:
    [{ group: aigateway.envoyproxy.io, kind: AIServiceBackend, name: bedrock }]
  type: AWSCredentials
  awsCredentials:
    region: us-east-1
    # Option A: static credentials file in a Secret
    credentialsFile: { secretRef: { name: aws-credentials } }
    # Option B: omit both, use the AWS SDK default chain (IRSA, Pod Identity, instance profile)
```

Prefer IRSA, Pod Identity or OIDC exchange over long-lived access keys. Docs describe automated short-lived credentials for Bedrock (OIDC to AWS STS), Azure (Entra ID) and Vertex (workload federation to Google STS); API keys are the manual path.

## Per-request (per-tenant) credentials

`credentialOverride` on a `BackendSecurityPolicy` lets a trusted filter (typically `ext_authz`) supply the credential per request, so each tenant is billed to their own provider account.

- `fromDynamicMetadata: {namespace, key}`: recommended. Clients cannot forge it, and there is no header to leak on retries or fallback. The namespace must be listed in the Gateway's `GatewayConfig` under `extProc.metadataForwardingNamespaces` (required in v1.2.0); only untyped metadata is read. AWS needs a struct `{accessKeyId, secretAccessKey, sessionToken?}`.
- `fromRequestHeaders: {}`: reads `x-aigw-api-key` for `APIKey`; safe only if the trusted layer overwrites or rejects client-supplied values. Avoid with multi-backend fallback routes.
- `fallbackToConfigured` (default `true`): fall back to the static credential, or `false` to answer 401 without contacting the provider. Roll out with `true`, then tighten.

## Gateway auth (inbound)

The AI Gateway adds no inbound authentication. Use Envoy Gateway `SecurityPolicy` (JWT, API key, basic auth, ext auth, OIDC) on the Gateway or route, `ClientTrafficPolicy` for TLS and buffers, and `BackendTrafficPolicy` for retries, timeouts and rate limits. For standalone `aigw`, keep ports bound to loopback or put `caddy` or `tailscale` in front.

## Discovery

```bash
kubectl get aiservicebackend -A -o json | jq -r '.items[]|.metadata.namespace+"/"+.metadata.name+" "+.spec.schema.name'
kubectl get backendsecuritypolicy -A -o json | jq -r '.items[]|.metadata.name+" "+.spec.type'   # no secret values
kubectl get secret -n default openai-apikey -o jsonpath='{.data}' | jq 'keys'                    # key names only
```
