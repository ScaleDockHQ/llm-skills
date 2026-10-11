# Together AI batch and fine-tuning

> Verified against Together docs: Batch overview, Run a batch job, Manage batch jobs, Files CLI, Fine-tuning quickstart, Monitor a fine-tuning job, Deploy a fine-tuned model; `tg` CLI, 2026-10-11

## Batch API

- Runs independent requests asynchronously from one JSONL file, in a rate-limit pool separate from real-time traffic. Selected serverless models get a batch discount (the docs say up to 50%); the list is on the batch overview page. The discount does not apply to dedicated model inference.
- Documented limits: up to 50,000 requests per batch, 100 MB per input file, 10 MB per line (inline base64 counts), and an enqueued-token ceiling per model. Re-check on https://docs.together.ai/docs/inference/batch/overview.
- Completion window: 24 hours maximum; small batches usually finish in minutes.
- Input file, output file and error file are retained for 7 days. Download before then.
- Billing: successful responses in the output file are billed; failed requests in the error file are not. Cancelling does not refund responses already generated.

Input line: `{"custom_id": "request-1", "body": {"model": "MODEL_ID", "messages": [...], "max_tokens": 200}}`. `custom_id` is unique, up to 64 characters. Audio endpoints add `"method": "FILE"`.

```bash
tg batches submit batch_input.jsonl --api chat.completions   # uploads and creates
tg batches get <BATCH_ID>                                     # poll every 30-60 s
tg batches download <BATCH_ID> --output batch_output.jsonl    # also saves the error file
tg batches cancel <BATCH_ID>                                  # VALIDATING or IN_PROGRESS only
tg batches list
```

Statuses: `VALIDATING`, `IN_PROGRESS`, then `COMPLETED`, `FAILED`, `EXPIRED` or `CANCELLED`. Always read the error file: a `COMPLETED` batch can still contain failed lines (match on `custom_id`; results are unordered). Lines over 10 MB fail with `error reading input file`. Audio lines without `"method": "FILE"` fail with `Content-Type must be multipart/form-data`.

SDK: `client.batches.create(input_file_id=..., endpoint="/v1/chat/completions")` returns a wrapper; the batch is `.job`. `client.batches.retrieve(id)` returns the batch directly.

## Files API

```bash
tg files upload data.jsonl --purpose batch-api --no-check   # --no-check skips the local check
tg files list
tg files retrieve <FILE_ID>
tg files retrieve-content <FILE_ID> --output ./
tg files delete <FILE_ID>
```

Uploading a file whose contents already exist returns the existing file's metadata; delete the old file first to force a re-upload. For fine-tuning, the SDK upload uses `purpose="fine-tune"`; check `tg files upload --help` for the CLI purpose flag.

## Fine-tuning lifecycle

1. Prepare data (conversational, instruction, preference or generic text, JSONL by default). See https://docs.together.ai/docs/fine-tuning/data-preparation.
2. Upload and wait for `processing_status == COMPLETED` (other values: `INVALID_FORMAT` with `validation_report.error`, `FAILED`).
3. Estimate cost, then create the job (needs approval; each `create` call starts a new billed job, so run `tg fine-tuning list` before retrying):

```bash
tg fine-tuning create --training-file "$FILE_ID" --model "BASE_MODEL" \
  --lora --n-epochs 3 --n-checkpoints 1 --learning-rate 1e-5 --suffix my-ft
tg fine-tuning retrieve <JOB_ID>
tg fine-tuning list-events <JOB_ID>
```

States: `pending`, `queued`, `running`, `uploading`, `completed`, with `error` and `cancelled` as other terminal states. LoRA is the default; set `lora false` for full fine-tuning. Check the supported-models page for bases and limits (`tg fine-tuning` has a model-limits command).

4. When `completed`, read `model_object_id` (`ml_...`) and `model_object_name` (`<project_slug>/<model_name>`). Deploy on a dedicated endpoint:

```bash
tg beta endpoints deploy "<MODEL_OBJECT_NAME>" --endpoint my-ft --inactive-timeout 60
```

The SDK needs `projects/{project_id}/models/<MODEL_OBJECT_ID>` and a config resource name. Call the result at `https://api-inference.together.ai/v1` with the endpoint string as `model`, not the Model Object ID.

5. Many fine-tunable bases are not serverless (`Unable to access non-serverless model`). To compare against the base, deploy the base on its own endpoint and delete it afterwards.

Other operations: `tg fine-tuning cancel <JOB_ID>` (billed for completed steps only), `tg fine-tuning delete <JOB_ID>` (removes the job and its files), `tg fine-tuning list-checkpoints <JOB_ID>`, `tg fine-tuning download <JOB_ID>` (checkpoint types `merged`, `adapter`, `model_output_path`), `--from-checkpoint` to continue training.

## Sources

- https://docs.together.ai/docs/inference/batch/overview
- https://docs.together.ai/docs/inference/batch/tutorial
- https://docs.together.ai/docs/inference/batch/manage
- https://docs.together.ai/reference/cli/files
- https://docs.together.ai/docs/fine-tuning/quickstart
- https://docs.together.ai/docs/fine-tuning/monitoring
- https://docs.together.ai/docs/fine-tuning/deployment
