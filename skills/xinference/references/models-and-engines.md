# Xinference models and engines

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

## Engines (LLM)

Choose with `xinference engine -n <model>`; the launch needs `--model-engine` (`-en`).

| Engine         | Use when                                     | Notes                                                                                                                                                          |
| -------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vllm`         | Linux with CUDA, best throughput             | Formats `pytorch` (quant none), `gptq` (Int3/4/8), `awq` (Int4), `fp4`, `fp8`, `bnb`; only for model families on its supported list (`xinference vllm-models`) |
| `sglang`       | Linux with CUDA, RadixAttention prefix reuse | Select explicitly at launch; also supports distributed runs                                                                                                    |
| `llama.cpp`    | GGUF, limited memory, CPU, Metal             | Runs through `xllamacpp`; GPU wheel picked per CUDA line (cu128 for CUDA 12.8+, cu132 for CUDA 13.x)                                                           |
| `transformers` | Anything else; default for PyTorch format    | `pytorch`, `gptq`, `awq`, `bnb`, `fp4`; continuous batching is on by default for LLMs                                                                          |
| `MLX`          | Apple Silicon                                | Best on Mac when the model supports it                                                                                                                         |

Upstream guidance: Linux, prefer vLLM or SGLang, llama.cpp when resources are limited, Transformers for
coverage. Windows, prefer WSL (then as Linux) else llama.cpp then Transformers. Mac, MLX if supported, else
llama.cpp, else Transformers. Built-in model names and sizes change each release: list them with
`xinference registrations -t LLM` rather than from memory.

Model type and format flags: `-s 0_5` is 0.5B (underscore for the decimal), `-f pytorch|ggufv2|gptq|awq|mlx|fp8...`,
`-q none|Int4|Q4_K_M...` depending on the format.

## Other model types

Launch with `--model-type` (or `model_type=`): `embedding`, `rerank`, `image`, `audio` (speech to text, text to
speech, music), `video`. List with `xinference registrations -t <type>`. Releases v3.4 and v3.5 added
multimodal embedding and rerank abilities and many OCR, TTS, image and video models; check the registrations on
your version.

## Cache and downloads

- Weights are cached under `XINFERENCE_HOME`; the cache stores symlinks into the Hugging Face or ModelScope caches.
- `POST /v1/cache/models` (or **Download only** in the Web UI) downloads without launching; progress at
  `GET /v1/cache/models/<cache_uid>/progress`, cancel at `.../cancel`; pause and resume at
  `/v1/downloads/<id>/pause|resume`; list at `GET /v1/downloads`.
- `xinference cached` lists, `xinference remove-cache --check` deletes (needs `cache:delete` permission).
- Source: `XINFERENCE_MODEL_SRC`; gated Hugging Face models need `HUGGING_FACE_HUB_TOKEN` in the server
  environment (from a `0600` file). Download retries: `XINFERENCE_DOWNLOAD_MAX_ATTEMPTS` (3).
- Memory estimates: `xinference cal-model-mem` and the Web UI **Recommend configuration**
  (`POST /v1/models/recommend`, read-only, v3.5+, single replica, assumes 2048-token context, FP16 KV,
  80 percent of free memory; always verify).

## Custom models

- **Existing family, local weights:** `xinference launch --model-path /path --model-engine <e> -n qwen1.5-chat`
  (works when the family is built in; on a cluster add `--worker-ip` for the worker that has the files).
- **Register a new model:** write a JSON spec (`version`, `context_length`, `model_name`, `model_lang`,
  `model_ability`, `model_family`, `model_specs[]` with `model_format`, `model_size_in_billions`,
  `quantization`, `model_uri` or `model_id`, optional `chat_template`, `stop`, reasoning tags, `virtualenv`),
  then `xinference register -t LLM --file spec.json --persist` and `unregister -t LLM -n <name>`. The Web UI
  can parse the config of a model and pre-fill fields (v2.0+). Needs `models:register`.

## Model virtual environments

On by default since v2.0. Each model gets its own uv-created virtualenv under
`XINFERENCE_HOME/virtualenv/v4/<model>/<engine>/<python>` with the packages its spec declares. The base is the
current environment's site-packages; `XINFERENCE_VIRTUAL_ENV_SKIP_INSTALLED=1` skips packages already present.

- Toggle globally with `XINFERENCE_ENABLE_VIRTUAL_ENV=0|1`, per model with `--enable-virtual-env` or
  `--disable-virtual-env`.
- Add or pin packages: `--virtual-env-package transformers==4.46.3` (repeatable; replaces a default of the same
  name). Local wheels: set `XINFERENCE_VIRTUAL_ENV_FIND_LINKS_ALLOWED_ROOTS` on every worker and pass
  `--virtual-env-find-link /abs/dir`; do not make those roots writable by untrusted users.
- Requires internet or a private PyPI mirror; Xinference inherits the current pip config. cuDNN errors with
  vLLM or SGLang inside a virtualenv may need `LD_LIBRARY_PATH` pointed at the nvidia cudnn, cusparselt and nccl
  library directories of the environment.
- Launch progress per replica: `GET /v1/models/<uid>/progress` shows `waiting_for_dependencies`,
  `installing_dependencies`, `loading`.
- Delete environments with the `virtualenv:delete` permission or by removing the directory when no model uses it.

## LoRA

Xinference does not manage adapters: download them yourself. Launch with
`--lora-modules <name> <path>` (repeatable; images also `--image-lora-load-kwargs` and
`--image-lora-fuse-kwargs`). For LLMs select one adapter per request with `lora_name` in `generate_config`.
Python: `launch_model(..., peft_model_config={"lora_list": [{"lora_name": ..., "local_path": ...}]})`.
