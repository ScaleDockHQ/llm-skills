# Lighteval: troubleshooting

> Verified against lighteval 0.13.0 and main 0.13.1.dev0 (docs, source of main_inspect.py and cli_args.py), 2026-10-11

| Symptom                                         | Cause                                                                                        | Fix                                                                                                |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Install fails or backend missing                | Python < 3.10, or extra not installed                                                        | Python 3.10+, `pip install "lighteval[litellm]==X"` or `[vllm]`                                    |
| `vllm` extra breaks the environment             | vLLM pins differ from your installed vLLM (0.13.0 needs `>=0.10.0,<0.10.2`)                  | Separate venv, or use `eval`/`endpoint litellm` against a running server                           |
| "Task ... is not supported by inspect_ai yet"   | Task lacks `sample_fields`                                                                   | Use `vllm`, `accelerate` or `endpoint litellm`, or define the task for Inspect                     |
| Timeouts on every sample with `eval`            | `--timeout` default 30 s                                                                     | `--timeout 300` or more; reasoning models need longer; lower `--max-connections` for small servers |
| Same scores for different runs                  | Inspect cache (`generate(cache=True)`) in `eval`; or `--load-responses-from-details-date-id` | Clear the Inspect cache; drop the load flag                                                        |
| Eval stopped midway ("Error evaluating models") | Sample or connection errors                                                                  | Re-run the identical command with the same `--log-dir` to resume                                   |
| Scores near zero on correct-looking answers     | Thinking text in the answer, truncated thoughts, wrong answer format for the metric          | Check `__model_response__` in details; `--reasoning-tags`; raise max tokens; read the task prompt  |
| `--custom-tasks` ignored with `eval`            | `eval` passes no custom tasks to the registry in the inspected source                        | Use another backend for custom tasks                                                               |
| CUDA OOM with `vllm`                            | Memory settings                                                                              | Lower `gpu_memory_utilization` and `max_model_length`; use tensor parallelism                      |
| Multi-GPU vLLM hangs                            | Worker start method                                                                          | `export VLLM_WORKER_MULTIPROC_METHOD=spawn`                                                        |
| 401 or gated dataset error                      | Missing `HF_TOKEN` or no access                                                              | Set the token (env var), accept the dataset terms                                                  |
| LiteLLM auth/URL errors                         | `base_url` missing `/v1`, wrong provider prefix, empty key rejected                          | `hosted_vllm/<id>` or `openai/<id>`; check `curl $BASE/models`                                     |
| Unexpected Hub upload                           | `--push-to-hub` or `--repo-id` set                                                           | Remove; uploads are private by default but still leave the machine                                 |
| No details files                                | `--save-details` is off by default on the CLI                                                | Add `--save-details`                                                                               |

Useful: `lighteval <backend> --help`, `lighteval tasks inspect <task>` to see the prompt, `--max-samples 5`.

Official sources: https://huggingface.co/docs/lighteval/, https://github.com/huggingface/lighteval/issues
