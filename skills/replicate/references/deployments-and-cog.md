# Replicate deployments and Cog

> Verified against replicate.com/docs topics/deployments (create-a-deployment, delete-a-deployment, monitor-a-deployment), topics/models/hardware, guides/build/push-a-model, get-started/deploy-a-custom-model, reference/http, 2026-10-11

A deployment is a dedicated, configurable copy of a model on hardware you choose, with min and max instances. Without one, a public model runs on shared capacity.

## Pick hardware

```bash
curl -sS https://api.replicate.com/v1/hardware -H "Authorization: Bearer $REPLICATE_API_TOKEN" | jq .
```

Use a SKU returned there (for example `cpu` or one of the `gpu-...` names). Prices are on the hardware page. Do not store them.

## Create a deployment (ask first)

Show the model, version, hardware and instance bounds, then wait for approval.

```bash
curl -sS -X POST https://api.replicate.com/v1/deployments \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"my-llm","model":"<owner>/<model>","version":"<64-char version id>","hardware":"<sku from /hardware>","min_instances":0,"max_instances":2}' | jq .
```

- `min_instances: 0` scales to zero. Requests then wait for a cold boot. A value of 1 or more keeps instances warm, and idle time is billed.
- Always set a `max_instances` ceiling.
- Deployments bill setup, idle and active time. Public models bill active time only.

## Run and update

- Call `POST /v1/deployments/{owner}/{name}/predictions` (see `references/predictions-api.md`).
- Change hardware, bounds or version: `PATCH /v1/deployments/{owner}/{name}` with the fields to change.
- `GET /v1/deployments` lists them, and `GET /v1/deployments/{owner}/{name}` shows one.
- Metrics (latency, throughput, errors, instance states, queue depth, GPU memory) are on the deployment page for the last 24 hours at 15-minute resolution. Setup-failure alerts and custom setup timeouts need an enterprise contract.

## Delete a deployment

`DELETE /v1/deployments/{owner}/{name}` returns 204. The deployment must be offline and unused for at least 15 minutes, so set `min_instances` to 0 first and wait. The topic page writes the path as `{deployment_id}` while the API reference uses `{owner}/{name}`, and the reference form is the one to use. The Python and Node clients cannot delete deployments, so use HTTP.

## Push your own model with Cog

```bash
cog init                          # creates cog.yaml and predict.py
# cog.yaml: build.python_version, build.python_packages, build.gpu: true, predict: "predict.py:Predictor"
# predict.py: class Predictor(BasePredictor) with setup() (load weights) and predict(...)
cog predict -i prompt="hello"      # test locally, files with -i image=@file.png
cog login
cog push r8.im/<your-username>/<model-name>
```

- Create the model on replicate.com first, choose visibility (private models bill setup and idle time too) and hardware.
- Pin versions in `python_packages`, and keep weights out of the image if you can, or pin their source.
- A push creates a new immutable version. Pass its ID in predictions and deployments.
- Hardware for a public or private model is changed in the web settings, not through the API.

## Delete models and versions

`DELETE /v1/models/{owner}/{name}` works only for a private model you own that has no versions. Delete the versions first via the API (`models.versions.delete`, `DELETE /v1/models/{owner}/{name}/versions/{version_id}`). See `references/billing-and-teardown.md` for the sequence.

## Verify

- [ ] A test prediction against the deployment succeeds.
- [ ] `GET /v1/deployments/{owner}/{name}` shows the bounds you set.
- [ ] The model page shows the right visibility.
