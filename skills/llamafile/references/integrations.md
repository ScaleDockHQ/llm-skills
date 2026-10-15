# Integrate llamafile

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

## OpenAI and Anthropic clients

```bash
export OPENAI_BASE_URL=http://127.0.0.1:8080/v1
export OPENAI_API_KEY=no-key-required          # must be non-empty; use the real key when --api-key-file is set
```

```python
from openai import OpenAI
client = OpenAI()   # reads the two variables above
print(client.chat.completions.create(model="local-model",
      messages=[{"role": "user", "content": "Hello!"}]).choices[0].message.content)
```

Anthropic-style clients can call `POST /v1/messages` with `x-api-key`. Use `--alias` so `model` is stable.

## LiteLLM

Template: `templates/litellm-llamafile.yaml`.

```yaml
model_list:
  - model_name: local-llamafile
    litellm_params:
      model: openai/local-model
      api_base: http://127.0.0.1:8080/v1
      api_key: os.environ/LLAMAFILE_API_KEY
```

Skill: `litellm` (`npx skills add ScaleDockHQ/llm-skills --skill litellm`).

## systemd

Template: `templates/llamafile.service`. Points that matter:

- The file is a polyglot shell script. Launch it through `/bin/sh` so it works without APE `binfmt_misc` registration (direct exec by systemd is unverified here).
- Set `TMPDIR` to a writable, exec-allowed directory: the loader unpacks to `$TMPDIR/.ape-1.10`. `ProtectHome` and `PrivateTmp` can break this if the path is not writable.
- Read the API key from `--api-key-file`, mode `0600`, owned by the service user.
- GPU mode skips the sandbox; add systemd hardening (`NoNewPrivileges`, `ProtectSystem=strict`) yourself, and test that the GPU still works.
- Model loading can take minutes: set `TimeoutStartSec` generously and probe `/health`.

## Containers

There is no official image in the docs. Common pattern: a minimal base image, the runtime file copied in, `chmod +x`, entrypoint `sh ./llamafile --server --host 0.0.0.0 ...` with `--api-key-file` mounted as a secret. For NVIDIA add the NVIDIA runtime and the driver libraries; the bundled CUDA library needs only the driver. Test `sh -c ./llamafile` behavior on your base image. Prefer a container for tool-enabled servers to isolate tool execution.

## Several llamafiles behind one URL

One model per process. Use `llama-swap` to start and stop llamafile servers on demand, or `litellm` to route by model name. Skills: `llama-swap`, `litellm`.

## Open WebUI and other chat UIs

Point any OpenAI-compatible UI at `http://host:8080/v1` with the key. See `open-webui` (`npx skills add ScaleDockHQ/llm-skills --skill open-webui`).

## Reverse proxy

Skills: `caddy`, `cloudflare-tunnel`, `tailscale`. Disable buffering for streamed responses and raise read timeouts, since a first request waits for model load.
