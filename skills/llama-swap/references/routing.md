# Routing, residency and queues

> Verified against llama-swap v263 (docs/config.example.yaml, docs/kb routing and ttl guides), 2026-10-11

By default llama-swap runs one model at a time. Everything else here changes what may be resident together. All keys live under `routing.router.settings` unless noted.

## Engines

`routing.router.use` is `group` (default) or `matrix`.

### Groups

```yaml
routing:
  router:
    use: group
    settings:
      groups:
        large: { swap: true, exclusive: false, members: [qwen-coder, gpt-oss] }
        side:
          { swap: false, exclusive: false, members: [embeddings, small-gguf] }
        forever:
          {
            swap: false,
            exclusive: false,
            persistent: true,
            members: [reranker],
          }
```

- `swap` (default true): one member at a time inside the group. false: all members may run together.
- `exclusive` (default true): running a member unloads every other group. false leaves others alone.
- `persistent` (default false): other groups cannot unload these members.
- A model belongs to at most one group. Models in no group follow the default one-at-a-time behaviour, so list every model explicitly.
- Set `large.exclusive: true` if no side model fits next to a large model.

### Matrix

For combinations a group cannot express (an LLM plus TTS plus reranker, or image generation next to a chat model). The solver evicts as few running models as possible, keeping the costliest loaded.

```yaml
routing:
  router:
    use: matrix
    settings:
      matrix:
        vars:
          { g: gemma-model, q: qwen-model, v: voxtral-model, e: reranker-model }
        evict_costs: { v: 50 } # relative cost of losing a model (default 1)
        sets:
          standard: "(g | q) & v" # & together, | alternatives, () grouping, +ref inlines a set
          with_rerank: "(g | q) & v & e"
          full: "llama-70B" # a model in no set can only run alone
```

Request for X: forward if running; else collect sets containing X, cost each by the `evict_costs` of running models outside that set, pick the cheapest (ties by definition order), evict, start X. A set permits any subset of itself; only the requested model is started.

## Scheduler and queues

`routing.scheduler.use: fifo` is the only scheduler. `settings.fifo.priority` maps model ID to priority (default 0, higher first). Swaps are serialized and requests queue until the model is ready. Do not use client retries as capacity control. A queue that never drains means a wrong `cmd`, `proxy` or health check (`troubleshooting.md`).

Limits: per-model `concurrencyLimit` and global `globalConcurrencyLimit`; excess requests receive HTTP 429 at once. Clients must back off.

## Residency: TTL, unload, preload

- `ttl` (idle seconds, resets on each request) and `globalTTL`. `ttl: 0` pins a model open; `-1` inherits.
- `unloadTimeout` is how long to wait for the process to exit after unload starts. Docker needs `cmdStop: docker stop ${MODEL_ID}` and a larger value (90 s works for big engines).
- On demand: `POST /api/models/unload` or `/api/models/unload/<id>`.
- Preload at startup:

```yaml
hooks:
  on_startup:
    preload: ["qwen-coder"]
    profile: coding # optional; must name a key in profiles
```

Preload only models that can coexist. Several models in one swapping group load and immediately swap each other out. Preloading does not make an incompatible model fit.

## Profiles

Named model-ID replacements switched at runtime (UI, `GET /api/profiles`, `PUT /api/profiles/active`). One profile or none is active; `hooks.on_startup.profile` picks the one used at startup and after reload. Pins are applied before aliases, filters and routing; a target may be a local model, peer model, alias, `setParamsByID` alias or selector; `""` or `~` disables the pin with a 404.

```yaml
profiles:
  coding:
    description: Coding-focused routing
    pins: { llm-code: gpt-oss-120b, image-gen: ~ }
```

## Selectors

Virtual IDs resolved per request. Strategies: `warm` (first ready target, then one already starting, else cold-start the first), `pin` (always the first target), `spillover` (fill targets to `settings.spillover` requests each, default 1, then use the next). Selector IDs may not collide with model IDs, aliases or qualified peer names; targets cannot be selectors; they are not supported on `/upstream/<model>`.

## Sources

- <https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml>
- <https://github.com/mostlygeek/llama-swap/tree/main/docs/kb/guides/routing>
- <https://github.com/mostlygeek/llama-swap/blob/main/docs/kb/guides/model-runtime/ttl-and-unloading.md>
