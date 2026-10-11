# lm-evaluation-harness: hf and vllm backends

> Verified against lm-evaluation-harness v0.4.13 (README, docs/interface.md, lm_eval/models/vllm_causallms.py at tag v0.4.13), 2026-10-11

Use a local backend when you have the weights and a GPU (or Apple/CPU) and want the harness to load the model itself: no server, exact control of dtype, batch size and tokenizer, and the reference numbers upstream uses. Use an endpoint model type (`endpoints.md`) when the model is already served.

## Hugging Face `transformers` (`hf`)

```bash
pip install "lm_eval[hf]==0.4.13"
lm-eval run --model hf \
  --model_args pretrained=EleutherAI/gpt-j-6B,dtype=bfloat16 \
  --tasks hellaswag \
  --device cuda:0 \
  --batch_size 8 \
  --output_path ./lm-eval-results
```

- `pretrained` takes a Hub ID or a local path. `revision=`, `dtype=`, `trust_remote_code=` and most other `model_args` are passed to the transformers constructors.
- `--batch_size auto` or `auto:N` auto-tunes; `--max_batch_size` caps it.
- `--device` defaults to `cuda`; `cuda:0`, `cpu`, `mps` also work. On Apple silicon the README warns the MPS backend is early and correctness issues may exist; check a forward pass on `cpu` against `mps` before trusting numbers.
- GGUF: `pretrained=/path/to/gguf_folder,gguf_file=model.gguf,tokenizer=/path/to/tokenizer` (the HF loader dequantizes; it is not llama.cpp's inference). For scores that reflect llama.cpp's own kernels, serve the GGUF with `llama-server` and use an endpoint model type.
- LoRA: add `peft=<path-or-id>`; bitsandbytes quantization via `load_in_4bit=True` (with `parallelize=True` where needed), GPTQ via `gptqmodel=True` or `autogptq=<file>`.
- Multi-GPU: `accelerate launch -m lm_eval --model hf ...` for data parallel copies; `parallelize=True` for a model sharded across GPUs (run outside `accelerate launch`); native tensor parallel with `tp_plan=auto` under `torchrun` or `accelerate launch`.

## vLLM (`vllm`)

```bash
pip install "lm_eval[vllm]==0.4.13"      # separate venv from your serving vLLM
CUDA_VISIBLE_DEVICES=0 lm-eval run --model vllm \
  --model_args pretrained=<hf-id-or-path>,dtype=auto,gpu_memory_utilization=0.8,max_model_len=4096 \
  --tasks gsm8k --apply_chat_template \
  --batch_size auto \
  --output_path ./lm-eval-results
```

Constructor arguments seen in source: `pretrained`, `dtype` (`auto` default), `revision`, `tokenizer`, `tokenizer_mode`, `trust_remote_code`, `tensor_parallel_size` (1), `data_parallel_size` (1), `quantization` (forwarded to vLLM as its quantization method name; check the vLLM docs for when it is needed), `max_model_len` (or `max_length`, not both), `max_gen_toks` (256), `batch_size` (`auto`), `seed` (1234), `lora_local_path`, `enable_thinking`, `chat_template_args`, `think_end_token`, `truncation_side` (`left`). Other keys are passed to vLLM's `LLM(...)` (`gpu_memory_utilization`, `kv_cache_dtype`, `enable_prefix_caching`, ...); consult the vLLM docs for the version installed.

- The `device` argument is ignored: select GPUs with `CUDA_VISIBLE_DEVICES`.
- `data_parallel_size > 1` dispatches replicas as Ray actors (`pip install ray`); each reserves `tensor_parallel_size` GPUs, manual batching is disabled, and it cannot combine with `enable_expert_parallel=True`. Download the weights once with `data_parallel_size=1` first.
- Set `max_model_len` (for example 4096) when using `--batch_size auto` on models with a very long default context, to avoid out-of-memory errors and speed up runs.
- `enable_thinking=True` requires `think_end_token` (a string such as `</think>`) or it raises a ValueError.
- vLLM occasionally differs from Hugging Face outputs. Upstream treats Hugging Face as the reference implementation and ships `scripts/model_comparator.py` to check vLLM results against it.
- `vllm>=0.18` is the extra's requirement at this tag.

For serving flags, quantization methods and memory tuning, use the `vllm` skill; this backend loads the model in-process and does not talk to a running server.

## SGLang (`sglang`)

The README documents an SGLang backend with `dp_size`, `tp_size`, `dtype=auto` and `mem_fraction_static`; it also accepts string `think_end_token`. This skill did not verify it beyond the README.

## Choosing

| Goal                                                      | Use                                             |
| --------------------------------------------------------- | ----------------------------------------------- |
| Exact numbers for a published model, small model, one GPU | `hf`                                            |
| Fast large-model runs, multi-GPU                          | `vllm`                                          |
| Test what users actually hit (server, template, gateway)  | `local-chat-completions` or `local-completions` |
| GGUF through llama.cpp kernels                            | endpoint model type against `llama-server`      |

Official sources: https://github.com/EleutherAI/lm-evaluation-harness#basic-usage, https://github.com/EleutherAI/lm-evaluation-harness/blob/main/lm_eval/models/vllm_causallms.py
