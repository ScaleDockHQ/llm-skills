# llama-swap configuration

> Verified against llama-swap v263 (docs/config.example.yaml, docs/kb guides), 2026-10-11

Authoritative source: `docs/config.example.yaml` at your installed version. A JSON schema for editors lives at `config-schema.json` in the repo; add `# yaml-language-server: $schema=https://raw.githubusercontent.com/mostlygeek/llama-swap/refs/heads/main/config-schema.json` for validation. Only `models` and each model's `cmd` are required.

## Global keys

| Key                                                  | Default                                | Notes                                                                                                                                                   |
| ---------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `healthCheckTimeout`                                 | 120 (minimum 15)                       | Seconds to wait for `checkEndpoint`. A health endpoint that reports `{"progress": 0..1}` restarts the countdown each time progress changes.             |
| `logLevel`                                           | `info`                                 | `debug`, `info`, `warn`, `error`.                                                                                                                       |
| `logTimeFormat`                                      | disabled                               | `ansic`, `rfc3339`, `kitchen`, `stampmilli`, and so on.                                                                                                 |
| `logToStdout`                                        | `proxy`                                | Comma list of `proxy`, `upstream`, `http`, or `both`, `none`. Read at startup only. HTTP access lines no longer appear on stdout unless you add `http`. |
| `store.path`                                         | in-memory sqlite                       | Path to a sqlite file to keep Activity metrics across restarts.                                                                                         |
| `metricsMaxInMemory`                                 | 1000                                   | Ignored when `store.path` is set.                                                                                                                       |
| `captureBuffer`                                      | 10 (MB)                                | Request and response captures for the UI; 0 disables. Do not capture secrets.                                                                           |
| `ui.activity.session_id`                             | `X-Session-ID`, `X-Litellm-Session-Id` | Header names used to show a session in the Activity table; `[]` disables.                                                                               |
| `performance.disabled` / `.every`                    | false / 5s (minimum 5s)                | System and GPU statistics polling.                                                                                                                      |
| `startPort`                                          | 5800                                   | First value of the auto-incrementing `${PORT}` macro.                                                                                                   |
| `sendLoadingState`                                   | false                                  | Streams loading messages in the `reasoning` field during a cold start so chat UIs and proxies see activity.                                             |
| `includeAliasesInList`                               | false                                  | Lists aliases in `/v1/models` too.                                                                                                                      |
| `globalTTL`                                          | 0 (never)                              | Idle seconds before unload. Model `ttl: -1` inherits it.                                                                                                |
| `unloadTimeout`                                      | 10                                     | Graceful seconds before force-kill on unload. Per-model override exists. `docker stop` needs more.                                                      |
| `globalConcurrencyLimit`                             | 0 (none)                               | One shared semaphore across all models; excess requests get HTTP 429 immediately (not queued).                                                          |
| `macros`                                             | empty                                  | See below.                                                                                                                                              |
| `apiKeys`                                            | `[]`                                   | Empty means unauthenticated. See below.                                                                                                                 |
| `security.cors`                                      | permissive                             | See below.                                                                                                                                              |
| `tailcat`                                            | none                                   | Models exposed over Tailcat virtual TCP; requires `-listen-tailcat`. Out of scope here; see upstream `docs/kb/guides/operations/tailcat.md`.            |
| `upstream.ignorePaths`                               | static assets, ComfyUI `/ws`           | RE2 regexes for `/upstream/<model>/...` paths that must not trigger a swap.                                                                             |
| `profiles`, `selectors`, `routing`, `hooks`, `peers` | none                                   | See `routing.md` and below.                                                                                                                             |

## Model keys

Each entry under `models:` is keyed by the model ID clients send.

