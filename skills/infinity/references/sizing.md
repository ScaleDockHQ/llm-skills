# Sizing Infinity

> Verified against infinity_emb 0.0.77 (README), 2026-10-11

Planning estimates only; measure with `nvidia-smi` under load.

```
VRAM per model ≈ parameters × bytes (fp16: 2) + activations(batch-size × seq len) + framework overhead
```

- Models share the GPU in one process: sum the weights of every `--model-id`, then add roughly 1 to 2 GB overhead per model as a guess.
- bge-small (33M): about 0.07 GB weights. bge-base (110M): 0.22 GB. bge-reranker-large (560M): 1.1 GB. gte-Qwen2-7B: about 15 GB.
- The PyTorch backend uses more memory than a Rust server for the same model; leave extra margin next to an LLM.

Vector storage:

```
bytes = vectors × dimensions × element bytes   (float32 4, int8 1, binary dims/8)
```

1M vectors at 768 dims is 3.1 GB in float32, 0.77 GB with `--embedding-dtype int8` and 0.1 GB binary, before index overhead. See the vector store skills for index and quantization settings.

Throughput: raise `--batch-size`, use several instances for query and ingestion separately, and keep the client batch near the server batch.
