# Prefix-Aware Routing

Helps an agent choose, configure and validate KV/prefix-cache-aware request routing across LLM replicas: the llm-d inference scheduler on the Gateway API Inference Extension, vLLM production-stack, SGLang Model Gateway, NVIDIA Dynamo's KV router and AIBrix. It covers approximate versus precise modes, exact flags and plugin parameters, engine-side settings (block size, KV events), validation and the numerics gate for related options.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill prefix-aware-routing
```

## Rules

- **Check the workload first.** Routing helps only with long shared prefixes and 2+ replicas.
- **Match block sizes** between router and engine.
- **Verify upstream.** Flags were read at the versions in each reference header; unverified items are marked.
- **Private event ports.** KV-event and EPP ports are unauthenticated.
- **Gate numerics changes** (lower-precision KV, non-exact KV reuse, engine changes) with `llm-evals`.

## References

- [`references/router-matrix.md`](references/router-matrix.md): router flags, plugin parameters, defaults.
- [`references/engine-side.md`](references/engine-side.md): engine settings, hit-rate hygiene, validation, security, numerics gate.

## Companion skills

- `llm-evals`: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`
- `disaggregated-serving`: `npx skills add ScaleDockHQ/llm-skills --skill disaggregated-serving`
- `llm-gateway`, `self-hosted-llms`, `vllm`, `sglang`, `tensorrt-llm`.
- Planned: `dynamo`, `llm-d`, `aibrix`, `kserve`.

## License

MIT
