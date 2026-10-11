# Security and compliance in the cloud

> Verified against AWS IAM temporary credentials, AWS Secrets Manager, Amazon Bedrock PrivateLink and data protection docs, Google Cloud Workload Identity Federation, Secret Manager and Agent Platform zero data retention docs, Microsoft Entra managed identities, Azure Key Vault and Foundry data privacy docs, vLLM v0.31.0 security notes, provider data pages (OpenAI, Anthropic, Gemini API), 2026-10-11

## Identity: least privilege, short-lived credentials

- **Prefer identities over keys.** AWS: IAM roles (instance profiles, IRSA/EKS Pod Identity, SSO) issue temporary credentials. Google Cloud: service accounts with Workload Identity Federation instead of key files. Azure: managed identities with Entra ID instead of API keys.
- **Scope narrowly.** Allow invoking specific models or endpoints, not `*`. Separate identities for the gateway, CI and humans.
- **Vendor API keys** (OpenAI, Anthropic, Gemini, open-model APIs) cannot be short-lived on most platforms: scope them per project or workspace, store them in a secret manager, rotate on a schedule and after any exposure.
- **Clients never hold provider credentials.** They get gateway virtual keys that can be revoked individually.

## Secrets never touch output

- Store secrets in AWS Secrets Manager, Google Secret Manager or Azure Key Vault (or Kubernetes Secrets synced from them).
- Inject into the gateway process as environment variables or mounted files; reference them in config as `os.environ/NAME`.
- Commands must not print secrets. Patterns:

```bash
# Check a variable is set without printing it
[ -n "${OPENAI_API_KEY:-}" ] && echo "OPENAI_API_KEY is set" || echo "OPENAI_API_KEY missing"

# Read a key from a file with restricted permissions instead of typing it
chmod 600 ~/.config/llm/provider.key
export PROVIDER_API_KEY="$(cat ~/.config/llm/provider.key)"

# Kubernetes Secret from a file, never from a literal on the command line
kubectl create secret generic hf-token-secret --from-file=token=<path-to-token-file>
```

- Never paste keys into manifests, tickets, chat, commit messages or shell history. If a key appears in output, rotate it.

## Network: private endpoints

| Platform                         | Private access to model APIs                                                                    |
| -------------------------------- | ----------------------------------------------------------------------------------------------- |
| AWS Bedrock                      | Interface VPC endpoints (AWS PrivateLink) for the Bedrock runtime                               |
| Agent Platform (Vertex AI)       | Private Service Connect; VPC Service Controls perimeters                                        |
| Microsoft Foundry / Azure OpenAI | Private endpoints (Azure Private Link); disable public network access                           |
| Self-hosted on VMs / Kubernetes  | Private subnets, security groups / firewall rules, NetworkPolicies; only the gateway is exposed |

- Run the gateway in the same VPC/VNet and region as the private endpoints.
- Expose only the gateway, over TLS, behind authentication. Engines stay private: vLLM's `--api-key` protects only `/v1`, `/v2` and `/inference` routes, not `/invocations` and others.
- Egress allow-lists on the gateway subnet make data paths explicit and block accidental calls to unapproved providers.

## Know the data path

For each alias, document every hop and its terms:

```
client → gateway (region, logs?) → provider endpoint (region, retention, training use) → upstream (for routers)
                ↘ tracing / logging (retention, who can read)
```

Per provider, record:

- [ ] Training use (default and opt-out).
- [ ] Retention (abuse monitoring, stored features such as batches, files, stored responses).
- [ ] Zero data retention eligibility and approval status.
- [ ] Region / geography of inference and storage; global routing options disabled if residency matters (Bedrock global inference profiles, Foundry Global deployment types, Agent Platform `global` location).
- [ ] Contract coverage: DPA (GDPR), BAA (HIPAA), and which services and regions it covers.

Provider summaries are in `frontier-apis.md`, `open-model-apis.md` and `hyperscalers.md`; the decision-level view is in `choosing-llm-hosting` (`references/privacy-compliance.md`).

## Logging and PII

- Gateway and tracing tools can store full prompts and responses. Decide per alias whether to log content, metadata only, or nothing.
- Set retention on every log sink; restrict who can read traces.
- Redact or hash identifiers before logging where possible; never log request headers that carry keys.
- Cloud audit logs (CloudTrail, Cloud Audit Logs, Azure Activity Log) record who changed endpoints and keys; keep them on.
- Observability setup is owned by `llm-observability`.

## Data residency

- Pin the region on every endpoint; avoid global routing for regulated data.
- Use geography-scoped options when one region lacks capacity: Bedrock geographic cross-Region inference profiles, Foundry Data Zone deployments.
- Anthropic's `inference_geo` and OpenAI's data residency controls (project-level, via sales) apply to their direct APIs.
- Keep the gateway, logs and vector stores in the same jurisdiction as the model endpoint.

## Official links

- AWS temporary credentials: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html
- AWS Secrets Manager: https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html
- Bedrock PrivateLink: https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html
- Bedrock data protection: https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html
- Google Workload Identity Federation: https://docs.cloud.google.com/iam/docs/workload-identity-federation
- Google Secret Manager: https://docs.cloud.google.com/secret-manager/docs
- Agent Platform zero data retention: https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention
- Azure managed identities: https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
- Azure Key Vault: https://learn.microsoft.com/en-us/azure/key-vault/general/overview
- Azure OpenAI data privacy: https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/openai/data-privacy
- vLLM security: https://docs.vllm.ai/en/latest/usage/security/
- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- Anthropic API and data retention: https://platform.claude.com/docs/en/build-with-claude/zero-data-retention
