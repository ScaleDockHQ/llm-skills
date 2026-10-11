# Troubleshooting

> Verified against Agent Router (Envoy AI Gateway) v1.2.0 docs, chart values and examples, 2026-10-11

Start here, all read-only:

```bash
kubectl get gateway,httproute,aigatewayroute,aiservicebackend,backendsecuritypolicy,backend -A
kubectl describe aigatewayroute -n <ns> <name> | sed -n '/Status/,$p'
kubectl describe aiservicebackend -n <ns> <name> | sed -n '/Status/,$p'
kubectl get pods -n envoy-ai-gateway-system
kubectl get pods -n envoy-gateway-system
kubectl logs -n envoy-ai-gateway-system deploy/ai-gateway-controller --tail=100
kubectl logs -n envoy-gateway-system deploy/envoy-gateway --tail=100
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=<gw> --all-containers --tail=100
```

| Symptom                                                     | Likely cause                                                                                                                                  | Fix                                                                                                                                               |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 404 on `/v1/chat/completions`                               | No `AIGatewayRoute` rule matches `x-ai-eg-model`; wrong `parentRefs`; Gateway not Programmed                                                  | Compare the request `model` with rule `matches`; `kubectl get gateway` conditions; regex rules need `type: RegularExpression`                     |
| 404 or 400 from the upstream                                | Wrong schema or prefix (Gemini `/v1beta/openai`, Groq `/openai/v1`); Azure deployment name                                                    | Fix `schema.name`, `schema.prefix`, `version`; check `modelNameOverride`                                                                          |
| 413 `request_payload_too_large`, truncated responses        | Envoy Gateway buffer limit is 32 KiB by default; HTTP/2 window caps                                                                           | `ClientTrafficPolicy` with `connection.bufferLimit` (example 50Mi) and `http2.initialStreamWindowSize: 16Mi`, `initialConnectionWindowSize: 24Mi` |
| 401 or 403 from the provider                                | Secret missing, wrong key name (`apiKey`), wrong policy type, expired token                                                                   | `kubectl get secret` key names only; match `type` to provider; for AWS check region and role; rotate and re-apply                                 |
| 401 from the gateway on `/mcp`                              | OAuth token `iss` does not match `oauth.issuer` (exact, v1.2.0), audience mismatch                                                            | Align issuer string including trailing slash; check `audiences` and JWKS reachability                                                             |
| 503 `upstream connect error`, TLS errors                    | HTTPS upstream without `BackendTLSPolicy`; wrong port; DNS                                                                                    | Add the TLS policy with `hostname`; check the `Backend` fqdn and port; test from a debug pod                                                      |
| 429                                                         | Token rate limit or QuotaPolicy exhausted, or provider 429                                                                                    | Look at the response body and Envoy log; `limits-and-quota.md`; tenant header missing makes selectors skip or share buckets                       |
| Rate limits never trigger                                   | Rate-limit addon values not applied, Redis down, `llmRequestCosts` keys differ from the policy's metadata key, response had no usage          | Re-run the Envoy Gateway helm upgrade with addon values; check `redis` and `envoy-ratelimit` pods; align `metadataKey` and `key`                  |
| QuotaPolicy has no effect                                   | Dedicated quota service not deployed (fails open), `modelName` differs from `modelNameOverride`, window not `1s`/`1m`/`1h`/`1d`               | Deploy the service at `controller.quotaRateLimitServiceAddr`; align names; consider `quotaRateLimitFailureModeDeny: true`                         |
| Fallback never fires                                        | No `BackendTrafficPolicy` on the generated HTTPRoute, wrong `targetRefs` name, status code not in `retryOn`, same `priority` on both backends | Name must equal the AIGatewayRoute; put fallback at higher `priority` number; add status codes and triggers                                       |
| Fallback fires but fails                                    | Fallback provider lacks the feature (tools, JSON schema), or credentials missing there                                                        | Test the fallback backend directly; check its `BackendSecurityPolicy`                                                                             |
| Streaming hangs or cuts at a minute                         | Idle or request timeout in Envoy                                                                                                              | `BackendTrafficPolicy.timeout`; `examples/stream_idle_timeout`                                                                                    |
| Route `Accepted=False`, `ResolvedRefs` false                | `AIServiceBackend` or `Backend` missing, cross-namespace without `ReferenceGrant`                                                             | Read the condition message; add the object or grant                                                                                               |
| InferencePool `Accepted=False` (`EndpointPickerRefMissing`) | No `endpointPickerRef`                                                                                                                        | Add the EPP reference per the Inference Extension manifests                                                                                       |
| `kubectl apply` of CRs fails with unknown kind              | CRDs chart not installed, or old CRDs                                                                                                         | Install `ai-gateway-crds-helm` first; `--take-ownership` when migrating from the single chart                                                     |
| `helm install` stalls pulling from `docker.io`              | Network or rate limit                                                                                                                         | Pull through a mirror, or install charts from a repo checkout (docs link the source instructions)                                                 |
| Controller up but no extproc sidecar on Envoy pods          | Envoy Gateway installed without the project values (extension manager config missing), or an existing customized install                      | Re-run `helm upgrade eg ... -f manifests/envoy-gateway-values.yaml`; use a clean Envoy Gateway                                                    |
| `aigw run` exits at start                                   | Unsupported OS (Linux and macOS only), port 1975 or 1064 in use, Envoy binary download blocked, bad config                                    | Check the log under `AIGW_STATE_HOME`; `lsof -nP -iTCP:1975`; run with `AIGW_DEBUG=1`                                                             |
| Docker `aigw` cannot reach host Ollama                      | `localhost` inside the container                                                                                                              | `OPENAI_BASE_URL=http://host.docker.internal:11434/v1` and `--add-host host.docker.internal:host-gateway`; Ollama must listen beyond loopback     |
| Wrong model name in metrics                                 | `modelNameOverride`, or provider returned a dated snapshot                                                                                    | Compare `gen_ai.original.model`, `request.model`, `response.model`                                                                                |
| `AI_GATEWAY_TRACING_SEMCONV` crash                          | Unrecognized value                                                                                                                            | Use `openinference` or `gen_ai`                                                                                                                   |

## Check a single backend path

```bash
# Is the Backend reachable from inside the cluster?
kubectl run -it --rm dbg --image=curlimages/curl --restart=Never -- \
  curl -sS -m 5 -o /dev/null -w '%{http_code}\n' http://vllm.llm.svc.cluster.local:8000/v1/models
# What does the Gateway resolve to?
kubectl get gateway -A -o json | jq -r '.items[]|.metadata.name+" "+(.status.addresses[0].value // "no-address")'
```

## When to escalate

Search existing issues in `theagentrouter/agent-router` (old `envoyproxy/ai-gateway` links redirect) for the exact error string, then open one with the controller version, Envoy Gateway version, the redacted route and backend YAML, and logs. Do not paste Secrets or provider keys.
