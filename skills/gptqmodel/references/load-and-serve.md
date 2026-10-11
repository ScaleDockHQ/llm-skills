# GPT-QModel: load, serve and hand off

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

## Load and generate

```python
from gptqmodel import GPTQModel

model = GPTQModel.load("ModelCloud/Llama-3.2-1B-Instruct-gptqmodel-4bit-vortex-v2.5")   # Hub id or local directory
tokens = model.generate("Uncovering deep insights begins with")[0]
print(model.tokenizer.decode(tokens))
```

Signature: `GPTQModel.load(model_id_or_path, quantize_config=None, device_map=None, device=None, backend=BACKEND.AUTO, profile=PROFILE.AUTO, trust_remote_code=False, **kwargs)`.

- `backend`: `AUTO` or an explicit `BACKEND.*` (`methods-and-formats.md`). On Apple Silicon `AUTO` can select MLX Metal for supported 4-bit GPTQ and AWQ GEMM checkpoints when MLX-LM supports the architecture (group sizes 32, 64, 128; install `gptqmodel[mlx]`).
- `profile`: `auto`, `fast`, `low_memory`.
- `trust_remote_code=False` by default; only enable it for repositories you have reviewed.
- Loading an unquantized model with a `quantize_config` prepares it for `quantize()`.

## OpenAI-compatible endpoint (quick tests)

```python
model.serve(host="127.0.0.1", port=12345)       # signature defaults: host "0.0.0.0", port 80, async_mode False
model.serve_wait_until_ready(timeout=30)
model.serve_shutdown()
```

Needs the `openai` extra (uvicorn, fastapi, pydantic). The README example binds `0.0.0.0`; always pass loopback unless you add a proxy with auth (this server's auth behavior is (unverified)). It is a convenience server: for production serving use vLLM or SGLang.

## Serving the quantized checkpoint elsewhere

Upstream states models quantized by GPT-QModel are inference compatible with HF Transformers (not with `dynamic`), vLLM and SGLang. The saved `config.json` carries a `quantization_config`; check it before serving:

```bash
jq '.quantization_config | {quant_method, bits, group_size, sym, desc_act, checkpoint_format}' ~/models/<quant>/config.json
vllm serve ~/models/<quant> --host 127.0.0.1        # flags and kernel selection: see the vllm skill
```

- SGLang loads only GPTQ (`gptq`, `gptq_v2`, `marlin`) and AWQ (`gemm`, `marlin`).
- vLLM/SGLang choose their own kernels (Marlin on NVIDIA); the `BACKEND.*` choice here applies to GPT-QModel's own runtime.
- GGUF output from GPT-QModel is a GPT-QModel path; llama.cpp compatibility is not promised by this README ((unverified)); use `gguf-quantization` when llama.cpp is the target.
- ModelScope: `export GPTQMODEL_USE_MODELSCOPE=True`.

## Kernel selection hygiene

- Pin `backend=` only when benchmarking; mismatches between format and backend are expected to fail at load time.
- `GPTQMODEL_FP32_ACCUM=1` (default) favors accuracy; set `0` only after checking quality (`install.md`).
- First load of Machete/JIT kernels compiles; allow minutes, or prewarm and keep `~/.cache/gptqmodel`.

## Publishing

```bash
hf auth whoami
hf repos create <user>/<model>-gptq-4bit
hf upload <user>/<model>-gptq-4bit ~/models/<quant> .
```

(The CLI is the `huggingface_hub` `hf` command; read `hf upload --help`.) Include in the card: source model and license, gptqmodel version, full config, calibration dataset and size, evaluation results, serving command, and note any `dynamic` use. Confirm redistribution rights first and get approval before uploading.
