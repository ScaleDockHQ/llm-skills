# Installing TensorRT-LLM

> Verified against TensorRT-LLM v1.2.1 (docs at tag v1.2.1 and `main`), NGC `nvcr.io/nvidia/tensorrt-llm/release` tags 1.2.1 and 1.3.0rc29, NVIDIA/dgx-spark-playbooks `nvidia/trt-llm`, 2026-10-11

## Pick a channel

| Channel                    | Example                                                     | Use when                                                         |
| -------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| Stable release container   | `nvcr.io/nvidia/tensorrt-llm/release:1.2.1`                 | Default. PyPI also carries 1.2.1 as the latest non-pre version.  |
| rc release container       | `nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc29`             | A model or feature needs the newer line (Dynamo, Spark recipes). |
| Nightly container          | tags with `.dev`, e.g. `1.3.0rc29.dev202609290000`          | Early access, quality not guaranteed.                            |
| pip wheel                  | `pip3 install tensorrt_llm`                                 | You manage CUDA, PyTorch and MPI yourself.                       |
| `devel` container / source | `nvcr.io/nvidia/tensorrt-llm/devel:x.y.z`, `build_wheel.py` | You modify TensorRT-LLM or need a custom CUDA arch list.         |

Upstream's current docs say rc tags publish weekly from `main` and the monthly QA-tested release has no `rcN` suffix. At writing the NGC stable tags are `1.0.0`, `1.1.0`, `1.2.0`, `1.2.1`; the rc tags run up to `1.3.0rc29`; `main` reports `1.4.0rc0` (nightly tags `1.4.0rc0.dev...`).

List tags without a login (read-only):

```bash
T=$(curl -s "https://nvcr.io/proxy_auth?scope=repository:nvidia/tensorrt-llm/release:pull" | jq -r .token)
curl -s -H "Authorization: Bearer $T" https://nvcr.io/v2/nvidia/tensorrt-llm/release/tags/list \
  | jq -r '.tags | map(select(test("^1\\.[0-9]+\\.[0-9]+(rc[0-9]+)?$"))) | sort | .[-12:] | join(" ")'
# platforms of a tag (1.2.1 and 1.3.0rc29 list amd64 and arm64):
curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.oci.image.index.v1+json" \
  https://nvcr.io/v2/nvidia/tensorrt-llm/release/manifests/1.2.1 | jq -c '[.manifests[]?.platform.architecture]'
```

## Linux x86_64 (NGC container)

