# Authentication for triggers

> Verified against KEDA v2.21.0, 2026-10-11

KEDA reads credentials from a `TriggerAuthentication` (namespaced) or `ClusterTriggerAuthentication`, referenced
from a trigger by `authenticationRef`. Secrets are never put in the ScaledObject.

## Prometheus with bearer, basic or TLS

```bash
chmod 600 /path/to/token-file                            # a 0600 file you control
kubectl create secret generic prom-auth -n llm --from-file=bearerToken=/path/to/token-file
```

`templates/triggerauth-prometheus.yaml` maps the Secret to the scaler's parameters. In the trigger set
`authModes: "bearer"` (or `basic`, `tls`, `custom`; combine like `tls,basic`). Scaler parameters: `bearerToken`;
`username` and `password`; `ca`, `cert`, `key`; `customAuthHeader` and `customAuthValue`.

Cloud-managed Prometheus: AWS Managed Prometheus uses `podIdentity.provider: aws`; Azure Monitor uses Azure workload
identity (no other authModes); Google Managed Prometheus uses GCP workload identity on the KEDA operator.

## Queues

RabbitMQ: a Secret key `host` holding the AMQP URI, mapped with `secretTargetRef` (`parameter: host`). Redis:
`username`/`password` parameters. SQS: `podIdentity.provider: aws` (EKS Pod Identity or IRSA). Names and parameters per scaler:
keda.sh/docs/2.21/scalers/<scaler>.

## Bound service account tokens (breaking in 2.21)

KEDA 2.21 fixes CVE-2026-77524 / GHSA-637c-6jxx-4rwm. Defaults are now `operator.serviceAccountTokens.mode: enforce-audience`:

- A `boundServiceAccountToken` entry needs an operator-approved **audience** for that service account, and the receiver
  (Prometheus proxy, metrics API) must accept that audience. Without it, token minting fails.
- Configure it in the chart (`permissions.operator.restrict.serviceAccountTokenCreationRoles` with `name`, `namespace`,
  `audience`), and make the receiver verify the audience (for example kube-rbac-proxy `--auth-token-audiences`).
  Choose audiences your Kubernetes API server does not accept.
- Prometheus itself does not do TokenReview audience checks; put an authenticating proxy in front.
- Vault Kubernetes auth is also affected (new `hashiCorpVault.kubernetesAuth.audience`, default `vault`).
- Plain secrets, API keys and non-BSAT auth are unaffected.

Inventory before upgrading:

```bash
kubectl get triggerauthentication,clustertriggerauthentication -A -o yaml | grep -E 'boundServiceAccountToken|hashiCorpVault' | sort | uniq -c
```

## Rules

- ClusterTriggerAuthentication is cluster-wide: restrict who may reference it (RBAC) and prefer namespaced TriggerAuthentication.
- Do not echo Secret contents; check with `kubectl get secret <name> -o jsonpath='{.data}' | jq 'keys'`.
