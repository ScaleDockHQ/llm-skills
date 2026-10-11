# Private access, residency and policy

> Verified against Microsoft Foundry docs (Understanding deployment types, Disable local authentication, Troubleshoot common HTTP errors), Azure OpenAI network configuration source article (MicrosoftDocs/azure-ai-docs `network.md`), Azure ML online endpoints YAML reference, 2026-10-11

## Private networking for a Foundry resource

1. Disable public network access: `az cognitiveservices account update -g "$RG" -n "$RESOURCE" --public-network-access Disabled` (portal: Networking > Allow access from > Disabled). Private endpoints become the only way in.
2. Create a private endpoint on the resource with target sub-resource `account` (`Microsoft.CognitiveServices/accounts`) in a subnet of your VNet.
3. Link private DNS zones to the VNet. The reference Bicep uses `privatelink.openai.azure.com`; Foundry resources also use `privatelink.cognitiveservices.azure.com` and `privatelink.services.ai.azure.com`. Check the Configure private link page for your resource type.
4. Run the gateway inside that VNet (or a peered one) so prompts never cross the public internet.

Verify from inside the network: `nslookup <resource>.openai.azure.com` should return the private IP, and `Test-NetConnection <ip> -Port 443` (or `nc -vz <ip> 443`) should succeed only from the private network. A 403 mentioning network access or private endpoint means a firewall, IP rule or DNS problem. IP and VNet rules: `az cognitiveservices account network-rule add|list|remove`.

For Azure ML online endpoints, set `public_network_access: disabled` so scoring goes through the workspace private endpoint.

## Residency

Data at rest stays in the resource's Azure geography. Inference processing:

- Global types: any Azure region.
- Data Zone types: only within the US, EU (the Azure EU Data Boundary, which can include EFTA countries) or APAC zone. Microsoft can add regions to a zone without notice.
- Standard and Regional Provisioned: within the chosen geography, possibly moving between regions inside it for operations.

For regulated data avoid Global types; use Data Zone or regional types and an Azure Policy that blocks others:

```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.CognitiveServices/accounts/deployments"
        },
        {
          "field": "Microsoft.CognitiveServices/accounts/deployments/sku.name",
          "equals": "GlobalStandard"
        }
      ]
    },
    "then": { "effect": "deny" }
  }
}
```

(The docs show the `if` condition and tell you to replace the SKU name; the `then` effect line is standard Azure Policy.) With Global Standard and Data Zone Standard, an outage of the primary region affects all traffic initially routed there; see the high availability guidance for failover design.

## Data handling and identity

- Data privacy for Azure OpenAI in Foundry: https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/openai/data-privacy (retention and abuse monitoring settings; read it for your contract).
- Prefer managed identities and Entra ID; enforce with the disable-local-auth policy (`setup-and-auth.md`).
- Content filters are applied per deployment (`raiPolicyName`, default `Microsoft.DefaultV2` in the docs' template).
- Keep Azure Activity Log on to record who changed deployments and keys.

Cross-provider checklist: `cloud-llms`. Logging and tracing hygiene: `llm-observability`.

## Sources

- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- https://github.com/MicrosoftDocs/azure-ai-docs/blob/main/articles/foundry-classic/openai/how-to/network.md
- https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth
- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/troubleshoot-errors
- https://learn.microsoft.com/en-us/azure/machine-learning/reference-yaml-endpoint-online?view=azureml-api-2
