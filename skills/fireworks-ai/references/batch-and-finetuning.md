# Fireworks AI batch and fine-tuning

> Verified against Fireworks docs: Batch API guide, Supervised Fine-Tuning (Text), Deploying Trained Models, Account quotas (training GPU quota), firectl dataset, batch-inference-job and supervised-fine-tuning-job command pages, 2026-10-11

## Batch API

Async processing at a discount to serverless per-token prices (the docs say 50% off, with additional savings on cached tokens). Prices: https://docs.fireworks.ai/serverless/pricing.

- Models: base models that support on-demand deployments, and custom models built on a batch-compatible base. If a model does not support batch, the job may sit in a pending state without an immediate error. Verify first.
- Dataset: JSONL, up to 80 GiB, each line `{"custom_id": "...", "body": {...}}` with unique `custom_id`. Use `body.messages` or `body.prompt_token_ids` (mutually exclusive). Set `user` or `prompt_cache_key` in the body to keep cache hit rates up.

```bash
firectl dataset create batch-input-dataset ./batch_input_data.jsonl
firectl batch-inference-job create \
  --job-id my-batch-job \
  --model accounts/fireworks/models/<MODEL> \
  --input-dataset-id batch-input-dataset \
  --output-dataset-id batch-output-dataset \
  --max-tokens 1024
firectl batch-inference-job get my-batch-job
firectl batch-inference-job list
firectl dataset download batch-output-dataset     # results file and error file
```

REST: `POST https://api.fireworks.ai/v1/accounts/$ACCOUNT_ID/batchInferenceJobs?batchInferenceJobId=<id>` with `model`, `inputDatasetId`, `outputDatasetId`, `inferenceParameters`. Use `--system-prompt` to set one system message for rows that lack one (keeps the prefix cache-friendly).

If the job is not running: check JSONL validity, remember jobs wait in "pending" during the selected window, and contact support if it has been "creating" a deployment over 30 minutes. A batch job stores customer content; a Zero Data Retention policy disables it (enterprise).

## Supervised fine-tuning (SFT)

Requires a payment method for training GPU quota. Size the run first with https://docs.fireworks.ai/fine-tuning/cost-estimator.

```bash
firectl dataset create my-dataset ./train.jsonl
firectl supervised-fine-tuning-job create \
  --base-model <MODEL_ID> --dataset my-dataset --output-model my-tuned-model \
  --epochs 3 --learning-rate 0.0001 --lora-rank 16
firectl sftj get <JOB_ID>
firectl model list
```

`firectl sftj` is the documented alias. Use `--full-parameter` for full tuning instead of LoRA, `--warm-start-from <MODEL>` to continue from a tuned model, `--evaluation-dataset` for validation. Training data is OpenAI chat JSONL (see `serverless-api.md`). A job rejected with HTTP 403 `quota_exceeded` or `tier_required` needs a payment method or freed GPUs of that type.

Deploy the output as in `deployments.md` (`firectl deployment create <FINE_TUNED_MODEL_ID> --deployment-shape default`, or load as a LoRA on an addons-enabled deployment).

Other training products (DPO or ORPO, reinforcement fine-tuning, the Training API with dedicated trainers) exist: https://docs.fireworks.ai/fine-tuning/finetuning-intro. Trainers and weight-sync deployments hold GPUs until cleaned up; read https://docs.fireworks.ai/fine-tuning/training-api/reference/cleanup. RLOR trainer jobs auto-stop after 10 minutes with no tracked activity.

## Cancel and delete

```bash
firectl supervised-fine-tuning-job cancel <JOB_ID>
firectl supervised-fine-tuning-job delete <JOB_ID> --wait
firectl batch-inference-job delete <JOB_ID> --wait
firectl dataset delete <DATASET_ID> --wait
firectl model delete <MODEL_ID>
```

Full teardown order: `teardown.md`.

## Sources

- https://docs.fireworks.ai/guides/batch-inference
- https://docs.fireworks.ai/fine-tuning/fine-tuning-models
- https://docs.fireworks.ai/fine-tuning/deploying-loras
- https://docs.fireworks.ai/tools-sdks/firectl/commands/supervised-fine-tuning-job-create
- https://docs.fireworks.ai/guides/quotas_usage/account-quotas
