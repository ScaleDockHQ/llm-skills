# Multi-Node Inference

Helps an agent serve one model across several machines: choose TP, PP, DP and EP layouts, bring up vLLM (Ray or multiprocessing), SGLang, TensorRT-LLM (MPI), llama.cpp RPC, exo or TensorFold speed-up, verify the NCCL/RDMA path on ConnectX-7, RoCE or InfiniBand, and gate numerics changes. DGX Spark dual node is one worked example.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill multi-node-inference
```

## Rules

- **Prefer one node plus replicas** when the model fits.
- **Prove the fabric** (`nccl-tests`, `NCCL_DEBUG=INFO`) before tuning engines.
- **Private networks only.** Ray, llama.cpp RPC and exo discovery are not secure for public exposure.
- **Verify upstream.** Flags were read at the versions in each reference header; unverified items are marked.
- **Gate numerics changes** (TP/PP layout, lossy KV, speed-up modes) with `llm-evals`.

## References

- [`references/engine-matrix.md`](references/engine-matrix.md): per-engine commands, flags, defaults, constraints.
- [`references/interconnect-and-dgx-spark.md`](references/interconnect-and-dgx-spark.md): NCCL variables, fabric proof, DGX Spark dual node, failure map.

## Companion skills

- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `nvidia-dgx-spark`, `disaggregated-serving`, `prefix-aware-routing`, `vllm`, `sglang`, `tensorrt-llm`, `llama-cpp`, `tensorfold`.
- Planned: `exo`, `ray-serve`, `kserve`, `dynamo`.

## License

MIT
