# Install Infinity

> Verified against infinity_emb 0.0.77 (README, Docker Hub michaelf34/infinity tags), 2026-10-11

## Docker (recommended upstream)

Images are `michaelf34/infinity` on Docker Hub. Tags seen on 2026-10-11: `0.0.77` and `latest` (CUDA), `0.0.77-cpu` and `latest-cpu`, `0.0.77-amd` and `latest-amd` (ROCm, MI200/MI300), `0.0.77-trt-onnx` and `latest-trt-onnx`. Upstream says the ROCm and TRT-ONNX images are not built by CI because of size, so pin an exact version for them. Blackwell support was announced in 2025/07.

```bash
install -d -m 700 ~/infinity && cd ~/infinity
umask 077; printf 'INFINITY_API_KEY=%s\nINFINITY_ANONYMOUS_USAGE_STATS=0\nHF_TOKEN=\n' "$(openssl rand -hex 24)" > infinity.env

docker run -d --name infinity --gpus all --env-file infinity.env \
  -v "$PWD/cache:/app/.cache" -p 127.0.0.1:7997:7997 \
  michaelf34/infinity:0.0.77 \
  v2 --model-id BAAI/bge-small-en-v1.5 --model-id mixedbread-ai/mxbai-rerank-xsmall-v1 --port 7997
```

The container cache path is `HF_HOME` (mounted at `/app/.cache` in the README example). CPU example from upstream:

```bash
docker run -d --name infinity -v "$PWD/cache:/app/.cache" -p 127.0.0.1:7997:7997 \
  michaelf34/infinity:0.0.77-cpu v2 --engine optimum --model-id BAAI/bge-small-en-v1.5 --port 7997
```

## pip

```bash
python3 -m venv ~/infinity/venv && . ~/infinity/venv/bin/activate
pip install 'infinity-emb[all]==0.0.77'
infinity_emb v2 --model-id BAAI/bge-small-en-v1.5 --host 127.0.0.1 --port 7997
```

Python 3.9 to 3.13 per `pyproject.toml`. Since 0.0.75 a bare `infinity_emb` defaults to the `v2` command. Apple Silicon uses `--device mps`.

## Local or air-gapped models

```bash
git lfs install && git clone https://huggingface.co/BAAI/bge-small-en-v1.5 models/bge-small-en-v1.5
docker run ... -v "$PWD/models:/models" michaelf34/infinity:0.0.77 v2 --model-id /models/bge-small-en-v1.5
```

`--preload-only` downloads and validates models, then exits; use it to pre-cache in a Dockerfile.

## Models

Tested in upstream CI (README): bge, gte, jina-embeddings v2/v3, e5, mxbai embedders, decoder embedders such as gte-Qwen2 (20 to 100 times slower than BERT-small), rerankers (bge-reranker-*, mxbai-rerank, gte-multilingual-reranker), CLIP/SigLIP, CLAP, ColBERT, ColPali, text classifiers. Qwen3-Embedding is not on the README list at the check date; test before depending on it.
