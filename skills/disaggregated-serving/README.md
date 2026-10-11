# Disaggregated Serving

Helps an agent decide whether to split LLM inference into prefill and decode pools, and set it up and validate it with vLLM (NixlConnector, MooncakeConnector), SGLang (`--disaggregation-mode`), TensorRT-LLM (`cache_transceiver_config`), NVIDIA Dynamo, llm-d, NIXL and Mooncake. It covers when the split helps or hurts, exact flags and defaults, operations, and the numerics gate for options that change outputs.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill disaggregated-serving
```

## Rules

- **Justify the split first.** vLLM documents that disaggregated prefill does not improve throughput; it tunes TTFT and ITL.
- **Gate numerics changes.** Lower-precision KV, heterogeneous TP, recompute-on-failure and similar options go through the `llm-evals` gate.
- **Verify upstream.** Flags were read at the versions in each reference header; re-check before use. Unverified items are marked.
- **Private side channels only.** NIXL, Mooncake and bootstrap ports are unauthenticated.
- **Keep the aggregated deployment** until the gate passes.

## References

- [`references/engine-flags.md`](references/engine-flags.md): vLLM, SGLang and TensorRT-LLM flags, env vars, defaults, constraints.
- [`references/orchestrators.md`](references/orchestrators.md): Dynamo, llm-d, production-stack, AIBrix, SGLang gateway, NIXL and Mooncake.
- [`references/when-it-helps-and-gates.md`](references/when-it-helps-and-gates.md): when to use it, validation, numerics gate.

## Companion skills

- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `vllm`, `sglang`, `tensorrt-llm`: engine skills.
- `prefix-aware-routing`, `multi-node-inference`, `kv-cache-offloading`: sibling techniques.
- Planned: `dynamo`, `llm-d`, `aibrix`.

## License

MIT
