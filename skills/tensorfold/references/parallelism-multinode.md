# TensorFold: concurrency and multi-node

> Verified against TensorFold v1.0.7, 2026-10-11

README, RUNBOOK.md, docs/api.md, MiaAI-Lab Flash dual recipe

## One node: lanes

Engines that share lanes serve several streams per decode round. `--parallel N` admits up to N requests; `auto` is the default. Nemotron, GLM, Qwen3.5-2B and Qwen3.8-27B use shared lane rounds; **Flash Next runs one active reply per engine**. Each concurrent stream must equal its solo run (exactness gate). The 27B's DFlash2 drafter drafts for one stream at a time: a lone request, or the one in the drafter's slot when several share rounds. 1.0.5 notes: `--parallel 32` and `64` use about 3 GiB more memory than 8 for Nemotron on Metal.

There is no tensor parallelism flag in the 1.0.7 README table for the release archives. Multi-node paths that exist are below.

## Two Macs (Flash Next or GLM-5.3-Flash, Metal)

Qualified GLM setup: two M5 Ultras, same checkpoint, one settings file per rank (`--speed-up rank0.json` / `rank1.json`), a separately built MCDMA runtime library. Each settings file names `rank`, `library` and `links`; each link names its peer, RDMA device, interface/address, ports and link name. The schema is in `docs/speed-up-mode.md` upstream (section 5); not reproduced here.

```bash
# rank 1 first, on its own Mac
bin/tensorfold-native serve "$HOME/models/glm-5.3-flash" --speed-up rank1.json --context 8192 --temperature 0 --no-thinking
# then rank 0, which takes the requests
bin/tensorfold-native serve "$HOME/models/glm-5.3-flash" --speed-up rank0.json --name local-model --context 8192 --temperature 0 --no-thinking
```

Rules from the runbook: start rank 1 first; run the **same release** on both Macs (a Mac refuses a peer from an earlier release); send requests to rank 0; on macOS run both servers attached to a session or allow Local Network access. With `--learn`, states learned by an earlier release are refused and learned again. Flash Next waits at most 10 s for a missing handoff (1.0.5) instead of hanging. On one Mac, GLM loads only if weights and caches fit in 70% of RAM (`GLM_LOAD_LIMIT_GB` overrides, up to the GPU's recommended working set); past 70% it warns, and a load wiring most RAM can stall macOS until its watchdog restarts the Mac.

## Two NVIDIA nodes

The native 1.0.7 archives list no multi-node CUDA path. Two-GPU CUDA work in the project is the Python 0.6.6 engine (families with "one or two ranks", `docs/recipes/cuda.md`) and the community Flash Next recipe, which builds the Zig engine from the `zig-flashnext` branch and runs `--tp 2 --rank R` over RoCE. Details and pitfalls: `combos/dgx-spark-dual.md`. Open issue #665 (upstream) reports asymmetric two-rank watchdog deadlines: a legal prefill longer than 300 s can kill both ranks because the follower waits a fixed `TF_TP_TIMEOUT_S`. Treat very long prompts on two ranks as risky until fixed (check the issue).

For general multi-node concerns (NCCL, RoCE, switchless rings) use `multi-node-inference` and `nvidia-dgx-spark`.
