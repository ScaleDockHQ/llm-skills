# Install TEI

> Verified against text-embeddings-inference v1.9.4 (README Docker Images table, docs quick_tour and supported_models), 2026-10-11

TEI ships as container images on `ghcr.io/huggingface/text-embeddings-inference`. Image tags are `<arch>-<minor>`, for example `89-1.9`. The tags below are the ones the upstream README lists for the 1.9 line; the latest release at the check date was v1.9.4. Re-read the README table before pinning, because arch tags change between minors.

## Pick the image

| Hardware                                                  | Tag                                                                                  |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| CPU x86_64                                                | `cpu-1.9`                                                                            |
| CPU aarch64                                               | `cpu-arm64-1.9`                                                                      |
| Turing (T4, RTX 2000), experimental                       | `turing-1.9` (Flash Attention off by default, `USE_FLASH_ATTENTION=True` enables v1) |
| Ampere 8.0 (A100, A30)                                    | `1.9`                                                                                |
| Ampere 8.6 (A10, A40, RTX 3000)                           | `86-1.9`                                                                             |
| Ada (RTX 4000, L4, L40)                                   | `89-1.9`                                                                             |
| Hopper (H100)                                             | `hopper-1.9`                                                                         |
| Blackwell 10.0 (B200), experimental                       | `100-1.9`                                                                            |
| Blackwell 12.0 (RTX 50 series), experimental              | `120-1.9`                                                                            |
| Blackwell 12.1 (DGX Spark GB10), experimental, multi-arch | `121-1.9`                                                                            |
| Volta, V100, GTX 1000                                     | unsupported (needs compute capability 7.5+)                                          |

The quick tour in the same docs also shows a `cuda-1.9` tag. It is not in the hardware table; use the table's arch tag unless you have checked that `cuda-1.9` exists for your release.

GPU hosts need the NVIDIA Container Toolkit and a driver supporting CUDA 12.2 or newer.

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
docker info --format '{{json .Runtimes}}' | jq 'keys'   # expect "nvidia"
```

## Run (Docker)

```bash
install -d -m 700 ~/tei && cd ~/tei
umask 077; printf 'API_KEY=%s\nHF_TOKEN=\n' "$(openssl rand -hex 24)" > tei.env   # HF_TOKEN only for gated models

docker run -d --name tei-embed --gpus all --env-file tei.env \
  -p 127.0.0.1:8080:80 -v "$PWD/data:/data" \
  ghcr.io/huggingface/text-embeddings-inference:89-1.9 \
  --model-id Qwen/Qwen3-Embedding-0.6B
```

The container listens on port 80 inside the image in the upstream examples (`-p 8080:80`). The binary's own default port is 3000, so a custom command line without the image entrypoint may differ; check `/info` and logs.

For a long-running setup use `templates/docker-compose.yml`.

## Local install

The upstream README documents a source build (Rust, CUDA toolkit for GPU) and Homebrew for Apple Silicon. Prefer the container on Linux. On a Mac, run TEI natively or use `infinity` or Ollama embeddings; there is no CUDA there.

## Air-gapped

Download weights with `git lfs` or `huggingface-cli`, mount the directory at `/data`, and pass `--model-id /data/<dir>`. Gated models also need `HF_TOKEN` at download time only.

## Models

Supported: BERT-family, NomicBERT, JinaBERT, XLM-RoBERTa, ModernBERT, MPNet, Qwen2, Qwen3, Gemma3 and Mistral-based embedders (for example `Qwen/Qwen3-Embedding-0.6B`, `BAAI/bge-*`, `nomic-ai/nomic-embed-text-v1.5`, `google/embeddinggemma-300m` which is gated). Rerankers: sequence-classification cross-encoders such as `BAAI/bge-reranker-large`, `BAAI/bge-reranker-base`, `Alibaba-NLP/gte-reranker-modernbert-base`. Check the current list in `docs/source/en/supported_models.md`; an unsupported architecture fails at startup.
