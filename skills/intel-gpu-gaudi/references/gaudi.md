# Gaudi

> Verified against Intel Gaudi software 1.24.2 docs, vllm-gaudi 0.26.0 README and quickstart, 2026-10-11

## Software release

Release notes name 1.24.2 (build 1.24.2-481) as the latest. It refreshes components with security fixes and adds RHEL 10.2 on Gaudi 3, OpenShift 5.0 and the FP8 Dynamic model. It drops Slurm, Megatron-LM, the BMC exporter probe endpoint and media support. Known issue in 1.24.2: the Ubuntu 24.04 PyTorch installer and vLLM images (and RHEL vLLM images) include a Setuptools version flagged for CVE-2026-59890.

From 1.24.0 notes: `torch.compile` with Eager mode is the default; models that need Lazy mode set `PT_HPU_LAZY_MODE=1`, and Lazy mode is to be deprecated. Enabling IOMMU passthrough is required only for Ubuntu 24.04.2 or 22.04.5 with kernel 6.8. On kernels 5.9 and newer (for example Ubuntu 22.04.5) the notes say to add `intel_idle.max_cstate=0` to the kernel command line.

## Check the host

```bash
hl-smi                                     # every accelerator visible
dpkg -l | grep habana                      # firmware-tools, graph, rdma-core, thunk, container-runtime
pip list 2>/dev/null | grep -i habana      # habana-torch-plugin, habana-media-loader, ...
dmesg | grep -i habana | tail
```

Install steps for drivers and firmware are in the Gaudi Installation Guide (docs.habana.ai); ask before running them.

## Register the container runtime

Docker: add the `habana` runtime to `/etc/docker/daemon.json` (path `/usr/bin/habana-container-runtime`), optionally set `"default-runtime": "habana"`, then `sudo systemctl restart docker`. containerd and CRI-O have their own snippets in the Docker Installation page. Merge with existing config; do not overwrite it blindly.

## Prebuilt images

Intel publishes prebuilt images for Ubuntu 24.04.3 and 22.04.5 only, from `vault.habana.ai`:

```bash
docker pull vault.habana.ai/gaudi-docker/1.24.2/ubuntu24.04/habanalabs/pytorch-installer-2.13.0:latest
docker run -it --runtime=habana -e HABANA_VISIBLE_DEVICES=all \
  -e OMPI_MCA_btl_vader_single_copy_mechanism=none -v /opt/datasets:/datasets \
  --cap-add=sys_nice --net=host --ipc=host \
  vault.habana.ai/gaudi-docker/1.24.2/ubuntu24.04/habanalabs/pytorch-installer-2.13.0:latest
```

`--ipc=host` is needed for HCCL multi-card work. SSH host keys are not in the images (since 1.18.0); run `/usr/bin/ssh-keygen -A` inside if you need them. Using fewer cards than the host has needs the device-to-module mapping set correctly (see the "Multiple Dockers Each with a Single Workload" page).

## vLLM on Gaudi

The `HabanaAI/vllm-fork` README says the fork reaches end of life from Gaudi 1.23.0 and is deprecated in 1.24.0; the 1.24.0 release notes state it "reached end of life and is no longer supported". Use the community plugin `vllm-project/vllm-gaudi`.

Compatibility from the release notes: Gaudi 1.24.0 works with plugin 0.17.1, 0.19.0, 0.19.1 and 0.21.0. Gaudi 1.24.1 works with 0.24.0 and 0.26.0; plugin 0.26.0 is built on vLLM 0.26.0 with PyTorch 2.11. The plugin quickstart requires Python 3.10, Gaudi 2 or 3, and Gaudi software 1.24.2 or later, on Ubuntu 22.04/24.04 or RHEL 9.4/9.6.

Quickstart (container, from the plugin repo):

```bash
git clone https://github.com/vllm-project/vllm-gaudi.git && cd vllm-gaudi
git checkout <TAG_OR_BRANCH>      # a release tag from the releases page
cd .cd
MODEL="Qwen/Qwen2.5-14B-Instruct" \
HF_TOKEN="$(cat ~/.config/hf/token)" \
DOCKER_IMAGE="vault.habana.ai/gaudi-docker/1.24.2/ubuntu24.04/habanalabs/vllm-0.30.0-ptupstream-2.13.0:latest" \
docker compose up
```

Read the token from a `0600` file as shown; do not paste it into the command. The image tag above is the one in the quickstart; check the Gaudi vault listing before pinning another.

From source: the plugin README installs upstream vLLM at the commit stored in the `vllm/last-good-commit-for-vllm-gaudi` branch (`VLLM_STABLE_COMMIT`) with `VLLM_TARGET_DEVICE=empty`, then `pip install -e .` in `vllm-gaudi`.

Multi-card: with `TP*PP*DP > 1` vLLM uses the `mp` executor. The platform layer overrides `VLLM_WORKER_MULTIPROC_METHOD` to `spawn`, because forking after HPU init can hang on exit; leave it.

Validated model/TP sizes in the quickstart include Llama-3.1-8B (TP1), Llama-3.1-70B (TP4), Llama-3.1-405B (TP8), Qwen2.5-72B (TP4) and Qwen3-30B-A3B-Instruct-2507 (TP1). The list is not exhaustive.
