# Private access, residency and data retention

> Verified against Agent Platform docs (VPC Service Controls with Agent Platform, Allow access from a private endpoint inside a VPC Service Controls perimeter, Private Service Connect for online inference, Private Service Connect interfaces, Deployments and endpoints, Zero data retention), 2026-10-11

## Network paths

| Need                                             | Mechanism                                                                                                                                      |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Private path to Google APIs from VPC or on-prem  | Private Service Connect (PSC) for Google APIs or Private Google Access. These do not remove public reachability of the API; IAM still applies. |
| Block public use and exfiltration                | VPC Service Controls perimeter plus the **restricted VIP** via PSC for Google APIs.                                                            |
| Serve your own model without public IPs          | Dedicated private endpoint using PSC: service attachment on the endpoint, forwarding rule in your VPC.                                         |
| Producer services calling back into your network | PSC interfaces (network attachment and subnet).                                                                                                |

With PSC for Google APIs, the Agent Platform host becomes `LOCATION-aiplatform-restricted.p.googleapis.com` pointing at your endpoint IP. For other clouds, add a private DNS zone `p.googleapis.com` with an A record for that name. Example call through it:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  "https://us-central1-aiplatform-restricted.p.googleapis.com/v1/projects/$PROJECT_ID/locations/us-central1/publishers/google/models/$MODEL_ID:generateContent" \
  -d @request.json
```

Notes from the docs: Model Garden one-click public dedicated endpoints are unsupported in a VPC-SC environment (use a private endpoint). Inside a perimeter, producer-side internet egress is blocked; route it through a proxy VM and Cloud NAT if needed. Agent Runtime provides no internet egress.

## Residency

- Pick a regional or multi-region (`us`, `eu`) location when data must stay put. `global` routes anywhere.
- Per-model location tables: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/locations
- RAG Engine supports VPC-SC and CMEK; data residency controls are not supported there (per the quotas page).

## Retention and zero data retention

Google states it does not train or fine-tune models on your data without permission, for all managed models. Retention you control:

- **Abuse-monitoring prompt logging** for Google models applies to customers under the Google Cloud Platform Terms; request an exception for zero retention. Advanced AI models may log prompts and responses regardless; ask your account team.
- **In-memory caching** of Gemini inputs and outputs is on by default (project-isolated, 24-hour TTL, not at rest). Disable per project (needs `roles/aiplatform.admin`):

```bash
# Read current setting (roles/aiplatform.viewer, user or admin)
curl -sS -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  "https://us-central1-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/cacheConfig"

# Turn caching off
curl -sS -X PATCH -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  "https://us-central1-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/cacheConfig" \
  -d "{\"name\":\"projects/$PROJECT_ID/cacheConfig\",\"disableCache\":true}"
```

- **Request-response logging** to BigQuery is off by default; do not enable it for zero retention.
- **Grounding with Google Search** stores logs for up to 3 days and cannot be disabled; Grounding with Google Maps stores prompts and outputs for 30 days. Use Web Grounding for Enterprise if you need zero retention.
- **Interactions API** `store` defaults to true; set `store=false`.
- Gemini Live session resumption (24 hours) is off by default; leave it off.

Source: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention

Log hygiene for the gateway and tracing sits with `llm-gateway` and `llm-observability`. For the cross-provider checklist see `cloud-llms`.

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/general/vpc-service-controls
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/general/vpcsc-separate-perimeters
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/general/vpc-psc-i-multicloud-access
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/general/psc-interfaces
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/private-service-connect
