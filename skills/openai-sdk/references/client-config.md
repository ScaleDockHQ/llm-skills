# OpenAI SDK client configuration

> Verified against openai-python v3.28.0 and openai-node v7.32.0 (README and client source), 2026-10-11

## Settings and env vars

| Setting       | Python                                  | Node             | Env var                                          |
| ------------- | --------------------------------------- | ---------------- | ------------------------------------------------ |
| Base URL      | `base_url`                              | `baseURL`        | `OPENAI_BASE_URL`                                |
| Key           | `api_key`                               | `apiKey`         | `OPENAI_API_KEY`                                 |
| Extra headers | `default_headers`                       | `defaultHeaders` | `OPENAI_CUSTOM_HEADERS` (lines of `Name: value`) |
| Timeout       | `timeout` (seconds or `httpx2.Timeout`) | `timeout` (ms)   | none                                             |
| Retries       | `max_retries`                           | `maxRetries`     | none                                             |
| Debug log     | none                                    | `logLevel`       | `OPENAI_LOG=debug` (both SDKs)                   |

Defaults: base `https://api.openai.com/v1`, timeout 10 minutes (Python connect 5 s), 2 retries. A constructor argument beats the env var. If neither key source exists the constructor raises `Missing credentials`.

## Minimal clients

Python (`pip install openai`):

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url="https://llm.example.com/v1",
    api_key=os.environ["LLM_API_KEY"],      # any non-empty string if the server has no auth
    timeout=120.0,
    max_retries=1,
)
print([m.id for m in client.models.list().data][:5])   # read-only discovery
```

Node (`npm i openai`, ESM):

```js
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "https://llm.example.com/v1",
  apiKey: process.env.LLM_API_KEY,
  timeout: 120_000,
  maxRetries: 1,
});
const models = await client.models.list();
console.log(models.data.slice(0, 5).map((m) => m.id));
```

`assets/client.mjs` is a ready smoke test: `LLM_BASE_URL=... LLM_API_KEY_FILE=... MODEL=... node assets/client.mjs`.

## Keys without printing them

- Prefer an environment variable loaded from a `0600` file: `export LLM_API_KEY="$(cat ~/.config/llm/key)"`.
- Never print `client.api_key`, request headers or `os.environ`; redact the `Authorization` header from `OPENAI_LOG=debug` output before sharing.
- A gateway that issues per-app virtual keys (LiteLLM) is better than sharing one engine key.
- Keyless local servers (llama.cpp or Ollama without `--api-key`): pass `"none"` or any placeholder. Servers ignore it.

## Non-Bearer auth and gateway headers

The SDK always sends `Authorization: Bearer <api_key>`. For gateways that want another header, add it:

```python
client = OpenAI(base_url="https://llm.example.com/v1", api_key="unused",
                default_headers={"X-Api-Key": os.environ["LLM_API_KEY"]})
```

```js
new OpenAI({
  baseURL,
  apiKey: "unused",
  defaultHeaders: { "X-Api-Key": process.env.LLM_API_KEY },
});
```

Per request: Python `extra_headers={...}`, Node `{ headers: {...} }` as the second argument. Routing headers for gateways (team, tags, cache control) go the same way.

## Timeouts, retries, long generations

- Reasoning models and long outputs can exceed a short timeout; stream instead, which keeps bytes flowing.
- Retries cover connection errors, 408, 409, 429 and 5xx. Set `max_retries=0` on non-idempotent flows or when a gateway already retries.
- Per request: Python `client.with_options(timeout=5.0, max_retries=0).chat.completions.create(...)`.
- Node's fetch also has its own header and body inactivity limits (about five minutes) regardless of `timeout`; for longer silent waits install `undici` and pass a custom `fetch` with an `Agent` (see the SDK README).

## Proxies and TLS

- Python v3 clients use `httpx2`: pass `http_client=DefaultHttpx2Client(proxy="http://proxy:3128")`. Check the `DefaultHttpx2Client` options for TLS settings in the installed version; custom clients built on the old `httpx` package are not drop-in.
- Node: `fetchOptions: { dispatcher: new ProxyAgent("http://proxy:3128") }` with `fetch` and `ProxyAgent` imported from `undici` (they must match).
- Self-signed certificates: trust the CA (Python `verify=`; Node `NODE_EXTRA_CA_CERTS=/path/ca.pem`). Do not disable verification except for a throwaway test.
- Env proxies (`HTTPS_PROXY`, `NO_PROXY`): behavior depends on the HTTP library and runtime (unverified here); if a LAN model server is routed through a corporate proxy by mistake, set `NO_PROXY` for its host and test with the probe.

## Async and scoped clients

Python `AsyncOpenAI` has the same arguments. Create one client per process and reuse it; per-call changes use `with_options`. Node clients are also reusable; `client.withOptions({ timeout })` mirrors it.

## Switching between environments

Keep one config source (env file or settings) with `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`, and construct the client from them. Do not rely on `OPENAI_BASE_URL` in apps that also call the real OpenAI.

## Official links

- openai-python: https://github.com/openai/openai-python
- openai-node: https://github.com/openai/openai-node
- OpenAI API reference: https://platform.openai.com/docs/api-reference