Prerequisites: an NVIDIA driver (the gpt-oss deployment guide states 575 or later; Dynamo's matrix lists 580+ for its image built on TensorRT-LLM 1.3.0rc22 and CUDA 13.1; the minimum for the 1.2.1 image itself is unverified, read its NGC page), Docker, and the NVIDIA Container Toolkit.

```bash
docker pull nvcr.io/nvidia/tensorrt-llm/release:1.2.1
docker run --rm -it --ipc host --gpus all --ulimit memlock=-1 --ulimit stack=67108864 \
  -p 127.0.0.1:8000:8000 nvcr.io/nvidia/tensorrt-llm/release:1.2.1
# inside the container
python3 -c "import tensorrt_llm; print(tensorrt_llm.__version__)"
printenv TRT_LLM_GIT_COMMIT            # source commit recorded in the image
```

`--ipc=host` (or a large `--shm-size`) is required: upstream states it avoids `Bus error (core dumped)`. Mount `~/.cache/huggingface` at `/root/.cache/huggingface` to keep downloads. The release image contains the examples under `/app/tensorrt_llm/examples` and a PyTorch-NGC-compatible wheel under `/app/tensorrt_llm`.

## Linux arm64 and NVIDIA DGX Spark (GB10)

The 1.2.1 and 1.3.0rc29 tags are multi-arch (amd64 + arm64), so the same pull works on a Spark. DGX Spark is on upstream's supported hardware list (Blackwell: B200, GB200, B300, GB300, DGX Spark).

NVIDIA's playbook (single node) at writing:

```bash
export DOCKER_IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc13"   # playbook pin; rc5 in its two-node section
docker run --rm --gpus all "$DOCKER_IMAGE" nvidia-smi                 # GPU visible?
```

Spark specifics, all from the playbook or this repo's earlier notes:

- Unified memory: GPU and CPU share the 128 GB pool. `kv_cache_config.free_gpu_memory_fraction` is a fraction of what is free after weights, and the OS needs headroom; the playbook uses 0.8 to 0.9 for a single model, 0.8 for the Nemotron Omni recipe.
- If memory pressure persists with a model that should fit, flush the page cache: `sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'` (needs approval).
- Weight loading OOM on some models: `export TRT_LLM_DISABLE_LOAD_WEIGHTS_IN_PARALLEL=1` (playbook, Nemotron Super 49B).
- Triton kernel compilation errors (`ptxas fatal`): set `TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas` (the two-node container sets it; also `CPATH=/usr/local/cuda/include`).
- `PYTORCH_ALLOC_CONF=expandable_segments:True` is used in the playbook's Nemotron Omni recipe.
- gpt-oss needs tiktoken encodings. The playbook downloads `o200k_base.tiktoken` and `cl100k_base.tiktoken` from `openaipublic.blob.core.windows.net/encodings/` into a directory and sets `TIKTOKEN_ENCODINGS_BASE`. Pre-fetch them and mount the directory.
- GB10 reports compute capability 12.1 (check with `nvidia-smi --query-gpu=compute_cap --format=csv`); upstream's quantization table names sm100/103 and sm120, so which FP4 kernels an image selects on GB10 is not documented: read the startup log. (unverified)
- Memory hygiene and the OS side of GB10 live in the `nvidia-dgx-spark` skill (`npx skills add ScaleDockHQ/llm-skills --skill nvidia-dgx-spark`).

### Dual DGX Spark (two nodes over ConnectX-7)

NVIDIA's playbook, condensed (read the playbook for IPs and interface names on your hosts):

1. Network the two Sparks (CX7 links) and note the interface names (the playbook uses `enp1s0f0np0` and `enp1s0f1np1`).
2. Create `~/openmpi-hostfile` on the primary with both nodes' IPs, one per line.
3. On **each** node start a long-running container on host networking:

```bash
docker run -d --rm --name trtllm-multinode --gpus '"device=all"' --network host \
  --ulimit memlock=-1 --ulimit stack=67108864 --device /dev/infiniband:/dev/infiniband \
  -e UCX_NET_DEVICES="enp1s0f0np0,enp1s0f1np1" \
  -e NCCL_SOCKET_IFNAME="enp1s0f0np0,enp1s0f1np1" \
  -e OMPI_MCA_btl_tcp_if_include="enp1s0f0np0,enp1s0f1np1" \
  -e OMPI_MCA_orte_default_hostfile="/etc/openmpi-hostfile" \
  -e OMPI_MCA_rmaps_ppr_n_pernode="1" \
  -e OMPI_ALLOW_RUN_AS_ROOT="1" -e OMPI_ALLOW_RUN_AS_ROOT_CONFIRM="1" \
  -e CPATH=/usr/local/cuda/include -e TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas \
  -v ~/.cache/huggingface/:/root/.cache/huggingface/ -v ~/.ssh:/tmp/.ssh:ro \
  nvcr.io/nvidia/tensorrt-llm/release:1.3.0rc5 \
  sh -c "curl https://raw.githubusercontent.com/NVIDIA/dgx-spark-playbooks/refs/heads/main/nvidia/trt-llm/assets/trtllm-mn-entrypoint.sh | sh"
```

The entrypoint script comes from the playbook repo; review it before piping it into `sh`, or vendor a pinned copy. Then `docker cp ~/openmpi-hostfile trtllm-multinode:/etc/openmpi-hostfile` on the primary, and serve with `mpirun ... trtllm-llmapi-launch trtllm-serve` (see `parallelism-multinode.md`). The UCX warning about one CX7 port being unavailable is harmless if inference works.

## Linux pip

Upstream tests Ubuntu 24.04 and Python 3.12 (Dynamo's docs add that TensorRT-LLM does not support Python 3.11).

At tag v1.2.1:

```bash
# CUDA Toolkit 13.1 installed, CUDA_HOME set (cuda-compat-13-1 may be needed for older drivers)
pip3 install torch==2.9.1 torchvision --index-url https://download.pytorch.org/whl/cu130
sudo apt-get -y install libopenmpi-dev
sudo apt-get -y install libzmq3-dev           # only for disaggregated serving
pip3 install --ignore-installed pip setuptools wheel && pip3 install tensorrt_llm
```

On `main` (1.4 line) the prerequisites moved (CUDA Toolkit 13.4, `torch==2.14.0` from the cu132 index, plus a step to uninstall earlier `nvidia-cutlass-dsl*` packages), so re-read the installation guide that matches your wheel version. The PyPI wheel is built against public PyTorch; it can clash with the NGC PyTorch container, in which case use the wheel inside the release container's `/app/tensorrt_llm`.

Known pip problems from the guide:

- pip replaces a CUDA 13 torch with a CUDA 12 one (seen on Ubuntu 22.04). Constrain it:

```bash
echo "torch==$(python3 -c 'import torch; print(torch.__version__)')" > /tmp/torch-constraint.txt
pip3 install tensorrt_llm -c /tmp/torch-constraint.txt
```

- Slurm with Open MPI not built `--with-slurm`: "The application appears to have been direct launched using srun, but OMPI was not built with SLURM support". Reconfigure MPI with your admin.
- Open MPI 5 with a long hostname (Kubernetes pods): `mpi4py.MPI.Exception: MPI_ERR_UNKNOWN: unknown error`. Workaround in the `main` docs: `export PMIX_HOSTNAME=trtllm-node` (any short string).

Nightly wheels (1.4 line docs):

```bash
pip3 index versions tensorrt_llm --pre --index-url https://pypi.nvidia.com/trtllm_nightly/
pip3 install "tensorrt_llm==<version>" --extra-index-url https://pypi.nvidia.com/trtllm_nightly/
```

## Building from source and custom images

- `devel` image (no source, no wheel): mount a checkout and build inside; follow upstream's build-from-source guide.
- Local images need about 63 GB free disk: `make -C docker build` (devel) or `make -C docker release_build` (optionally `CUDA_ARCHS="89-real;90-real"` to cut compile time). Always run containers with `--ipc=host`.
- Enroot for Slurm: `make -C enroot build_sqsh`, then `make -C enroot run_sqsh`.
- Dynamo layers its runtime on the upstream release image; see `combos/dynamo.md`.

## Other platforms

macOS, Windows (native) and AMD or Apple GPUs have no documented path; the supported hardware page lists only NVIDIA architectures. WSL2 is not documented upstream (unverified). Use `llama-cpp`, `mlx` or `vllm` there.

## Verify

```bash
docker run --rm --gpus all nvcr.io/nvidia/tensorrt-llm/release:1.2.1 python3 -c "import tensorrt_llm, torch; print(tensorrt_llm.__version__, torch.cuda.is_available())"
```

## Official links

- Installation guide: https://nvidia.github.io/TensorRT-LLM/installation/installation-guide.html
- Containers: https://nvidia.github.io/TensorRT-LLM/installation/containers.html
- NGC release tags: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/tensorrt-llm/containers/release/tags
- Supported hardware: https://nvidia.github.io/TensorRT-LLM/supported-hardware.html
- DGX Spark playbook: https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/trt-llm
