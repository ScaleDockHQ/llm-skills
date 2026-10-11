# fal serverless: apps, deploy, scale

> Verified against fal.ai/docs serverless/index, development/getting-started/installation, deployment/{deploy-to-production,scale-your-application,manage-deployments,machine-types}, 2026-10-11

Serverless access is approved per account (https://fal.ai/dashboard/serverless-get-started). Every hosted model on fal is itself a `fal.App`.

## Three ways to ship

1. **Native `fal.App`:** a Python class plus pip `requirements`. fal builds the container.
2. **Custom container:** `image = ContainerImage.from_dockerfile_str(...)` or a registry image.
3. **Direct Server Mode:** an existing HTTP server on `exposed_port`, configured in `pyproject.toml` under `[tool.fal.apps.<name>]` with `auth`, `machine_type`, `exposed_port` and an image Dockerfile.

## Minimal app

```python
import fal
from pydantic import BaseModel

class Input(BaseModel):
    prompt: str

class Output(BaseModel):
    result: str

class MyModel(fal.App):
    machine_type = "GPU-H100"          # pick from the machine-types page
    requirements = ["torch", "transformers"]   # pin versions in real use

    def setup(self):
        from transformers import pipeline
        self.pipe = pipeline("text-generation", model="gpt2", device="cuda")

    @fal.endpoint("/")
    def generate(self, input: Input) -> Output:
        return Output(result=self.pipe(input.prompt, max_new_tokens=16)[0]["generated_text"])
```

The endpoint input must be a Pydantic model. A bare scalar parameter fails with HTTP 422.

## App attributes

`machine_type` (string or list), `num_gpus`, `regions`, `requirements`, `image`, `min_concurrency` (default 0), `max_concurrency`, `keep_alive` (default 60 s), `scaling_delay`, `max_multiplexing`, `startup_timeout`, `termination_grace_period_seconds` (default 5, max 3600). See https://fal.ai/docs/documentation/deployment/scale-your-application for the full reference and current defaults. Machine types and their prices: https://fal.ai/docs/documentation/deployment/machine-types and the dashboard. Never copy prices.

## CLI

```bash
fal run app.py::MyModel                         # temporary run, public auth, for testing
fal deploy app.py::MyModel --app-name my-app --auth private --strategy rolling --check
fal apps list
fal apps list-rev my-app
fal apps set-rev my-app <revision>              # roll back or forward
fal apps scale my-app --min-concurrency 0 --max-concurrency 4 --keep-alive 60
fal apps runners my-app                         # see live runners and their states
fal apps delete my-app
fal apps delete-rev my-app --revision-id <id>
```

`fal deploy` options include `--app-name`, `--env`, `--auth private|public|shared` (default private), `--strategy rolling|recreate`, `--check`, `--yes`, `--message`, `--annotation k=v` and `--reset-scale`. Builds happen remotely. Run `fal deploy --help` to confirm for your version.

Scale settings are inherited across deploys unless you pass `--reset-scale`. Always re-check with `fal apps list` after a deploy.

## Calling your app

Deployed apps are served at fal's queue and sync hosts under your namespace and app name, the same shape as hosted models (`references/model-apis.md`). With `auth=private` callers need a key allowed for the app.

## Cost-relevant settings

- `min_concurrency: 0` scales to zero. A value of 1 or more keeps a runner warm and billed.
- `keep_alive` keeps an idle runner for that many seconds, and the idle time is billed. Shorter means cheaper and slower for the next request.
- `max_concurrency` is your ceiling.
- Multi-GPU machines bill GPU count times seconds.

## Update

1. `fal deploy ... --strategy rolling` for zero-downtime (use `recreate` when only one runner fits).
2. Smoke test with a request.
3. If it is bad, `fal apps set-rev my-app <previous>`.
4. Delete old revisions you no longer need.

## Verify

- [ ] `fal apps list` shows the app with the scale you intended.
- [ ] A request through the queue returns a result.
- [ ] `fal apps runners` shows no unexpected runners after the test.
