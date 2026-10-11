# Recipe: vLLM on Modal

> Verified against modal 1.6.1, Modal docs (Run OpenAI-compatible LLM inference with Gemma and vLLM, Servers guide, Endpoints guide, Proxy Tokens), 2026-10-11

Details live in the `modal` skill (`vllm-server.md`, `endpoints.md`, `scaling-and-volumes.md`, `troubleshooting.md`) and the `vllm` skill. This file sequences them.

## 0. Decide the inputs (ask the user)

| Input              | Example                             | Where to decide                             |
| ------------------ | ----------------------------------- | ------------------------------------------- |
| Server or Endpoint | own `@app.server` or Dedicated      | see below                                   |
| Model and revision | `<org>/<model>`, full commit hash   | `vllm`, `choosing-hardware`                 |
| GPU                | Modal suggests starting with `L40S` | `modal` `scaling-and-volumes.md`            |
| `max_containers`   | `1` to start                        | the spend cap                               |
| Region             | routing region                      | a compute region can add a price multiplier |

## 1A. Your own vLLM Server

Copy the current shape from Modal's example, https://modal.com/docs/examples/vllm_inference, then keep these properties (full trimmed app in `modal` `vllm-server.md`):

- `modal.Image.from_registry("nvidia/cuda:<tag>", add_python="3.12").entrypoint([]).uv_pip_install("vllm==<pin from the example>")`. The example currently pins `vllm==0.21.0` with `nvidia/cuda:12.9.0-devel-ubuntu22.04`; PyPI has newer vLLM, so do not assume the latest works with the example's flags.
- A pinned `MODEL_REVISION`, and two Volumes for the Hugging Face and vLLM caches.
- `@app.server(image=..., gpu="<GPU>:1", port=8000, scaledown_window=..., startup_timeout=..., volumes=..., target_concurrency=..., max_containers=1)`, with `unauthenticated` left at its default (False).
- `@modal.enter()` starts `vllm serve ... --host 0.0.0.0 --port 8000 --served-model-name ...`; the container is ready once the port listens.
- Gated model: add `secrets=[modal.Secret.from_name("huggingface-secret")]`.

```bash
modal run app.py        # ephemeral App, stops when the command exits
modal deploy app.py     # persistent and billable while containers run: ASK FIRST
modal server info <app>/<server>
modal server logs <app>/<server> -f
```

## 1B. Dedicated Endpoint (no code)

```bash
modal endpoint create --name llm --model <hf-repo-id>       # after approval
modal endpoint info llm --json
```

Shared Endpoints are billed per token and managed by Modal; Dedicated bill for compute and can scale to zero. Check which mode a model supports in the Modal Library.

## 2. Proxy token (gateway only)

```bash
umask 077
modal workspace proxy-tokens create --name llm-gateway --json > ~/.config/modal-proxy-token.json   # secret is shown once
jq 'keys' ~/.config/modal-proxy-token.json          # prints field names only, never values
# Build the single bearer value "<id>.<secret>" from those two fields into an env var, using the field names printed above:
# export MODAL_PROXY_TOKEN="$(jq -r '"\(.<id field>).\(.<secret field>)"' ~/.config/modal-proxy-token.json)"
```

Tokens are `wk-...` (ID) and `ws-...` (secret). The single bearer value is `<token id>.<token secret>`, which OpenAI-compatible clients accept as an API key; two headers, `Modal-Key` and `Modal-Secret`, also work. The JSON field names were not verified here, hence the `jq 'keys'` check.

## 3. Smoke test

```bash
export SERVER_URL="<url from modal server info or modal endpoint info>"      # ends with .modal.direct for Servers
until curl -fsS "$SERVER_URL/health" -H "Authorization: Bearer $MODAL_PROXY_TOKEN" >/dev/null; do sleep 5; done
curl -sS "$SERVER_URL/v1/models" -H "Authorization: Bearer $MODAL_PROXY_TOKEN" | jq -r '.data[].id'
curl -sS "$SERVER_URL/v1/chat/completions" -H "Authorization: Bearer $MODAL_PROXY_TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"<served name>","messages":[{"role":"user","content":"Say hi"}],"max_tokens":8}' | jq -r '.choices[0].message.content'
```

`503` means no container is ready yet (cold start). `401` or `403` means a missing, wrong or environment-unscoped proxy token.

## 4. Stack-specific pitfalls

| Pitfall                     | Fix                                                                                                                                    |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 503 on the first request    | Cold start. Retry with backoff in the gateway; or `min_containers=1` and accept idle cost.                                             |
| 401 or 403 from the gateway | Proxy token missing, malformed or not allowed for the App's Environment (`modal workspace proxy-tokens allow`).                        |
| Slow cold start             | Cache Volumes for weights and compile artifacts; `--enforce-eager` trades throughput for faster boots (see the example's `FAST_BOOT`). |
| Public URL by accident      | Never set `unauthenticated=True`; confirm with a request that has no token (expect rejection).                                         |
| Cost surprise               | `max_containers`, short `scaledown_window`, `min_containers=0`; read `modal billing rates`.                                            |
