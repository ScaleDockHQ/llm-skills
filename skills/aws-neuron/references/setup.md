# Setup: DLAMI, DLC and manual install

> Verified against Neuron docs (Neuron DLAMI User Guide, Getting started with Neuron DLC using Docker, NxD Inference setup), aws-neuron/deep-learning-containers README, vllm-neuron release-0.24.0.1.1.0 setup guide, Neuron SDK 2.32.0, 2026-10-11

## Option A: Neuron DLAMI (preferred)

Neuron DLAMIs ship the driver, runtime, compiler, frameworks and tools. From the DLAMI guide:

- Multi-Framework DLAMI on Ubuntu 24.04 supports Inf2, Trn1, Trn1n, Trn2 and Trn3, with a vLLM virtual environment at `/opt/aws_neuronx_venv_pytorch_inference_vllm_0_24_0_1_1_0` (vLLM 0.24.0, vllm-neuron 0.24.0.1.1.0).
- Single-framework DLAMI "PyTorch Inference vLLM 0.24.0.1.1.0 (Ubuntu 24.04)" supports Trn2 and Trn3 only.
- Amazon Linux 2023 DLAMIs no longer support PyTorch 2.9+ (GLIBC 2.35 requirement), so the vLLM environment is not available there; use Ubuntu.
- Inf1 is not supported by Neuron DLAMIs from 2.26.1.

Find the latest AMI id with SSM instead of hardcoding it. List the available parameter prefixes first:

```bash
aws ssm get-parameters-by-path --path /aws/service/neuron/dlami --recursive --query 'Parameters[].Name' --output text | tr '\t' '\n' | head -40
aws ssm get-parameter --name <prefix-from-the-list>/latest/image_id --query Parameter.Value --output text
```

Launch only after the user approves instance type, region, subnet, key pair, security group and an EBS size (Neuron's docs suggest at least 512 GB for Trn1 and large models). Do not open port 8000 to the internet.

```bash
source /opt/aws_neuronx_venv_pytorch_inference_vllm_0_24_0_1_1_0/bin/activate
neuron-ls
python -c "import vllm; from vllm.platforms import current_platform; print(current_platform.device_name)"   # expect: neuron
```

The vllm-neuron repo's setup guide still shows the 0.21.0 venv path in places; `ls /opt | grep aws_neuronx_venv` shows what is actually installed.

## Option B: Deep Learning Container

`aws-neuron/deep-learning-containers` publishes `vllm-inference-neuronx` images on public ECR. For Neuron 2.32.0 (verified in the README table):

- `public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.24.0.1.1.0-neuronx-py313-sdk2.32.0-ubuntu24.04` (Trn2, Trn3)
- `public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.16.0-neuronx-py312-sdk2.31.1-ubuntu24.04` (Trn1, Trn2, Trn3, Inf2; the NxD Inference line)

Run on a host that already has the Neuron driver, passing devices explicitly:

```bash
docker run -it --rm --net=host \
  $(for d in /dev/neuron*; do printf -- '--device=%s ' "$d"; done) \
  --shm-size=16g \
  -e HF_TOKEN \
  public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.24.0.1.1.0-neuronx-py313-sdk2.32.0-ubuntu24.04 bash
```

Inside, `neuron-ls` shows only the devices you passed. Choose how many devices to pass for the TP size you need. The `--shm-size`, entrypoint and any extra capabilities are not specified in the README table; check the image's Dockerfile on GitHub for the tag you pin.

## Option C: Manual install

Only when a DLAMI or DLC does not fit. Install the Neuron driver, runtime and tools from the Neuron repositories per https://awsdocs-neuron.readthedocs-hosted.com/en/latest/ for your OS, then install the plugin (the plugin does not install `neuronxcc`, `torch_neuronx` or `nki`):

```bash
git clone -b release-0.24.0.1.1.0 https://github.com/vllm-project/vllm-neuron.git
cd vllm-neuron && pip install --extra-index-url=https://pip.repos.neuron.amazonaws.com -e .
```

Requirements per the plugin guide: Neuron SDK 2.31 or later, Python 3.11 or later. Reinstall the driver (`aws-neuronx-dkms`) after any kernel update, and reboot after driver installation if `neuron-ls` shows nothing.

## Verify

```bash
neuron-ls
python -c "import vllm; from vllm.platforms import current_platform; print(current_platform.device_name)"
pip show vllm-neuron | sed -n '1,3p'
```
