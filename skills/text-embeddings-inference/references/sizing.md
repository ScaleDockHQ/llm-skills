# Sizing TEI and the vectors it produces

> Verified against text-embeddings-inference v1.9.4 (docs supported_models, cli_arguments), 2026-10-11

Numbers here are planning estimates from arithmetic, not measurements. Measure on your hardware with `nvidia-smi` under load.

## GPU memory

```
VRAM ≈ weights + activations(max-batch-tokens) + CUDA context
weights (GB) ≈ parameters (B) × bytes per parameter   (fp16/bf16: 2)
```

- `Qwen/Qwen3-Embedding-0.6B` is listed upstream at 509M parameters: about 1.0 GB of fp16 weights.
- `Qwen/Qwen3-Embedding-4B` (4.02B): about 8 GB. `Qwen3-Embedding-8B` (7.57B): about 15 GB.
- BERT-base class (110M): about 0.2 GB. `bge-reranker-large` (about 560M): about 1.1 GB.
- Add roughly 1 to 3 GB for activations and context at the default `--max-batch-tokens 16384`, more for large hidden sizes. Treat that range as a starting guess and read real usage.

Next to a chat model, reserve the embedder's total from the LLM's memory budget (for vLLM `--gpu-memory-utilization`), or the LLM's allocator will starve it.

## Vector storage

```
raw bytes = vectors × dimensions × bytes per element   (float32: 4, float16: 2, int8: 1, binary: dims/8)
```

| Vectors | Dim  | float32 | Note                                    |
| ------- | ---- | ------- | --------------------------------------- |
| 1M      | 384  | 1.5 GB  | small BERT models                       |
| 1M      | 1024 | 4.1 GB  | Qwen3-Embedding-0.6B outputs up to 1024 |
| 1M      | 4096 | 16.4 GB | 8B-class embedders                      |

Add index overhead (HNSW graph roughly tens of percent more, depends on `m`) and plan for the whole index to be in RAM unless the store memory-maps it. See the vector store skills for their exact overhead and quantization options.

## Throughput levers

- Larger `--max-batch-tokens` and client batches improve ingest throughput.
- Smaller dimensions (models trained with Matryoshka representations can be truncated) cut storage, but truncate only if the model card allows it.
- CPU images work for small models; expect much lower throughput than GPU.
