# Lighteval: tasks, reasoning tags, results and custom tasks

> Verified against lighteval 0.13.0 and main 0.13.1.dev0 (docs quicktour, saving-and-reading-results, adding-a-custom-task; src/lighteval/cli_args.py), 2026-10-11

## Choosing tasks

```bash
lighteval tasks list | grep -i gsm8k           # all registered tasks
lighteval tasks inspect gsm8k --num-samples 3  # prompt, metrics, a few samples (--show-config for full config)
```

- Backends other than `eval` take task strings like `gsm8k`, `truthfulqa:mc`, `ifeval`, with few-shot as `task|N` (for example `"truthfulqa:mc|0,gsm8k|3"`). Several tasks: comma list, or a text file path starting with `./` (see `examples/tasks/recommended_set.txt` upstream). Sample-level parameters: `{task}@{param}={value}|0`.
- `lighteval eval` accepts the same registry names (for example `gpqa:diamond`) but only those with an Inspect definition.
- Task implementations live in `src/lighteval/tasks/` (prompts, metrics, splits); read the prompt format before trusting a score, because few-shot, formatting and metric choices decide the number. Upstream scores are not guaranteed comparable to other harnesses.
- Multilingual tasks need `--load-tasks-multilingual` and the `multilingual` extra.

## Reasoning models

`--remove-reasoning-tags` is on by default and removes `<think>` ... `</think>` before metrics are computed. For other markers: `--reasoning-tags "[('[THINK]','[/THINK]')]"`. If the server already separates reasoning (vLLM reasoning parser), the content has no tags and nothing is removed. Give enough `max_new_tokens`/`--max-tokens` (a truncated thought has no answer) and, for `eval`, a long `--timeout`. Check five generations in the details.

## Results and details

- Results JSON: `{output_dir}/results/{model_name}/results_{timestamp}.json`. The output path may be any fsspec location (local, S3, Hub); use `--results-path-template '{output_dir}/{org}_{model}'` for a custom layout.
- `--save-details` writes per-sample Parquet at `{output_dir}/details/{model_name}/{timestamp}/details_{task}_{timestamp}.parquet` with columns `__doc__` (gold, few-shot, hyperparameters), `__model_response__` (generations, logprobs, input) and `__metric__`.
- `lighteval eval` writes Inspect logs to `--log-dir`; read them with `inspect log dump <file> | jq` or `inspect view --log-dir <dir>` (see `inspect-ai`).
- Reuse generations while iterating on metrics: `--load-responses-from-details-date-id <timestamp>`.
- Hub push (`--push-to-hub --results-org <org>`, details need `--save-details`) creates a dataset named from the org and model; private unless `--public-run`. Do not push without approval; prompts and outputs go with it.

Compare two runs per task: `templates/compare-results.sh results-a.json results-b.json`. Treat differences inside the reported stderr as noise.

## Custom task (non-Inspect backends)

```python
# my_tasks.py
from lighteval.tasks.lighteval_task import LightevalTaskConfig
from lighteval.tasks.requests import Doc
from lighteval.metrics import Metrics

def prompt_fn(line, task_name):
    return Doc(task_name=task_name, query=line["question"],
               choices=[f" {c}" for c in line["choices"]], gold_index=line["gold"])

task = LightevalTaskConfig(
    name="myothertask", prompt_function=prompt_fn,
    hf_repo="<org>/<dataset>", hf_subset="default",
    hf_avail_splits=["train", "test"], evaluation_splits=["test"],
    few_shots_split="train", few_shots_select="random_sampling_from_train",
    metrics=[Metrics.ACCURACY], generation_size=256, stop_sequence=["\n", "Question:"],
)
TASKS_TABLE = [task]
```

```bash
lighteval accelerate "model_name=<repo>" "myothertask|3" --custom-tasks my_tasks.py
```

Custom metrics use `SampleLevelMetric(metric_name, higher_is_better, category, sample_level_fn, corpus_level_fn)`. For an Inspect-backed task, `LightevalTaskConfig` also takes `sample_fields`, `solver` and `scorer`. `lighteval tasks create <template> <task_name> <dataset_name>` scaffolds a task file. The repo ships no Python files, so keep this code in your own project.

Official sources: https://huggingface.co/docs/lighteval/quicktour, https://huggingface.co/docs/lighteval/saving-and-reading-results, https://huggingface.co/docs/lighteval/adding-a-custom-task
