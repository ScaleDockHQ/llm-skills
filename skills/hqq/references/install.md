# Installing HQQ

> Verified against hqq v0.2.8.post1 (README, PyPI, GitHub releases), 2026-10-11

- Project: https://github.com/dropbox/hqq (the former `mobiusml/hqq` address redirects). Apache-2.0. Latest release `v0.2.8.post1` (2025-10-20); `master` last updated 2026-02-26 (a solver fix). Not archived.
- PyPI `hqq` requires numpy, tqdm, einops, accelerate, `transformers>=4.36.1`, huggingface_hub, termcolor.

```bash
python3 -m venv ~/venvs/hqq && . ~/venvs/hqq/bin/activate
# install a PyTorch 2 build that matches the CUDA version first (https://pytorch.org)
pip install hqq                                  # latest stable
pip install git+https://github.com/dropbox/hqq.git   # upstream recommends this for the latest updates
DISABLE_CUDA=1 pip install hqq                   # skip building the aten CUDA kernels
python3 -c "import hqq; from hqq.core.quantize import HQQLinear; print('ok')"
```

Ask before installing. A source build compiles CUDA kernels for the `ATEN` backend; skip it with `DISABLE_CUDA=1` when you only need the PyTorch, GemLite or torchao backends. Intel XPU works with the pure PyTorch implementation.

Optional fast-inference packages: `gemlite` (https://github.com/dropbox/gemlite) for `backend="gemlite"` and for vLLM on-the-fly use; `torchao` for `backend="torchao_int4"` (`torchao` skill).
