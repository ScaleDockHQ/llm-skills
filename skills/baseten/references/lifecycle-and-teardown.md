# Baseten lifecycle, scaling, cost and teardown

> Verified against docs.baseten.co deployment/manage/{overview,lifecycle,scaling}, deployment/autoscaling/overview, organization/billing, troubleshooting/deployments, 2026-10-11

## Inspect

```bash
baseten model list
baseten model deployment list --model-id <id>
baseten model deployment describe --model-id <id> --deployment-id <dep>
baseten model environment describe --model-id <id> --environment production
```

Command shapes come from the CLI docs. Run `baseten model --help` to confirm flags in your installed version.

## Autoscaling

Defaults per the autoscaling overview: min replicas 0, max replicas 1, autoscaling window 60 s, scale-down delay 900 s, max scale-down rate 50%, concurrency target 1, target utilization 70%. Starting concurrency targets suggested for LLM engines are in the autoscaling page (a range for vLLM, a lower figure for SGLang). Tune from a load test.

```bash
baseten model deployment update-autoscaling --model-id <id> --deployment-id <dep> --min-replica 1 --max-replica 3
```

The update is asynchronous, so re-describe to confirm. REST: `PATCH .../autoscaling_settings`.

- **Scale to zero** (min 0): no GPU charge while idle, but a request wakes it, pays a cold start and waits. Cold starts are billed.
- While testing a new model, set `min_replica=1`, since it otherwise scales to zero before the first request.
- Set a max replica ceiling so a traffic spike cannot run the bill up.

## Promote and update

1. Push a new deployment.
2. Verify it (smoke test, evals).
3. `baseten model deployment promote --yes --environment production ...`.
4. Keep the previous deployment until traffic is clean, then deactivate it.

## Billing

- Per minute while a workload runs. Billed: image build, cold start, idle warm replicas. Not billed: failed boot, scaled to zero, image pull.
- Look up rates: instance type page https://docs.baseten.co/deployment/resources and the Model APIs pricing page.
- New workspaces get credits. If credits run out with no payment method, models are deactivated. Invoices are issued when usage passes a threshold or at month end.

```bash
baseten org billing usage                       # defaults to the last 7 days
baseten org billing usage --jq '.model_apis_usage.total'
```

## Budget controls

- Dashboard monthly budget: emails at 75/90/100%.
- Enforce budget: stops Model API requests only. Dedicated deployments and training keep running and billing. Cap them with max replicas and teardown.

## Deactivate, activate, delete

```bash
baseten model deployment deactivate --model-id <id> --deployment-id <dep>
baseten model deployment activate   --model-id <id> --deployment-id <dep>
baseten model deployment delete     --model-id <id> --deployment-id <dep>
baseten model delete --model-id <id>
```

REST equivalents: `POST .../deployments/{id}/deactivate`, `POST .../activate`, `DELETE .../deployments/{id}`.

- A deactivated deployment has no compute spend. Requests fail with HTTP 400 "Model version {id} is deactivated. It needs to be activated before running predictions".
- A deployment attached to an environment, or the model's only deployment, cannot be deleted. Delete the model, which removes all its deployments.
- Replicas can be terminated individually with `baseten model deployment replica` (see `--help`).

## Tear down checklist

- [ ] List models and deployments you created. Get approval for the exact IDs.
- [ ] Remove the model from LiteLLM and from client configs.
- [ ] Deactivate (reversible) or delete (final). Delete the model if the deployment is protected.
- [ ] Revoke inference keys created only for this job: `baseten org api-key delete --prefix <prefix>`.
- [ ] Delete unused secrets.
- [ ] Verify: `baseten model list` shows nothing unintended, and `baseten org billing usage` stops growing the next day.
- [ ] Training jobs, chains and sandboxes are separate resources. This skill does not cover them, so check the dashboard.
