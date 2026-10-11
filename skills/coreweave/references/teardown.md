# CoreWeave: teardown

> Verified against CoreWeave docs: Getting started with Dedicated Inference (Clean up), Delete a CKS cluster and Cluster API delete, Manage Node Pools (delete), Spot Node Pools, Scaling (capacity claims), 2026-10-11

Order matters. Ask the user before each step.

## Dedicated Inference

Delete deployments first, then the gateway. Delete capacity claims too, since managed claims bill while they exist.

```bash
cwic inference deployment list
cwic inference deployment delete "$CW_DEPLOYMENT_ID"
cwic inference gateway delete "$CW_GATEWAY_ID"
# REST: DELETE ${CW_BASE_URL}/v1alpha1/inference/deployments/{id}  then  .../gateways/{id}
# Terraform-managed: terraform destroy
```

Capacity claims: delete via the Terraform resource (`terraform destroy`) or the Dedicated Inference API reference (`CapacityClaim` delete). Then remove model weights from AI Object Storage if no longer needed (storage bills separately) and revoke any client tokens you issued.

## CKS

1. Remove workloads and any `LoadBalancer` Services you created (public IPs).
2. Delete Node Pools. CKS removes the nodes without waiting for workloads, so confirm nothing important is running.

```bash
kubectl delete svc,deploy --all -n <your-namespace>     # only your own namespace
kubectl delete nodepool <name>
kubectl get nodepool                                   # expect none
```

3. Delete the cluster. The cluster must be `Healthy` to delete. Console: Clusters, the cluster's menu, enter the cluster name to confirm. REST: `DELETE https://api.coreweave.com/v1beta1/cks/clusters/{id}` with a bearer token. Terraform: `terraform destroy`.
4. Delete the kubeconfig file and the API access token if it was created for this job (Cloud Console, Tokens).

## SUNK

Delete the SUNK cluster resource (`SunkCluster` for Self-Service, or the Helm releases for Standard) before the Node Pools that host it. Follow the SUNK docs for your version.

## Serverless Inference

Nothing runs between requests. Revoke the Forge API key at `forge.coreweave.com/settings`, and delete LoRA adapters you stored (storage can bill separately).

## Verify nothing accrues

```bash
cwic inference gateway list
cwic inference deployment list
kubectl get nodepool 2>/dev/null
```

Then check the Billing insights page the next day and remove the matching entries from your LiteLLM config.

## Sources

- https://docs.coreweave.com/products/inference/getting-started
- https://docs.coreweave.com/products/cks/clusters/delete
- https://docs.coreweave.com/products/cks/nodes/manage
