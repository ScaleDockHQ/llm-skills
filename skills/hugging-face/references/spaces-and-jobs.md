# Hugging Face Spaces and Jobs (brief)

> Verified against huggingface_hub CLI guide (hf spaces, hf jobs, hf sandbox sections), 2026-10-11

Only the lifecycle and cost commands are covered here. For app design see the Spaces docs; for training see `fine-tuning-llms`.

## Spaces

```bash
hf spaces ls --search "gradio"
hf spaces info <owner/space>
hf spaces hardware                        # hardware options with pricing (read live)
hf spaces pause <owner/space>             # paused time is not billed
hf spaces restart <owner/space> [--factory-reboot]
hf spaces wait <owner/space> --timeout 5m # exit 0 only when RUNNING
hf repos create my-space --repo-type space --sdk gradio
```

- Pausing or restarting tears down the container; the ephemeral filesystem is lost. Persist data in a mounted volume or bucket (`hf spaces volume`, `hf buckets`).
- Upgraded hardware bills per minute while running. Pause or downgrade when idle. Set sleep time in the Space settings where available (unverified here: check the Space settings page).
- Do not put secrets in a public Space; use Space secrets.

## Jobs

Docker-like compute on HF infrastructure (CPU, GPU, TPU), available to users and orgs with pre-paid credits.

```bash
hf jobs run --flavor cpu-basic python:3.12 python -c 'print("hi")'
hf jobs run --flavor a10g-small pytorch/pytorch:<pinned-tag> python train.py
JOB_ID=$(hf jobs run -dq --flavor a10g-small <image> python train.py)   # detached, prints the id only
hf jobs logs "$JOB_ID"
hf jobs inspect "$JOB_ID"
hf jobs stats -f "$JOB_ID"
hf jobs wait "$JOB_ID"                    # non-zero exit if the job failed
hf jobs cancel "$JOB_ID"
hf jobs ls          # running;  hf jobs ls -a  for all
hf jobs run --attempts 3 ...              # retries, including the first run
hf jobs run --namespace my-org ...        # run under an org
hf jobs uv run my_script.py               # experimental
```

- Pass secrets with the job secrets option rather than inline arguments; check `hf jobs run --help` for the current flag and never echo them.
- Flavors (`cpu-basic`, `a10g-small`, ...) and prices: see the Hardware section of the CLI guide and the Jobs docs; do not copy prices.
- Use `--` to separate Jobs options from the command's own options.
- Always cancel on failure paths and when abandoning work; a stuck job keeps billing until it ends or times out (unverified default timeout: check `hf jobs run --help`).

## Sandboxes (experimental)

`hf sandbox create|exec|cp|kill` run on Jobs. Use `--idle-timeout` and `hf sandbox kill` to bound cost. The API may change without notice.

## Official links

- CLI guide: https://huggingface.co/docs/huggingface_hub/guides/cli
- Jobs overview: https://huggingface.co/docs/hub/jobs
