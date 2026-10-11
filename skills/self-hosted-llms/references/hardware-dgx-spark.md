# Hardware: NVIDIA DGX Spark

> Verified against NVIDIA DGX Spark user guide and dgx-spark-playbooks (main), 2026-10-11

This page keeps the memory-budget formula the decision flow uses. Hardware, OS, networking, dual-node setup and troubleshooting live in the platform skill.

Depth: install the nvidia-dgx-spark skill (`npx skills add ScaleDockHQ/llms-skills --skill nvidia-dgx-spark`).

## Memory budgeting

Per node, before loading:

```text
weights (file size of the quantized checkpoint)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_seqs
+ runtime overhead (CUDA graphs, activations, engine buffers: measure, start with several GB)
+ OS + services headroom (desktop, Docker, LiteLLM, page cache pressure: keep a large margin)
<= 128 GB
```

Read `layers`, `num_key_value_heads` and `head_dim` (or `hidden_size / num_attention_heads`) from
the model's `config.json`. FP8 KV cache halves the KV term (a numerics change: see
`optimization.md`). Measure the real peak with `free -m` sampled during a long-context request,
not the number the engine prints at startup.

Co-resident models (a non-exclusive llama-swap group) must fit **together**, at their peaks.

## Known pitfalls

- Treating `nvidia-smi` memory as truth: it is not reported on this platform.
- Memory fractions tuned on a discrete GPU (0.90+) starve the OS on unified memory.
- Building engines from source while serving: the build can take the box down. Stop serving first.
- Different images on node-a and node-b behind the same tag.
- Assuming the 10 GbE port is the inter-node link: NCCL must be pointed at the ConnectX-7 interface.

## Official links

- [DGX Spark user guide](https://docs.nvidia.com/dgx/dgx-spark/index.html)
- [DGX Spark known issues](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)
- [DGX Spark playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)
- [Connect two Sparks](https://build.nvidia.com/spark/connect-two-sparks)
