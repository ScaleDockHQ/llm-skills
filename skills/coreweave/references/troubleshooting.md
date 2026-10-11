# CoreWeave: troubleshooting

> Verified against CoreWeave docs: Managed Authentication in CKS, Create a Node Pool, Getting started with Dedicated Inference, Serverless Inference support articles (401, 402, 403, 429), Spot Node Pools, 2026-10-11

| Symptom or error string                                                             | Cause                                                 | Fix                                                                           |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| `403 Forbidden` on every kubectl call, `couldn't get current server API group list` | CKS token missing, malformed, expired or revoked      | Create a new token, download a fresh kubeconfig                               |
| `certificate-authority-data` errors on a new cluster                                | Managed endpoint uses a public cert                   | Use the console kubeconfig unchanged; do not add the CA field                 |
| `Warning CWOverQuota ... TargetNodes pushes org over quota`                         | Node Pool exceeds instance-type quota                 | Lower `targetNodes`, or ask your CoreWeave representative to raise quota      |
| `QUEUED` nodes, `QueuedAwaitingCapacity`                                            | No free capacity for that type                        | Wait, pick another type or zone                                               |
| Pods Pending after spot preemption                                                  | Spot pool emptied (`Deleted for preemption`)          | Use a default pool for essential replicas                                     |
| GPU Operator conflicts                                                              | Installed the NVIDIA GPU Operator                     | Remove it; CoreWeave manages it                                               |
| Dedicated 403 `organization is not allowed to perform this operation`               | Not enabled for Dedicated Inference                   | Ask support or your representative with your org id                           |
| Dedicated 403 `insufficient permissions for this operation`                         | Token identity lacks Inference Admin                  | Add the role, retry                                                           |
| `organization has no GPU quota for it`                                              | No inference GPU quota for the instance type          | Open a support ticket; `capacityClasses` does not help                        |
| `validation error: name: must be a valid hostname label`                            | Deployment or gateway name has dots or bad characters | Use lowercase letters, digits, hyphens (gateway up to 38 chars)               |
| `{"code":3, "message":"model path has no objects: path ..."}`                       | Wrong model path                                      | Fix bucket and path split                                                     |
| `model bucket is not accessible...` or weights fail to load                         | Missing bucket policy for the service account         | Add the `AllowInference` policy statement and verify with `get-bucket-policy` |
| SSL handshake or DNS error on a new gateway                                         | DNS and TLS provision asynchronously                  | Wait a few minutes, retry                                                     |
| Deployment stuck, then `STATUS_FAILED`                                              | Bad engine config, memory, weights                    | Read logs in Grafana (`vllm-server` container); fix and recreate              |
| Serverless `401 Authentication failed`                                              | Bad or expired Forge key, wrong `team/project`        | Regenerate key; set `OpenAI-Project: team/project` exactly                    |
| Serverless `402 You exceeded your current quota`                                    | No credits or monthly cap reached                     | Add credits, raise the cap through support                                    |
| Serverless `403 The inference gateway is not enabled for your organization`         | Org-level gateway disabled                            | Ask an org admin or Forge support to enable it                                |
| Serverless `429 Concurrency limit reached for requests`                             | Too many parallel requests per project or user        | Reduce concurrency, backoff, request an increase                              |
| Grafana dashboards empty                                                            | Missing Observability Viewer role                     | Add it to an IAM access policy                                                |

## Sources

- https://docs.coreweave.com/products/cks/auth-access/managed-auth/kubeconfig
- https://docs.coreweave.com/products/cks/nodes/create
- https://docs.coreweave.com/products/inference/getting-started
- https://docs.coreweave.com/support/inference/articles/api-error-code-403-the-inference-gateway
- https://docs.coreweave.com/support/models/articles/why-am-i-getting-rate-limit-errors-429-w
