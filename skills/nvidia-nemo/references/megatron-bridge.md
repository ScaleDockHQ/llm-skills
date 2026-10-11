# NeMo Megatron-Bridge

> Verified against NVIDIA-NeMo/Megatron-Bridge v0.6.2 (README.md, docs/recipe-usage.md, docs/nemo2-migration-guide.md, examples/conversion/README.md; PyPI megatron-bridge 0.6.2), 2026-10-11

PyTorch-native Megatron-Core training library (pretrain, SFT, LoRA/DoRA) plus a bidirectional Hugging Face <-> Megatron conversion and verification layer (`AutoBridge`). PyPI requires Python >= 3.12, < 3.13. A refactor of the NeMo 2.x training stack (see `docs/nemo2-migration-guide.md` upstream for the NeMo 2.0 -> Bridge mapping).

## Install

Best experience, highest performance and full feature support come from the NeMo Framework container; fetch the newest tag from the NGC catalog:

```bash
docker run --rm -it -w /workdir -v $(pwd):/workdir --entrypoint bash --gpus all nvcr.io/nvidia/nemo:${TAG}
```

For a development install follow the repo's CONTRIBUTING guide (uv, `uv sync --locked`). Megatron-Core is pinned as a git submodule at `3rdparty/Megatron-LM`: the committed pin tracks upstream **main**; `./scripts/switch_mcore.sh status|dev|main` switches (then `uv sync` for dev, `uv sync --locked` for main). Dev-branch features are experimental. Log in with `huggingface-cli login` (token via the CLI prompt or environment, not on the command line you share).

## Convert and verify (AutoBridge)

```python
from megatron.bridge import AutoBridge
bridge = AutoBridge.from_hf_pretrained("meta-llama/Llama-3.2-1B", trust_remote_code=True)  # only for repos you trust
provider = bridge.to_megatron_provider()
provider.tensor_model_parallel_size = 1
provider.pipeline_model_parallel_size = 1
provider.finalize()
model = provider.provide_distributed_model(wrap_with_ddp=False)
bridge.save_hf_pretrained(model, "./hf_exports/llama32_1b")      # Megatron -> HF folder
for name, w in bridge.export_hf_weights(model, cpu=True): print(name, tuple(w.shape))  # stream weights
```

Conversion is parallelism-aware (TP/PP/VPP/CP/EP/ETP) and streams per parameter. HF -> Megatron checkpoint conversion is only needed when you want pretrained HF weights as a Megatron checkpoint (fine-tuning from converted weights, round trips). Random-init pretraining from an HF architecture needs no conversion: `to_megatron_provider(load_weights=False)`.

Example scripts (run with `uv run python <script>` in a clone): `examples/conversion/hf_megatron_roundtrip.py --hf-model-id <id> --output-dir <dir>`, `hf_megatron_roundtrip_multi_gpu.py`, `hf_to_megatron_generate_text.py`, `compare_text_generation.py`, `list_supported_architectures.py`, `create_hf_toy_model.py` (shallow test checkpoint with the first N layers).

## Recipes and training

Recipes return a `ConfigContainer`; override in Python, YAML (OmegaConf) or CLI, then call the entry point:

```python
from megatron.bridge.recipes.llama.h100 import llama32_1b_pretrain_1gpu_h100_bf16_config
from megatron.bridge.training.gpt_step import forward_step
from megatron.bridge.training.pretrain import pretrain
if __name__ == "__main__":
    cfg = llama32_1b_pretrain_1gpu_h100_bf16_config()
    cfg.train.train_iters = 10
    pretrain(cfg, forward_step)
```

Launch: `uv run python -m torch.distributed.run --nproc-per-node=<N> script.py`. Workflows: pretraining/continued pretraining (`pretrain()`, `GPTDatasetConfig`), full SFT (`finetune()`, `GPTSFTDatasetConfig`, `checkpoint.pretrained_checkpoint` for the base), PEFT (same plus `cfg.peft`; `pretrained_checkpoint` is required), VLM SFT (`DirectHFSFTDatasetConfig`). `checkpoint.load` resumes a native Megatron run. Slurm launcher: `scripts/training/README.md` upstream.

## Support notes

Gemma 1/2, Llama 2, Mistral 7B, Mistral Small 3 24B, Nemotron H v1 and the legacy `NemotronForCausalLM` bridge are deprecated and removed in 0.7.0 (README). Pretrain/SFT/LoRA only; RL is done through NeMo RL, which uses Megatron-Bridge as a backend.

## Discovery

```bash
python3 -c 'import importlib.metadata as m; print(m.version("megatron-bridge"))'
python3 examples/conversion/list_supported_architectures.py   # inside a clone
gh api repos/NVIDIA-NeMo/Megatron-Bridge/releases/latest --jq '.tag_name,.published_at'
```
