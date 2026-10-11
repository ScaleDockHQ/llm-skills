# NVIDIA NIM serve configuration

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: environment variables, CLI reference and advanced configuration pages.

## CLI actions

`docker run <image> [ACTION] [OPTIONS...]`. With no action, `nim-serve` runs. Remaining arguments pass to
the backend.

| Action                | Purpose                                                           |
| --------------------- | ----------------------------------------------------------------- |
| `nim-serve`           | Start the server. `--dry-run` previews the resolved config.       |
| `nim-serve-ray`       | Ray-based multi-node serving. Needs `--head` or `--head-address`. |
| `list-model-profiles` | List profiles for the current hardware.                           |
| `download-to-cache`   | Download a profile (`-p <id>`) or all (`--all`) without serving.  |
| `download-model`      | Materialise a workspace (`--workspace-path`); used by Dynamo.     |
| `create-model-store`  | Copy a cached profile to a directory (`-p`, `-m`).                |
| `mirror`              | Copy cached profiles to S3 or GCS (`mirror s3 -b <bucket>`).      |
| `show-build-info`     | Print versions and build metadata.                                |

## Core variables

| Variable                     | Meaning                                                                |
| ---------------------------- | ---------------------------------------------------------------------- |
| `NIM_SERVER_PORT`            | External HTTP port.                                                    |
| `NIM_HEALTH_PORT`            | Port of `/v1/health/live` and `/v1/health/ready`.                      |
| `NIM_CACHE_PATH`             | Model and artifact cache. Default `/opt/nim/.cache`.                   |
| `NIM_CACHE_PROBE_TIMEOUT`    | Seconds to probe the cache at startup (default 60); fails on dead NFS. |
| `NIM_MODEL_PROFILE`          | Profile ID or description to force.                                    |
| `NIM_MODEL_PATH`             | Model source: `hf://`, `ngc://`, `modelscope://`, S3 or local path.    |
| `NIM_SERVED_MODEL_NAME`      | Name in `/v1/models` and responses.                                    |
| `NIM_MAX_MODEL_LEN`          | Context window override. Larger than trained maximum may error.        |
| `NIM_TENSOR_PARALLEL_SIZE`   | Tensor parallel degree override.                                       |
| `NIM_PIPELINE_PARALLEL_SIZE` | Pipeline parallel degree override.                                     |
| `NIM_NUM_COMPUTE_NODES`      | Number of nodes for multi-node.                                        |
| `NIM_REPOSITORY_OVERRIDE`    | Alternative model repository location.                                 |
| `NIM_DISABLE_MODEL_DOWNLOAD` | Do not download models.                                                |
| `NIM_TRUST_CUSTOM_CODE`      | Allow model repo custom code (a trust decision; leave off by default). |
| `NIM_PEFT_SOURCE`            | LoRA adapter directory.                                                |
| `NIM_PEFT_REFRESH_INTERVAL`  | Seconds between adapter scans; setting it enables dynamic LoRA.        |
| `NIM_LOG_LEVEL`              | `DEBUG` to `CRITICAL`; default `WARNING`.                              |
| `NIM_JSONL_LOGGING`          | JSON Lines logs; default false.                                        |
| `NIM_DISABLE_CUDA_GRAPH`     | Turn CUDA graphs off (diagnostics, memory).                            |
| `NIM_WRITABLE_ROOT`          | Writable root, default `/opt/nim`.                                     |
| `NIM_PASSTHROUGH_ARGS`       | Backend args when container args are unavailable.                      |
| `NIM_STRICT_ARG_PROCESSING`  | Exit if a custom arg conflicts with an image passthrough value.        |

Speculative decoding: `NIM_SPECDEC_ENABLE`, `NIM_SPECDEC_ARGS`, `NIM_DRAFT_MODEL_PATH`. Payload capture:
`NIM_CAPTURE_ENABLE`, `NIM_CAPTURE_ARGS` (captures request content; treat output as sensitive).

Authentication variables: `NGC_API_KEY` (and `NGC_CLI_API_KEY`, which wins if both are set), `HF_TOKEN`,
`MODELSCOPE_API_TOKEN`. Pass each with `-e NAME` so the value is not written on the command line.

## TLS and CORS

`NIM_SSL_MODE`, `NIM_SSL_KEY_PATH`, `NIM_SSL_CERTS_PATH`, `NIM_SSL_CA_CERTS_PATH` configure server TLS;
`REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE` set trusted CAs for downloads. CORS is `NIM_CORS_ALLOW_ORIGINS`,
`..._METHODS`, `..._HEADERS`, `..._EXPOSE_HEADERS` and `..._MAX_AGE`. Read the environment-variables page
for accepted `NIM_SSL_MODE` values before setting it.

## Backend arguments

Anything after `nim-serve` goes to vLLM, for example
`nim-serve --max-model-len 4096 --enable-prefix-caching`. Arguments must match the vLLM version in the
image. Preview with `--dry-run`. On Kubernetes use the container `args` field or Helm `customArgs`.
`--middleware <import.path>` installs a custom ASGI middleware; it is unsupported in the Dynamo
deployment variants and do not replace FastAPI's middleware list with `VLLM_PLUGINS`.
`NIM_SAGEMAKER_MODE` adapts the container to SageMaker conventions.

## Dry run

```bash
docker run --rm --gpus all -e NGC_API_KEY <image> nim-serve --dry-run
```
