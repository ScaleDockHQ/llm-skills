# Teardown and troubleshooting

> Verified against Microsoft Foundry docs (Create a project, Quickstart clean up, Recover or purge deleted Foundry resources, Deployments - Delete REST reference, Troubleshoot common HTTP errors, Quickstart error notes), Azure ML online endpoint deploy docs, az CLI references, 2026-10-11

## What bills

- Provisioned (PTU) deployments, whether or not traffic flows, and they keep billing on a soft-deleted account until purged.
- Azure ML online deployments: per instance-hour for GPU VMs (an endpoint with no deployment bills no compute).
- Pay-per-token usage and batch jobs while consumed.
- Storage, Key Vault, private endpoints, Log Analytics, ACR images, Logic Apps or runbooks you created.

## Teardown order

Ask before deleting. Inventory first (see the discovery block in `SKILL.md`).

```bash
# 1. Model deployments (stops PTU billing)
az cognitiveservices account deployment delete -n "$RESOURCE" -g "$RG" --deployment-name "$DEPLOYMENT"

# 2. Azure ML: delete deployment first, then endpoint
az ml online-deployment delete -n blue --endpoint-name my-llm -g "$RG" -w "$WS" --yes
az ml online-endpoint delete -n my-llm -g "$RG" -w "$WS" --yes --no-wait

# 3. Foundry projects (permanent, unrecoverable), then the resource
az cognitiveservices account project delete -n "$RESOURCE" -g "$RG" --project-name "$PROJECT"
az cognitiveservices account delete -n "$RESOURCE" -g "$RG"

# 4. Purge the soft-deleted account (permanent: loses data and keys)
az cognitiveservices account list-deleted -o table
az cognitiveservices account purge -n "$RESOURCE" -g "$RG" -l "$LOCATION"

# 5. Or remove everything in one go if the group is dedicated to this work
az group delete --name "$RG" --yes --no-wait
az group exists --name "$RG"     # false when finished
```

Also remove: budgets (`az consumption budget delete --budget-name llm-budget`), action groups, runbooks and Logic Apps, role assignments you added (`az role assignment delete`), private endpoints and DNS zones, and key files (`shred` or delete `~/.config/azure-foundry.key`). Purge needs the Cognitive Services Contributor role; with plain Contributor the role must be assigned at the subscription level. The documented REST alternative is `DELETE .../providers/Microsoft.CognitiveServices/locations/{location}/resourceGroups/{rg}/deletedAccounts/{name}`. Flag names for `az ml online-deployment delete` and `az cognitiveservices account purge` follow the CLI reference; confirm with `--help` if a flag is rejected.

**Verify nothing still accrues:** `az cognitiveservices account list` and `list-deleted` show no leftover accounts; `az ml online-endpoint list` is empty; `az group exists` is false; Cost Management > Cost analysis filtered to the resource group shows no new cost the next day.

## Troubleshooting

| Symptom                                                                          | Cause                                                                                                     | Fix                                                                                                                  |
| -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 401 `Access denied due to invalid subscription key or wrong API endpoint`        | Wrong key or resource, key auth disabled, wrong region endpoint, or stale key after rotation              | Use KEY1/KEY2 from the same resource, correct endpoint; check `disableLocalAuth` and Azure Policy; allow propagation |
| 401 with Entra                                                                   | Expired or wrong-audience token, missing RBAC                                                             | Scope `https://ai.azure.com/.default`; assign Cognitive Services OpenAI User; `az login --tenant <id>`               |
| 403 mentioning network access, IP restriction or private endpoint                | Firewall, IP rule or DNS for private endpoint                                                             | Check Networking, DNS resolves to private IP, NSG rules                                                              |
| 404 `DeploymentNotFound` ("The API deployment for this resource does not exist") | Model name used instead of deployment name, wrong resource or endpoint, or deployment under 5 minutes old | `az cognitiveservices account deployment list`, use that name, wait and retry                                        |
| 429                                                                              | TPM or RPM limit, capacity throttling                                                                     | Honor `retry-after-ms`, backoff, lower `max_tokens`, request quota, spread across regions                            |
| `DeploymentModelNotSupported` on create                                          | Model, version or SKU unavailable in the region                                                           | `az cognitiveservices model list --location <region>`, pick a supported combination                                  |
| `CustomDomainInUse` on account create                                            | Custom domain name taken globally                                                                         | Pick another `--custom-domain`                                                                                       |
| Project creation fails: managed identity must be enabled                         | Resource created without identity                                                                         | Create with `--assign-identity --allow-project-management true`                                                      |
| Works locally, fails after deploy                                                | Managed identity not enabled or role assigned to your user only                                           | Enable identity on the host, assign role to it, set `AZURE_CLIENT_ID` for user-assigned                              |
| Deleted account still billing                                                    | Soft-deleted, provisioned deployments still count                                                         | `az cognitiveservices account list-deleted`, then purge                                                              |
| Disabled key auth but old key still works for a while                            | Gateway cache                                                                                             | Wait up to hours; confirm with a 401 test                                                                            |

Cross-provider habits: `cloud-llms`. Gateway retries and fallbacks: `llm-gateway`.

## Sources

- https://learn.microsoft.com/en-us/azure/foundry/how-to/create-projects
- https://learn.microsoft.com/en-us/azure/foundry/tutorials/quickstart-create-foundry-resources
- https://learn.microsoft.com/en-us/azure/ai-services/recover-purge-resources
- https://learn.microsoft.com/en-us/rest/api/aifoundry/accountmanagement/deployments/delete?view=rest-aifoundry-accountmanagement-2025-06-01
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/troubleshoot-errors
- https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-online-endpoints?view=azureml-api-2
