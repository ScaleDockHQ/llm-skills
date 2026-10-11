# Aphrodite Engine API and security

> Verified against Aphrodite Engine (Sonar) v0.24.1, 2026-10-11

Base URL `http://HOST:2242/v1`. The model name clients send is `--served-model-name` (else the repo or path).
Discover on a live server: `/docs`, `/openapi.json`. Use `--api-key` or `APHRODITE_API_KEY` (bearer).

| Route                                                                                               | Use                                                                                                                                        |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `/v1/chat/completions`, `/v1/completions`, `/v1/responses`                                          | OpenAI chat, raw prompt, Responses                                                                                                         |
| `/v1/messages`, `/v1/messages/count_tokens`                                                         | Anthropic Messages                                                                                                                         |
| `/v1/embeddings`, `/v2/embed`, `/pooling`, `/score`, `/rerank`, `/v2/rerank`, `/generative_scoring` | Pooling, scoring, reranking (needs a suitable runner/task)                                                                                 |
| `/v1/audio/transcriptions`                                                                          | Transcription models (`json`, `text`, `verbose_json`, `diarized_json`)                                                                     |
| `/tokenize`, `/detokenize`                                                                          | Tokenizer of the loaded model                                                                                                              |
| `/v1/chat/completions/render`, `/v1/completions/render`, `/inference/v1/generate`                   | Render and token-in/token-out for gateways and P/D                                                                                         |
| `/v1/models`, `/health`, `/metrics`, `/version`, `/load`                                            | Discovery and ops (`/load` with load tracking)                                                                                             |
| `/v1/load_lora_adapter`, `/v1/unload_lora_adapter`                                                  | Only with runtime LoRA updating enabled                                                                                                    |
| Kobold routes (`/api/v1/model`, `/api/extra/generate/check`, `/api/extra/abort`, ...)               | Kobold-compatible clients; docs name `--launch-kobold-api` but the generated flag reference lacks it: verify with `aphrodite serve --help` |

```bash
curl -s --fail http://127.0.0.1:2242/health
curl -s http://127.0.0.1:2242/v1/models -H "Authorization: Bearer $(cat ~/.aphrodite-key)" | jq '.data[].id'
```

## Security

- Bind loopback or a private address; TLS and rate limits at a proxy. `/metrics`, profiling, adapter management,
  cache reset, sleep, weight update and collective RPC routes must not be public.
- `--api-key` protects the API routes, not the network: do not rely on it for metrics or admin routes.
- Pin `--revision` and `--tokenizer-revision` to commits; `--trust-remote-code` runs repo code with the
  server's file, network and device access.
- Media: `--allowed-media-domains`, no `--allowed-local-media-path` on public hosts, proxy size and time limits.
- Tenants needing strong isolation get separate replicas (shared prefix cache, queues, logs and metrics leak
  workload shape). Containers: not privileged, model storage read-only, writable cache dir.
- Prompts and outputs can contain secrets: restrict request logs and traces, set retention. Opt out of usage
  statistics (`APHRODITE_NO_USAGE_STATS=1`, `DO_NOT_TRACK=1`) where required.

## Client examples

```python
from openai import OpenAI
c = OpenAI(base_url="http://localhost:2242/v1", api_key=open("/home/me/.aphrodite-key").read().strip())
c.chat.completions.create(model="qwen3", messages=[{"role":"user","content":"hi"}], extra_body={"min_p":0.05})
```

Retry connection errors and 5xx with backoff, not in-flight generations after bytes were sent. Proxy: disable
response buffering, read timeout above the longest request, limit body size for media, retry only before
response headers.
