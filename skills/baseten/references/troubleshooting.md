# Baseten troubleshooting

> Verified against docs.baseten.co inference/errors, troubleshooting/deployments, deployment/manage/lifecycle, development/model/secrets, 2026-10-11

## Inference status codes

| Status and message                              | Meaning and fix                                                                                |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 401 Unauthorized                                | Missing or wrong key. Check the header form and that the key is active                         |
| 403 Authentication failed                       | Key lacks permission for this model or environment. Use a key with invoke rights               |
| 402                                             | Billing problem on Model APIs. Check credits, payment method                                   |
| 400 "Model version ... is deactivated"          | Activate the deployment or call another one                                                    |
| 404 model or deployment not found               | Wrong ID, wrong environment, or deleted                                                        |
| 404 `The model 'x' does not exist` (vLLM)       | `model` does not match `--served-model-name`                                                   |
| 413                                             | Body too large. Edge cap is 100 MB, async has a lower default                                  |
| 429, including `CAPACITY_EXCEEDED`              | Rate or concurrency limit. Back off, raise max replicas or tier                                |
| 499                                             | Client closed the connection                                                                   |
| 500 "Internal Server Error (in model/chainlet)" | Exception in model code. Read deployment logs                                                  |
| 500 "Failed to route request"                   | No ready replica within the routing timeout (about 20 minutes). Check replicas and scale-up    |
| 502 "Error making prediction"                   | Often the replica ran out of memory (OOMKilled). Use a larger GPU or smaller batch and context |
| 503                                             | Replica unavailable or restarting                                                              |
| 504                                             | Sync timeout (1200 s). Use async for long jobs (up to 3600 s)                                  |
| 529                                             | Overloaded. Retry after `Retry-After`                                                          |

## Deploy problems

- **"[Errno 2] No such file or directory: '.../config.yaml'"** from Truss: run the command in the directory containing `config.yaml` or pass the path.
- **Weight mirroring auth errors** (`aws_access_key_id ...`, `secret_id is required`) or a 401 on a gated Hugging Face repo: add the `auth` block to the weight source and create the secret.
- **Build failed**: the dashboard offers a restart for transient build failures. Otherwise read the build logs and pin versions.
- **Max deployed models error** ("You've reached the maximum number of deployed models (2000) for your tier..."): delete old models.
- **Model never answers after deploy**: with min replicas 0 the first request waits for a cold start. Set `min_replica=1` while testing.
- **Cannot delete a deployment**: it is attached to an environment or is the model's only deployment. Delete the model instead.

## Cost surprises

- Idle warm replicas bill. Lower the scale-down delay or min replicas.
- Enforce budget covers Model APIs only, so check dedicated deployments in `baseten model list`.
- Image builds and cold starts bill.

## Where to look

```bash
baseten model deployment logs --help
baseten model environment logs --help
```

Docs: https://docs.baseten.co/troubleshooting/deployments and https://docs.baseten.co/inference/errors. Never paste API keys into support requests.
