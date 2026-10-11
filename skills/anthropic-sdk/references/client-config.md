# Anthropic SDK client configuration

> Verified against anthropic-sdk-python v1.13.0 and anthropic-sdk-typescript sdk-v0.133.0 (client source and platform docs), 2026-10-11

## Settings and env vars

| Setting                            | Python                                  | TypeScript       | Env var                                             |
| ---------------------------------- | --------------------------------------- | ---------------- | --------------------------------------------------- |
| Base URL                           | `base_url`                              | `baseURL`        | `ANTHROPIC_BASE_URL`                                |
| `x-api-key` credential             | `api_key`                               | `apiKey`         | `ANTHROPIC_API_KEY`                                 |
| `Authorization: Bearer` credential | `auth_token`                            | `authToken`      | `ANTHROPIC_AUTH_TOKEN`                              |
| Extra headers                      | `default_headers`                       | `defaultHeaders` | `ANTHROPIC_CUSTOM_HEADERS` (lines of `Name: value`) |
| Timeout                            | `timeout` (seconds or `httpx2.Timeout`) | `timeout` (ms)   | none                                                |
| Retries                            | `max_retries`                           | `maxRetries`     | none                                                |
| Log                                | none                                    | `logLevel`       | `ANTHROPIC_LOG=debug` or `info`                     |

Defaults: base `https://api.anthropic.com`, timeout 10 minutes, 2 retries (connection errors, 408, 409, 429, 5xx). The SDK always sends `anthropic-version: 2023-06-01`. A constructor argument beats an env var. Python: passing any explicit credential argument stops it from reading the credential env vars at all.

## Which credential option

| Server checks                                            | Use                                           |
| -------------------------------------------------------- | --------------------------------------------- |
| `Authorization: Bearer` (vLLM `--api-key`, Ollama cloud) | `auth_token` / `authToken`                    |
| `x-api-key` (Anthropic API)                              | `api_key` / `apiKey`                          |
| Either (LiteLLM, llama-swap, llama.cpp)                  | Either; keep to one                           |
| Nothing (local Ollama, llama.cpp without a key)          | A placeholder in either, for example `"none"` |

For keyless servers pass a placeholder in one option: the SDK may refuse to send a request with no credential at all. If both options are set, both headers are sent. Always confirm with the probe which header your server accepts.

## Minimal clients

Python (`pip install anthropic`):

```python
import os
from anthropic import Anthropic

client = Anthropic(
    base_url="https://llm.example.com",            # no /v1
    auth_token=os.environ["LLM_API_KEY"],          # Bearer; use api_key= for x-api-key servers
    timeout=120.0,
    max_retries=1,
)
msg = client.messages.create(model="coder", max_tokens=64,
                             messages=[{"role": "user", "content": "ping"}])
print(msg.content[0].text)
```

Node (`npm i @anthropic-ai/sdk`, ESM):

```js
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({
  baseURL: "https://llm.example.com", // no /v1
  authToken: process.env.LLM_API_KEY,
  timeout: 120_000,
  maxRetries: 1,
});
const msg = await client.messages.create({
  model: "coder",
  max_tokens: 64,
  messages: [{ role: "user", content: "ping" }],
});
console.log(msg.content[0].text);
```

`assets/client.mjs` is a ready smoke test: `LLM_BASE_URL=... LLM_API_KEY_FILE=... MODEL=... node assets/client.mjs`.

## Keys without printing them

- Load from a `0600` file into the environment: `export LLM_API_KEY="$(cat ~/.config/llm/key)"`.
- Never print `client.api_key`, `client.auth_token`, request headers or the full environment; redact `ANTHROPIC_LOG=debug` output before sharing.
- Prefer per-app virtual keys from a gateway over a shared engine key.
- Do not leave a real `ANTHROPIC_API_KEY` exported when you target a self-hosted server: it can be sent to the wrong host if a base URL is left at the default.

## Headers

```python
client = Anthropic(base_url=..., auth_token=..., default_headers={"X-Team": "search"})
client.messages.create(..., extra_headers={"X-Trace": "abc"})
```

Node: `defaultHeaders` in the constructor, and `{ headers: {...} }` as the second argument of a call. Gateway routing or tagging headers go this way.

## Timeouts and long generations

- Stream when `max_tokens` is large: the SDK raises an error for non-streaming requests expected to take more than about 10 minutes (Python `ValueError`; Node throws too), and idle connections can be dropped by networks. `stream=True`, or setting `timeout`, disables that error.
- The TypeScript SDK scales its default timeout with `max_tokens` for non-streaming calls (up to about 60 minutes) unless you set `timeout`.
- A model that must load on demand (llama-swap) needs a longer timeout or a warm-up call.
- Per request: Python `client.with_options(timeout=5.0, max_retries=0).messages.create(...)`; Node `client.messages.create(body, { timeout: 5000, maxRetries: 0 })`.

## Proxies and TLS

- Python uses `httpx2`: pass your own client as `http_client`, for example `DefaultHttpxClient(proxy="http://proxy:3128")` as in the platform docs for this version; check the installed version's exported client name and TLS options.
- Node: `fetchOptions` with a matching `undici` `ProxyAgent` dispatcher and `fetch`, as in the SDK README.
- Private CA: trust it (Node `NODE_EXTRA_CA_CERTS=/path/ca.pem`; Python via the HTTP client TLS settings). Disabling verification is for a throwaway test only.
- For LAN servers behind a corporate proxy, add the host to `NO_PROXY` and test with the probe.

## Async, reuse, scoped options

Python `AsyncAnthropic` takes the same arguments. Create one client per process; use `with_options` for per-call changes. Node clients are reusable.

## Do not mix up the AI SDK

Vercel's `@ai-sdk/anthropic` provider takes a `baseURL` that includes `/v1`; the official Anthropic SDKs do not. Same server, different value.

## Official links

- Python SDK: https://github.com/anthropics/anthropic-sdk-python
- TypeScript SDK: https://github.com/anthropics/anthropic-sdk-typescript
- SDK docs: https://platform.claude.com/docs/en/api/client-sdks
- Messages API: https://platform.claude.com/docs/en/api/messages
