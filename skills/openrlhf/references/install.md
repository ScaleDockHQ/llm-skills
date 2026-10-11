# Installing OpenRLHF

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md, setup.py, requirements.txt, dockerfile/Dockerfile, PyPI), 2026-10-11

## Requirements

Python >= 3.10 (PyPI `requires_python`). `requirements.txt` pins `deepspeed==0.19.6` and `ray[default]==2.55.0`; extras: `vllm` pins `vllm==0.29.0` (recommended upstream), `vllm_latest` is `vllm>=0.29.0`, plus `ring` and `liger`. The project Dockerfile starts from `nvcr.io/nvidia/pytorch:26.03-py3` and installs `vllm==0.29.0 deepspeed==0.19.5 transformers==5.15.0`.

## Recommended: NGC container

```bash
docker run --runtime=nvidia -it --rm --shm-size="10g" --cap-add=SYS_ADMIN \
  -v $PWD:/openrlhf nvcr.io/nvidia/pytorch:26.03-py3 bash

# inside the container: remove packages that conflict with vLLM/DeepSpeed builds
pip uninstall xgboost transformer_engine flash_attn pynvml -y   # upstream README uses sudo pip

pip install openrlhf                    # basic
pip install 'openrlhf[vllm]'            # + vLLM 0.29.0 (recommended)
pip install 'openrlhf[vllm_latest]'     # + latest vLLM
pip install 'openrlhf[vllm,ring,liger]' # + RingAttention and Liger kernels
```

`--cap-add=SYS_ADMIN` widens container privileges; it is what upstream documents, so ask the user before using it on a shared host. Mounting `$PWD` writes checkpoints and logs to the host.

## From source

```bash
git clone https://github.com/OpenRLHF/OpenRLHF.git && cd OpenRLHF
git checkout v0.11.2          # pin a tag
pip install -e .
```

Other helpers: `dockerfile/`, `examples/scripts/nvidia_docker_install.sh`, `examples/scripts/docker_run.sh`.

## Ray environment on clusters

Let Ray install on job start: `--runtime-env-json='{"setup_commands": ["pip install openrlhf[vllm]"]}'`.

## Verify

```bash
python3 - <<'PY'
import importlib.metadata as m, torch
for p in ("openrlhf","vllm","deepspeed","ray","transformers"):
    print(p, m.version(p))
print("cuda", torch.cuda.is_available(), torch.cuda.device_count())
PY
python3 -m openrlhf.cli.train_ppo_ray --help | head -20
```
