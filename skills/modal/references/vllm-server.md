# Your own vLLM Server

> Verified against Modal docs (Run OpenAI-compatible LLM inference with Gemma and vLLM example, Servers guide, Web Functions guide, App guide, CLI reference for `modal deploy|run|serve|app|server`), modal 1.6.1, vllm 0.21.0 as pinned in Modal's example, 2026-10-11

Use this path when a Modal Endpoint does not give you the engine flags, parser, auth or code you need. Modal's example uses `@app.server`, the primitive underneath Endpoints. Always re-read the current example at <https://modal.com/docs/examples/vllm_inference> before writing code: its model, vLLM version and flags change.

## Shape of the App

Trimmed from Modal's example. Keep the pins, the two cache Volumes and the `@modal.enter()` start-up.

```python
import json
import subprocess

import modal

vllm_image = (
    modal.Image.from_registry("nvidia/cuda:12.9.0-devel-ubuntu22.04", add_python="3.12")
    .entrypoint([])
    .uv_pip_install("vllm==0.21.0")  # pin: copy the version from the current example
    .env({"HF_XET_HIGH_PERFORMANCE": "1"})
)

MODEL_NAME = "<org>/<model>"
MODEL_REVISION = "<full commit hash>"  # pin the Hugging Face revision

hf_cache_vol = modal.Volume.from_name("huggingface-cache", create_if_missing=True)
vllm_cache_vol = modal.Volume.from_name("vllm-cache", create_if_missing=True)

app = modal.App("my-vllm")
PORT = 8000

@app.server(
    image=vllm_image,
    gpu="H200:1",                     # see scaling-and-volumes.md for GPU choice
    port=PORT,
    scaledown_window=10 * 60,
    startup_timeout=10 * 60,
    volumes={
        "/root/.cache/huggingface": hf_cache_vol,
        "/root/.cache/vllm": vllm_cache_vol,
    },
    routing_region="us-east",
    target_concurrency=32,            # tune; soft limit
    # unauthenticated stays False: requests need a proxy token
)
class Server:
    @modal.enter()
    def start(self):
        cmd = [
            "vllm", "serve", MODEL_NAME,
            "--revision", MODEL_REVISION,
            "--served-model-name", "llm",
            "--host", "0.0.0.0",
            "--port", str(PORT),
            "--tensor-parallel-size", "1",
        ]
        self.process = subprocess.Popen(cmd)

    @modal.exit()
    def stop(self):
        self.process.terminate()
```

Model-specific flags (`--reasoning-parser`, `--tool-call-parser`, `--enable-auto-tool-choice`, speculative config) belong to the `vllm` and `tool-calling-parsers` skills and the model's vLLM recipe.

For gated models, mount a Secret with `secrets=[modal.Secret.from_name("huggingface-secret")]` and create it from your own shell with `modal secret create`, reading the value from an env var rather than typing it into a logged command.

### Notes from the example

- The server runs in a `subprocess.Popen` child and the container counts as ready only once the port listens.
- `FAST_BOOT = True` adds `--enforce-eager` (skips Torch compilation and CUDA graph capture) for faster cold boots at lower throughput. Use it when scaling from zero often or while iterating. Use `False` when replicas stay up. GPU memory snapshots are the alternative for cold starts (`scaling-and-volumes.md`).
- The cached vLLM compile artifacts in `/root/.cache/vllm` cut start-up to roughly ten seconds when warm, per the example.
- Set `HF_XET_HIGH_PERFORMANCE=1` for faster weight transfers, as the example does.

## Test, deploy, call

```bash
modal run app.py            # runs the local_entrypoint against a throwaway ephemeral App; stops when the command exits
modal serve app.py          # live-reloading dev deployment while the command runs; stops on Ctrl-C
modal deploy app.py         # persistent deployment: ASK FIRST, it bills while containers run
modal server info my-vllm/Server
modal server logs my-vllm/Server -f
```

`Server.get_url()` returns the URL. A request with no active container gets **503**: write the client to retry. Modal's example polls `/health` until 200.

```bash
# Token IDs/secrets come from env vars or a 0600 env file; do not echo them.
until curl -fsS "$SERVER_URL/health" -H "Authorization: Bearer $MODAL_PROXY_TOKEN_ID.$MODAL_PROXY_TOKEN_SECRET" >/dev/null; do sleep 5; done
curl -sS "$SERVER_URL/v1/models" -H "Authorization: Bearer $MODAL_PROXY_TOKEN_ID.$MODAL_PROXY_TOKEN_SECRET" | jq -r '.data[].id'
```

Modal Servers have no built-in retries, no queue, and no customisable request timeout: set them in the client or in vLLM.

## Update and roll back

```bash
modal deploy app.py                      # new version replaces the old
modal app history my-vllm                # versions
modal app rollback my-vllm [vN] --strategy rolling
modal app rollover my-vllm --strategy rolling   # fresh containers, same code (e.g. to re-pull weights)
```

A redeploy resets any `update_autoscaler` changes.

## Web Functions (alternative for plain HTTP)

Web Functions turn a Function into an HTTP endpoint: `@modal.fastapi_endpoint`, `@modal.asgi_app`, `@modal.wsgi_app` and `@modal.web_server(port)`. Unlike Servers they are **public by default**: set `requires_proxy_auth=True` to require a proxy token. Functions queue inputs and handle one input at a time unless you enable input concurrency, so they suit short, bursty handlers better than long streaming LLM sessions. A Server is the better fit for an engine that already speaks HTTP.

## Apps: ephemeral vs deployed

`modal run` and `modal serve` create ephemeral Apps that stop when the client disconnects. `modal deploy` creates a persistent App named after the `modal.App(name)`, and it stays until `modal app stop`. See `teardown.md`.
