# KV Cache Offloading

Helps an agent extend LLM KV cache capacity by offloading evicted blocks to CPU RAM, disk, object storage or peer instances, for people running their own inference. It checks whether there is reuse to exploit, picks the lightest tier, gives exact flags for vLLM (native, tiering, LMCache), SGLang HiCache, TensorRT-LLM, llama.cpp, TabbyAPI/ExLlamaV3 and TensorFold, covers sharing and security, and verifies the gain before rollout.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill kv-cache-offloading
```

## Rules

- **Discover first.** Read-only checks of engine, host RAM, NUMA, disk and prefix-cache hit counters.
- **Ask before changing the system.** Restarts, large host reservations and disk writes need approval and an undo path.
- **Cached KV is sensitive.** Isolate tenants with salts, namespaces or separate tiers; lock down cache directories; keep secrets in `0600` files.
- **Gate where numerics can change.** Lossy options need the `llm-evals` skill gate with a user-chosen threshold and rollback; lossless tiers still get a cold-versus-warm check.
- **Verify upstream.** Connector and flag names change fast; check `--help` of the installed engine.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine flags, defaults and constraints, with unverified items marked.
- [`references/sharing-security-and-troubleshooting.md`](references/sharing-security-and-troubleshooting.md): tier scopes, hashing and cache-key security, sizing and troubleshooting.

## Companion skills

- `llm-evals`: A/B quality gate and decision record.
- `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `ollama`, `tensorfold`, `exllamav3`: engine install and operation.
- `kv-cache-quantization`, `prefix-aware-routing`, `disaggregated-serving`, `multi-node-inference`, `long-context`, `choosing-hardware`: related techniques.
- `self-hosted-llms`: running the stack on owned GPU servers.

## License

MIT
