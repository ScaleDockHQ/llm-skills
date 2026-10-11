# Lighteval: backends and model configuration

> Verified against lighteval 0.13.0 and main 0.13.1.dev0 (README, docs quicktour, use-vllm-as-backend, use-litellm-as-backend, src/lighteval/main_inspect.py, main_endpoint.py, cli_args.py), 2026-10-11

Commands are `lighteval <backend> <model-or-config> <tasks> [options]`, except `lighteval eval <model> <tasks>`. Run `lighteval <backend> --help` for the installed version.

| Command                                                                 | Use for                                                                                     | Model argument                                                                                              |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `lighteval eval`                                                        | Upstream's preferred path: runs tasks through Inspect AI (`eval_set`), any Inspect provider | Inspect model string(s), for example `vllm/<id>`, `openai-api/<name>/<id>`, `hf-inference-providers/<repo>` |
| `lighteval vllm`                                                        | Local GPUs through the vLLM Python engine                                                   | `"model_name=<repo>,key=val"` or YAML path                                                                  |
| `lighteval accelerate`                                                  | Local transformers on CPU or GPUs                                                           | `"model_name=<repo>"`                                                                                       |
| `lighteval endpoint litellm`                                            | Any OpenAI-compatible server or provider through LiteLLM                                    | `"provider=...,model_name=...,base_url=..."` or YAML path                                                   |
| `lighteval endpoint tgi` / `inference-endpoint` / `inference-providers` | Hugging Face TGI, Inference Endpoints, Inference Providers                                  | YAML path (or args)                                                                                         |
| `lighteval sglang`, `nanotron`, `custom`                                | SGLang engine, Nanotron checkpoints, your own model class                                   | see docs                                                                                                    |
| `lighteval tasks list                                                   | inspect                                                                                     | create`, `baseline`, `bundle`                                                                               | utilities |     |

## `lighteval eval` (Inspect backend)

```bash
export LLAMACPP_API_KEY="$(cat ~/.config/llm/llamacpp.key)"       # provider label "llamacpp" -> LLAMACPP_API_KEY
lighteval eval openai-api/llamacpp/<served-model-id> gsm8k \
  --model-base-url http://localhost:8080/v1 \
  --max-samples 5 --temperature 0 --max-tokens 1024 --seed 1234 \
  --timeout 300 --max-connections 8 --log-dir logs/gsm8k-smoke
```

What the source does (main and v0.13.0 agree):

- Several models in one call (`models` is a list) are run as one Inspect eval set, with a markdown table at the end. Re-run the **same command with the same `--log-dir`** to resume after errors; on failure it prints that hint.
- Defaults: `--max-connections 50`, `--timeout 30` (seconds per connection, short for slow or reasoning models), `--retry-on-error 1`, `--max-retries 5`, `--epochs 1`, `--display rich`. `--log-dir` defaults to `lighteval-logs-<timestamp>`.
- Default solver is `generate(cache=True)` and the default scorer is `exact()` unless the task defines others, so repeated runs can reuse cached generations. Use `inspect cache clear` (see the `inspect-ai` skill) before decision runs.
- Few-shot: tasks with `num_fewshots > 0` get a system message of examples sampled with seed 42 from the evaluation split (a TODO in the source says a dedicated few-shot split is not used yet).
- A task without `sample_fields` fails with "not supported by inspect_ai yet"; use another backend for it.
- The command builds its registry with `custom_tasks=None`, so `--custom-tasks` appears to have no effect on `eval` in the inspected source; test custom tasks with the other backends or `inspect-ai` directly.
- Options: generation (`--temperature`, `--top-p`, `--top-k`, `--max-tokens`, `--seed`, `--stop-seqs`, `--reasoning-effort`, `--reasoning-tokens`, `--system-message`, `--model-roles`, `--model-args 'k=v'`), task (`--max-samples`, `--epochs`, `--epochs-reducer`), logging (`--log-dir`, `--bundle-dir`, `--repo-id`, `--public`). `--repo-id` with `--bundle-dir` uploads a static viewer to a Hugging Face Space (private unless `--public`); needs approval.

See the `inspect-ai` skill for provider strings, env vars and log handling.

## `lighteval vllm`

```bash
export VLLM_WORKER_MULTIPROC_METHOD=spawn      # needed for multi-GPU per the docs
lighteval vllm "model_name=<hf-repo>,dtype=bfloat16,gpu_memory_utilization=0.8,max_model_length=8192" \
  ifeval --max-samples 5 --output-dir results --save-details
```

Or a YAML (`examples/model_configs/vllm_model_config.yaml` upstream):

```yaml
model_parameters:
  model_name: "<hf-repo>"
  dtype: "bfloat16"
  tensor_parallel_size: 1
  data_parallel_size: 1
  pipeline_parallel_size: 1
  gpu_memory_utilization: 0.9
  max_model_length: 2048
  generation_parameters:
    temperature: 0.0
    max_new_tokens: 1024
    seed: 42
```

OOM: lower `gpu_memory_utilization` and `max_model_length`. Tensor parallelism splits one model over GPUs; data parallelism replicates a model that fits on one GPU.

## `lighteval endpoint litellm`

```bash
lighteval endpoint litellm templates/litellm-endpoint.yaml gsm8k --max-samples 5 --output-dir results --save-details
```

```yaml
model_parameters:
  model_name: "hosted_vllm/<served-model-id>" # provider prefix: openai/<id> or hosted_vllm/<id>
  provider: "hosted_vllm"
  base_url: "http://localhost:8000/v1"
  api_key: "" # empty for open servers; never commit a real key
  generation_parameters:
    temperature: 0.0
    max_new_tokens: 512
    seed: 0
```

Config fields (source): `model_name`, `provider`, `base_url`, `api_key` (secret string), `concurrent_requests` (default 10), `api_max_retry` (8), `api_retry_sleep`, `api_retry_multiplier`, `timeout` (default none), `max_model_length`, `system_prompt`, `generation_parameters`. Chat templates are applied server-side. The inline form is `"provider=openai,model_name=gpt-4o"`. Through a LiteLLM proxy, use the proxy's `model_name` with `openai/` prefix and the proxy URL as `base_url`.

## Common run options (vllm, accelerate, litellm and others)

`--max-samples N` (per task), `--output-dir`, `--results-path-template`, `--save-details`, `--custom-tasks file.py`, `--num-fewshot-seeds`, `--remove-reasoning-tags/--no-...`, `--reasoning-tags "[('<think>','</think>')]"`, `--load-responses-from-details-date-id <ts>` (re-score saved responses instead of generating), `--push-to-hub --results-org <org>` (needs approval), `--wandb`, `--dataset-loading-processes`, `--load-tasks-multilingual`.

Official sources: https://huggingface.co/docs/lighteval/quicktour, https://huggingface.co/docs/lighteval/use-vllm-as-backend, https://huggingface.co/docs/lighteval/use-litellm-as-backend, https://github.com/huggingface/lighteval/blob/main/src/lighteval/main_inspect.py
