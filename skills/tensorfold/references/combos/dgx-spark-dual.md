# TensorFold on two DGX Sparks (Qwen3.8-Flash-Next, TP=2)

> Verified against MiaAI-Lab/Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold (pushed 2026-10-08; image `zig-db28187`; Zig 0.17.0; `nvcr.io/nvidia/pytorch:26.07-py3`) and TensorFold v1.0.7, 2026-10-11

This is the one verified two-Spark TensorFold setup. It is a community recipe (credit: MiaAI-Lab, with the Zig CUDA serving path by Jürgen Schmied in TensorFold PR #443). It does not use the 1.0.7 archive, and the 1.0.7 README lists no multi-node CUDA support. I did not run it; everything below is from its README.

## What it serves

Qwen3.8-Flash-Next across two GB10 Sparks (one rank each) linked by ConnectX-7, OpenAI-compatible, 1,048,576-token context (YaRN over native 262,144), up to 16 requests, FP8 KV by default, image and video input, tool calls. Model ID `Qwen3.8-Flash-Next` (`Qwen3.8-Flash-Next-INT4-AR` with `QUANT=int4ar`). Checkpoints: `nvidia/Qwen3.8-Flash-Next-NVFP4` at revision `fc694b54` (about 124 GiB) or `azampatti/Qwen3.8-Flash-Next-125B-A5B-INT4-AutoRound` (about 122 GiB, 5 experts a token instead of 10, authors report about 10% lower general capability). The README's measured numbers (sparkDash, 2026-10-07): NVFP4 67.4 tok/s alone, 390 aggregate at 16; INT4-AR 89.3 alone, 484 at 16. Measure yours.

## Requirements (from the README)

- Two DGX Sparks (or GB10 systems with 128 GB), nothing else large on either GPU. `MemAvailable` needed at start: about 102 GiB at the default 1M window, about 72 GiB at 262,144 (`MEM_NEED_GIB`; `start.sh` stops below it).
- Direct ConnectX-7 cable and an IPv4 address on each end in one private subnet (e.g. `192.0.2.1/24` and `.2/24`), `ping` working, RoCE v2 GID present. One QSFP port appears as two netdevs / RoCE devices (`enp1s0f0np0` / `enP2p1s0f0np0`, `rocep1s0f0` / `roceP2p1s0f0`); address both twins for two NCCL rails (about 112 Gb/s per rail).
- Key-based ssh from the head (runs `start.sh` and the API) to the worker (`ssh -o BatchMode=yes user@worker true`).
- Docker with NVIDIA runtime, user in `docker`, `rsync`, on both. About 150 GB per Spark (checkpoint + image; 35 GB for the image).
- Optional `hf` CLI and a Hugging Face token (the checkpoint is public).

## Run

```bash
git clone https://github.com/MiaAI-Lab/Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold.git && cd Qwen3.8-Flash-Dual-DGX-Sparks-TensorFold
cp scripts/local.sh.example scripts/local.sh   # set WORKER=user@192.0.2.2 (and FABRIC_PEER if on another network)
HOST=127.0.0.1 ./start.sh                      # sets up both nodes first time, then starts both ranks, smoke test
./start.sh restart    ./stop.sh
docker logs -f qwen38-fn-tf                    # rank 0; worker: ssh <worker> docker logs -f qwen38-fn-tf
curl -fsS http://127.0.0.1:8888/health
```

`start.sh` steps: setup via `scripts/prepare.sh` (image on both nodes pulled from `ghcr.io/miaai-lab/qwen3.8-flash-dual-dgx-sparks-tensorfold:zig-db28187-<hash>` by pinned digest, or built from `TF_REF` on branch `zig-flashnext` with `patches/*.patch`), checks (args, link, port, memory), launch rank 1 on the worker over ssh then rank 0, load (progress every 15 s, aborts if free memory falls below `MEM_FLOOR_GIB`=10), smoke test. The engine command is `tensorfold-native serve <snapshot> --name ... --context N --parallel N --kv-dtype ... [--vision ...] [--no-drafts] --tp 2 --rank R --master <head link address> --master-port 29551`, with NCCL on the RoCE devices. Extra arguments go after defaults and win. `DRY_RUN=1 ./start.sh` prints both `docker run` commands. `FOREGROUND=1 ./start.sh` attaches for systemd, exits with rank 0's code and stops the other rank. Later starts load half the weights per Spark in about two minutes.

## Weights on the worker

`WORKER_WEIGHTS=copy` (default) rsyncs the checkpoint to the worker. `WORKER_WEIGHTS=nfs` (the example local config) makes the worker read the head's HF cache over read-only NFS: on the head `sudo apt install nfs-kernel-server`, export `~/.cache/huggingface` to the worker's CX7 address with `(ro,no_subtree_check)`, `sudo exportfs -ra`; `prepare.sh` makes a read-only docker NFS volume (`nfsvers=4.2,ro,nconnect=8,...`). For `fsid=0` exports set `NFS_PATH`.

## Key settings (from `scripts/config.sh` table)

`QUANT` (`nvfp4`), `CONTEXT` (1048576; `262144` avoids YaRN and needs less memory), `PARALLEL` (16, range 1 to 16), `MAX_TOKENS` (32768), `THINKING` (1), `DRAFTS` (1), `KV_DTYPE` (`fp8`; `bf16` exact), `VISION`/`VISION_URLS` (1/0), `TENSORFOLD_MEMORY_RESERVE_GIB` (10), `PORT` 8888, `HOST` 0.0.0.0, `WAIT_TIMEOUT` 1800, `LOG_DIR` `~/.cache/tensorfold-qwen38fn/logs`, `LOG_KEEP` 10. Settings come from environment, then `scripts/local.sh`, then `.env`, then defaults. Any `TENSORFOLD_*`, `TF_FLASHNEXT_*`, `TF_TP_*`, `TF_CUDA_*` variable is passed to both ranks; `TENSORFOLD_API_KEY` goes to rank 0 by name only. `HF_HUB_OFFLINE=0` lets the server reach the Hub (default: local cache only). The checkpoint revision is pinned (`MODEL_REVISION`).

## Memory

Engine on GPU after load about 69 GiB (NVFP4) per rank; KV pool 26.5 GiB (about 3.9M tokens FP8; INT4-AR 31 GiB, 4.6M); three full 1M-token conversations at once. The pool is the smaller of the two Sparks' free memory, so other work on either shrinks it. Unified memory tends to freeze the machine rather than fail an allocation, hence the pre-launch checks (`MEM_CHECK=0` turns the stop into a warning: avoid). Prefill briefly holds about 31 GiB per rank for a million tokens.

## API limits of this build

Native Zig server routes: `/v1/chat/completions`, `/v1/completions`, `/v1/responses`, `/v1/messages`, `/v1/models`, `/tokenize`, `/detokenize`, `/health`, `/stats`, `/metrics`. Refused with HTTP 400: `logprobs`/`top_logprobs`, `n` other than 1, structured outputs (`response_format`, `guided_*`). Tool calls work including `tool_choice: required`. Images (JPEG, PNG, WebP; up to 50) and video (up to 4; MP4, WebM, MOV, MKV) via `image_url`/`video_url` data URLs; public URLs only with `VISION_URLS=1`; media prompts are not kept for prefix reuse.

## Troubleshooting `start.sh` stops

| Message                                                                         | Fix                                                                                                                           |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `only N GiB memory available`                                                   | Stop other GPU work (`docker ps`), restart.                                                                                   |
| `no RoCE device or RoCE v2 GID for the link` / `no route from this node to ...` | Route to the worker is not over CX7: set `FABRIC_PEER` to the worker's CX7 address; check both ends addressed (`ip -4 addr`). |
| `the worker's .../hub is not writable`                                          | A container left it root-owned; fix ownership on the worker.                                                                  |
| `... has no kernel set`                                                         | Image built without compiled kernels; rebuild (`scripts/prepare.sh --rebuild`) and read "kernel set" in the README.           |

Rank crash: `stop.sh` and `start.sh` save each rank's log gzipped (`zcat`/`zless`); attach both to reports. Upstream issue #665 (follower fixed timeout) is a risk for prompts that prefill over 300 s on two ranks.

## Pitfalls and gaps

- Defaults bind `0.0.0.0` on 8888: set `HOST=127.0.0.1` behind a gateway and check `ss -ltnp`.
- Needs matching images on both nodes, key-based ssh and a RoCE-capable link; recipes assume nothing else on the GPUs.
- Network bring-up of CX7/netplan, MTU and NCCL tuning are covered by `nvidia-dgx-spark` and `multi-node-inference`, not verified here.
- Not verified: behaviour with TensorFold 1.0.x archives on two nodes (none documented).
