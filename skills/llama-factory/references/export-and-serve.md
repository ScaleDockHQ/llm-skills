# Chat, merge, export and serve with LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## Chat-test the adapter

`examples/inference/qwen3_lora_sft.yaml`:

```yaml
model_name_or_path: Qwen/Qwen3-4B-Instruct-2507
adapter_name_or_path: saves/qwen3-4b/lora/sft
template: qwen3_nothink
infer_backend: huggingface # huggingface, vllm, sglang, ktransformers
trust_remote_code: true
```

```bash
llamafactory-cli chat infer.yaml        # terminal chat
llamafactory-cli webchat infer.yaml     # browser chat (Gradio)
```

Use the same `template` as training.

## Merge a LoRA adapter

Upstream note: do not use a quantized model or `quantization_bit` when merging. Merge into the unquantized base.

```yaml
model_name_or_path: Qwen/Qwen3-4B-Instruct-2507
adapter_name_or_path: saves/qwen3-4b/lora/sft
template: qwen3_nothink
trust_remote_code: true
export_dir: saves/qwen3_sft_merged
export_size: 5 # shard size in GB
export_device: cpu # cpu or auto
export_legacy_format: false # false = safetensors
```

```bash
llamafactory-cli export merge.yaml
```

Starter: `templates/merge-lora.yaml`. Check disk first (`df -h`): the merged model is a full copy of the base. Verify by loading `export_dir` with `infer_backend: vllm` or by the `vllm` skill, and compare outputs with the adapter run.

Other export options in `model_args.py`: `export_hub_model_id` pushes to the Hub (needs `HF_TOKEN` in the environment, ask first), `export_quantization_bit` with `export_quantization_dataset` (required), `export_quantization_nsamples` (128) and `export_quantization_maxlen` (1024) produce a quantized export (`examples/merge_lora/qwen3_gptq.yaml` is the GPTQ example). Exporting a full-tuned model with the right config can also write an Ollama modelfile (upstream example `examples/merge_lora/qwen3_full_sft.yaml`); GGUF conversion belongs to `llama-cpp`.

## OpenAI-style API

```bash
API_PORT=8000 API_KEY="$(cat ~/.config/llamafactory/api_key)" \
  llamafactory-cli api infer.yaml infer_backend=vllm vllm_enforce_eager=true
```

From `api/app.py`: host from `API_HOST` (default `0.0.0.0`), port from `API_PORT` (default `8000`), docs at `http://localhost:<port>/docs`. If `API_KEY` is set, requests need `Authorization: Bearer <key>`; if unset, anyone who can reach the port can use it. Always set `API_HOST=127.0.0.1` or put it behind a private network, and keep the key in a `0600` file.

vLLM backend knobs in model args: `vllm_maxlen`, `vllm_gpu_util`, `vllm_enforce_eager`, `vllm_max_lora_rank`, `vllm_config`. For production serving prefer the merged model under the `vllm` skill, which covers flags and tuning.

```bash
curl -s http://127.0.0.1:8000/v1/models -H "Authorization: Bearer $(cat ~/.config/llamafactory/api_key)" | jq .
```

## LLaMA Board (web UI)

`llamafactory-cli webui` serves Gradio with `server_name` from `GRADIO_SERVER_NAME` (default `0.0.0.0`, or `[::]` with `GRADIO_IPV6`), `GRADIO_SHARE` to create a public share link, and `inbrowser=True`. The code path has no login. Use:

```bash
GRADIO_SERVER_NAME=127.0.0.1 llamafactory-cli webui
```

and reach it through an SSH tunnel or an authenticated reverse proxy (`caddy`, `cloudflare-tunnel` skills). Never set `GRADIO_SHARE=1` on a machine with private models or data. It can start training and read paths on the host, so treat access as shell-level access.

## Docker

`docker compose exec llamafactory bash` then run the same commands; mount `/root/.cache/huggingface`, `/app/shared_data` and `/app/output` (commented `VOLUME` line in the Dockerfile) so results persist.