| Key                               | Default                                                                  | Notes                                                                                                                                                                                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cmd`                             | required                                                                 | Shell-style string. Multi-line with `\|` allowed; comments inside are stripped. Macros allowed.                                                                                                                                                                        |
| `cmdStop`                         | SIGTERM, 5 s then kill                                                   | Command that stops a model; `${PID}` is the process ID. Required for containers.                                                                                                                                                                                       |
| `proxy`                           | `http://localhost:${PORT}`                                               | Needed when `cmd` hardcodes a port or runs a container (`http://127.0.0.1:${PORT}`).                                                                                                                                                                                   |
| `checkEndpoint`                   | `/health`                                                                | Must return 200; `none` skips the check (last resort).                                                                                                                                                                                                                 |
| `ttl`                             | -1 (use `globalTTL`)                                                     | Idle seconds; 0 = never.                                                                                                                                                                                                                                               |
| `unloadTimeout`                   | global value                                                             | 0 uses the global value.                                                                                                                                                                                                                                               |
| `env`                             | none                                                                     | List of `NAME=value` strings added to the process environment.                                                                                                                                                                                                         |
| `aliases`                         | none                                                                     | Unique alternative IDs. `setParamsByID` keys also become aliases.                                                                                                                                                                                                      |
| `useModelName`                    | the ID                                                                   | Name sent upstream when it differs.                                                                                                                                                                                                                                    |
| `name`, `description`, `metadata` | none                                                                     | Shown in `/v1/models`. `metadata` accepts macros and nested values.                                                                                                                                                                                                    |
| `unlisted`                        | false                                                                    | Hidden from `/v1/models` but callable.                                                                                                                                                                                                                                 |
| `capabilities`                    | auto-discovered                                                          | `in`, `out` (text, audio, image, video; `decisions` for out), `tools`, `reranker`, `context`, `disableAuto`. Unset fields are filled from the upstream when ready (llama-server and vLLM). Values written here win; a zero value reads as unset, so use `disableAuto`. |
| `concurrencyLimit`                | 0 (internal default 10)                                                  | Per-model active parallel requests; excess get 429.                                                                                                                                                                                                                    |
| `sendLoadingState`                | global value                                                             | Per-model override.                                                                                                                                                                                                                                                    |
| `disableKeepAlives`               | false                                                                    | New upstream connection per request. Fixes 502 `proxy error: EOF` right after a stream from llama-server.                                                                                                                                                              |
| `timeouts`                        | connect 30, keepalive 30, responseHeader 0, tlsHandshake 10, idleConn 90 | Seconds; 0 disables. Raise `responseHeader` only for slow hardware.                                                                                                                                                                                                    |
| `compat.ignoreWebsockets`         | false                                                                    | Websocket connections do not load a stopped model or reset TTL (useful for ComfyUI).                                                                                                                                                                                   |
| `filters`                         | none                                                                     | `stripParams`, `setParams`, `setParamsByID`.                                                                                                                                                                                                                           |
| `macros`                          | none                                                                     | Model-level macros override global ones.                                                                                                                                                                                                                               |

There is no `maxConcurrentRequests`; the key is `concurrencyLimit`.

## Macros

- Global `macros:` and per-model `macros:` are plain substitutions. Names match `^[a-zA-Z0-9_-]+$`, under 64 characters, and may not be `PID`, `PORT` or `MODEL_ID`. Values can be strings, numbers or booleans. A macro may use earlier macros only.
- `${env.VAR}` is substituted first and fails config loading when `VAR` is unset.
- `${PORT}` is assigned per model while loading; `${MODEL_ID}` is the key; `${PID}` exists in `cmdStop`.
- Macros keep types in `metadata` (a numeric macro stays a number).

## Filters

```yaml
filters:
  stripParams: "temperature, top_p" # server-side enforcement; `model` can never be removed
  setParams: # always applied; `model` cannot be overridden
    temperature: 0.7
    max_tokens?: 4096 # trailing ? = set only if the request does not carry it
  setParamsByID: # runs after setParams; each key becomes an alias
    "${MODEL_ID}:high":
      chat_template_kwargs: { reasoning_effort: high }
```

A request for `gpt-oss:high` runs the `gpt-oss` process with the extra parameters, with no second copy in memory. The right key for a given engine and model (`reasoning_effort`, `chat_template_kwargs`, `enable_thinking`) comes from the engine and model family; the `self-hosted-llms` skill's `reasoning-effort.md` has a worked mapping.

## Authentication

```yaml
apiKeys:
  - "${env.LLAMA_SWAP_KEY}"
  - "${env.LLAMA_SWAP_KEY_NEXT}" # rotate: add new, move clients, remove old
```

Clients send `Authorization: Bearer <key>`, `x-api-key: <key>` or HTTP Basic. The UI and `/api/` are covered. Only a few static files (favicon, web manifest and its icons) stay open. All keys are equivalent: no per-key limits, users or roles; use LiteLLM for that. Generate one with `printf 'sk-%s\n' "$(head -c 48 /dev/urandom | base64)"` into a `0600` file, not into the terminal log.

## CORS

Omit `security` for the permissive default (any origin; only sent when the request has an `Origin`). Setting `security.cors.allowedOrigins` takes control; `*` cannot combine with `allowCredentials`, and `allowPrivateNetwork` needs explicit origins. Other keys: `allowedMethods`, `allowedHeaders`, `exposedHeaders`, `maxAge` (86400). CORS headers set by the upstream are stripped so one set reaches the client.

## Peers

```yaml
peers:
  other-box:
    proxy: http://192.168.1.23 # another llama-swap or any /v1 server
    models: [model_a, model_b]
  openrouter:
    proxy: https://openrouter.ai/api
    apiKey: ${env.OPENROUTER_API_KEY} # sent as Authorization Bearer and x-api-key
    models: [meta-llama/llama-3.1-8b-instruct]
    filters: { setParams: { provider: { zdr: true } } }
```

Peer models are always addressable as `<peer ID>/<model ID>`. An unqualified ID works only when exactly one peer provides it; local IDs and aliases win. `tailcat://` peers exist (see upstream). `peers.*.apiKey` is what llama-swap presents to the peer; it is unrelated to `apiKeys`.

## Reload

`-watch-config` reloads on file change (default true in the unified image). Changing `logToStdout` or the listen address needs a restart. Validate edits with the JSON schema in your editor before saving a live file (a missing `${env.VAR}` makes loading fail).

## Sources

- <https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml>
- <https://github.com/mostlygeek/llama-swap/tree/main/docs/kb/guides>
