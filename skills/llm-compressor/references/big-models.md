# Big models, MoE and distributed runs

> Verified against llm-compressor 0.14.0 (docs/guides/memory.md, docs/guides/big_models_and_distributed/model_loading.md, sequential_onloading.md, distributed_oneshot.md, docs/guides/entrypoints/oneshot.md, model-free-ptq.md, docs/steps/choosing-algo.md, examples/disk_offloading, examples/quantizing_moe/README.md), compressed-tensors 0.19.0, 2026-10-11

## Memory

Upstream's memory guide: 1B parameters in 16-bit is about 2 GB, so the BF16 model needs about `2 x parameters` bytes of CPU RAM (or disk, with offload).

- RTN (`QuantizationModifier`): no extra memory beyond scales and zero points; GPU needs about one layer (Llama-3-8B about 0.5 GB per layer).
- GPTQ and SparseGPT: an auxiliary Hessian per onloaded layer, about the size of the layer, so roughly double the per-layer GPU memory (Llama-3-8B about 1 GB).
- Text decoder layers are onloaded one at a time; vision towers load to the GPU all at once, so a large vision tower can be the GPU bottleneck. Upstream does not quantize vision towers.
- Tensor parallelism is not supported for compression; use DDP to spread work (below).
- Example upstream figures: DeepSeek-R1-0528-BF16 (684B) needs about 1368 GB CPU memory and 22.4 GB per layer on GPU for RTN, 44.8 GB for GPTQ.

## Calibration pipelines

`oneshot(pipeline=...)`:

| Pipeline      | Use                                                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `independent` | Default per the entrypoint docs                                                                                                                                                       |
| `sequential`  | Layer by layer with activations offloaded; for models that do not fit on the GPU. Upstream calls it the recommended pipeline for nearly all cases and the default for calibrated runs |
| `basic`       | One shared forward pass; fast but needs the whole model plus algorithm memory on the GPU                                                                                              |
| `datafree`    | No forward passes (data-free weight-only)                                                                                                                                             |

Sequential onloading swaps the loop order: for each layer, run the whole calibration set through it, then move on. Related arguments: `sequential_targets` (defaults to the model's `no_split_modules`, usually a decoder layer), `sequential_offload_device` (default `"cpu"`, set `"cuda:1"` if a second GPU exists), `sequential_prefetch`.

On a small GPU, set `sequential_targets="Linear"` for lower VRAM at the cost of runtime (upstream docs). Small models that fit in VRAM: load with `device_map="auto"` and `pipeline="basic"` for speed.

## Loading: `device_map` choices

From upstream's model-loading table (non-distributed):

| `device_map`                        | Behaviour                                                                      | Use with                            |
| ----------------------------------- | ------------------------------------------------------------------------------ | ----------------------------------- |
| `"auto"`                            | All visible CUDA devices, falls back to CPU and disk                           | `basic` or `datafree` pipeline      |
| `"cuda"`                            | First CUDA device only, errors if too big                                      |                                     |
| `"cpu"` (default `from_pretrained`) | CPU, errors if too big                                                         |                                     |
| `"auto_offload"`                    | CPU first, falls back to disk when CPU memory runs out; needs `load_context()` | `sequential` pipeline (recommended) |

## Disk offload

```python
from llmcompressor.utils import load_context

with load_context():
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_ID,
        device_map="auto_offload",           # as much as fits on CPU, rest on disk
        max_memory={"cpu": 64e9},            # optional CPU budget in bytes
        offload_folder="/scratch/offload",   # a filesystem with plenty of free space
    )
```

Then call `oneshot` as usual; some steps are slower. Upstream's `examples/disk_offloading/qwen3_example.py` notes that `transformers==5.14` breaks saving for disk-offloaded models and asks for `transformers>=5.15` (the 0.14.0 pin already requires 5.15+).

## DDP (multi-GPU)

Supported since v0.10.0 per upstream FAQ. DDP-aware: `GPTQModifier`, `QuantizationModifier`, `AutoRoundModifier`, `REAPPruningModifier`, plus the `SmoothQuantModifier` and `AWQModifier` transforms. Each rank calibrates a disjoint slice of the data; GPTQ also distributes the compression work.

Changes to a single-GPU script:

```python
from compressed_tensors.offload import init_dist
from llmcompressor.utils import load_context

init_dist()                                   # first, one GPU per rank
with load_context():                          # after init_dist
    model = AutoModelForCausalLM.from_pretrained(MODEL_ID, device_map="auto_offload")
# partition the dataset per rank (get_rank_partition) or pass a Dataset object
...
model.save_pretrained(SAVE_DIR, save_compressed=True)   # call on all ranks, rank 0 writes
tokenizer.save_pretrained(SAVE_DIR)
import torch.distributed as dist
dist.destroy_process_group()
```

Run with `torchrun --nproc_per_node=<gpus> script.py`. Skip or shorten the sample generation for large models.

## `model_free_ptq` (no transformers model needed)

Operates directly on safetensors files for **data-free** schemes (FP8 dynamic, FP8 block, NVFP4A16, MXFP4/MXFP8). Use it when the model has no transformers definition yet, when `oneshot` fails, or for very large checkpoints. Not for GPTQ, AWQ, SmoothQuant or static activation scales.

```python
from llmcompressor import model_free_ptq

model_free_ptq(
    model_stub="<org>/<model>",              # Hub id or local path
    save_directory="<model>-FP8-BLOCK",
    scheme="FP8_BLOCK",
    ignore=["lm_head"],
    device="cuda:0",                          # or a list of devices plus max_workers=N
)
```

Mixed data-free schemes: pass `config=QuantizationConfig(config_groups={...})` instead of `scheme=` (they are mutually exclusive; the first matching group wins). Upstream also provides `convert_checkpoint` (in compressed-tensors) to convert a ModelOpt or AutoAWQ checkpoint to compressed-tensors, or to dequantize a block-FP8 checkpoint to BF16 first. See `examples/model_free_ptq/` for per-model scripts.

## MoE models

- Load inside `load_context()` so MoE modules load in a calibratable form (upstream MoE README, GLM-4.7 AWQ W4A16 example).
- `moe_calibrate_all_experts=True` is the default and "required for accurate MoE quantization" per the entrypoint docs. New architectures may need a calibration module; see upstream's `docs/developer-tutorials/add-moe-support.md`.
- Ignore the router: `ignore=["lm_head", "re:.*mlp.gate$"]` (pattern used in upstream examples; check your model's gate module name).
- Mixed precision (for example NVFP4 experts plus FP8 attention) is in `examples/quantizing_moe` (`qwen_3_8_example.py`, `glm5_example.py`, others).
- REAP expert pruning (`REAPPruningModifier`) removes the least-salient experts by calibration data and can combine with quantization in one recipe; validate on your own workload because over-pruning can remove domain-critical experts (upstream warning). See `examples/reap_expert_pruning`.

## Time and cost

Big runs take hours. Run them in `tmux` or a job, inside a memory-capped scope on shared machines, and keep the offload folder on fast local disk. Never run them while a serving process holds the same GPU or unified memory.
