# Inspect AI: tasks, datasets and run configuration

> Verified against inspect-ai 0.3.278 (docs: tasks, datasets, options), 2026-10-11

An eval is a `Task`: a dataset of samples, a solver that produces output, and a scorer. Tasks live in a Python file and are registered with `@task`.

## Minimal task

```python
# task.py
from inspect_ai import Task, task
from inspect_ai.dataset import FieldSpec, json_dataset
from inspect_ai.scorer import match
from inspect_ai.solver import generate

@task
def golden(path: str = "dataset.jsonl"):
    return Task(
        dataset=json_dataset(path, FieldSpec(input="input", target="target", id="id", metadata=["category", "critical"])),
        solver=generate(),
        scorer=match(),          # target must appear at the end of the output by default
    )
```

```bash
inspect eval task.py --model <provider/model> --limit 5 --log-dir logs/smoke
inspect eval task.py -T path=other.jsonl ...      # task args
inspect eval task.py@golden ...                  # pick a task in a multi-task file
```

`@task` is required for `inspect eval`, `eval-retry` and `eval-set` (retry and sets need it to rebuild the task; parameters must be plain Python types).

## Datasets

- Native readers: `csv_dataset`, `json_dataset` (JSON or JSON Lines), `hf_dataset` (Hugging Face; downloads, so ask first), or any list of `Sample` objects.
- `Sample` fields: `input` (str or chat messages, required), `choices`, `target` (str or list; literal answer or grading guidance for a model grader), `id`, `metadata`, `sandbox`, `files`, `setup`. Samples without `id` get 1, 2, 3 ...
- A dataset already named `input`/`target` loads with no mapping; otherwise use `FieldSpec(input=..., target=..., id=..., metadata=[...])` or a `record_to_sample(record)` function.
- With `choices`, `target` is a capital letter (use the `multiple_choice()` solver and `choice()` scorer).
- `shuffle=True|seed` and `shuffle_choices=True|seed` on the readers randomize order; set an int seed for repeatability.

## Solvers

`generate()` sends the input and records the output. Others compose in a list: `system_message()`, `prompt_template()`, `chain_of_thought()`, `multiple_choice()`, `use_tools()`, agents such as `react()`. Solver docs: https://inspect.aisi.org.uk/solvers.html.

## Overriding at run time

Most Task settings can be set on the CLI (precedence: CLI flag over task default). Useful ones: `--solver`, `-S` solver args, `-T` task args, `--model-role name=model`, `--limit N` or `10-20`, `--sample-id`, `--epochs N`, `--epochs-reducer`, `--message-limit`, `--token-limit`, `--time-limit`, `--cost-limit` (needs model cost data), `--no-score`, `--tags`, `--metadata k=v`.

`--generate-config`, `--task-config`, `--solver-config` take YAML or JSON files. `--run-config run.yaml` bundles task, model, model roles, generation config, solver and eval options in one file; explicit CLI flags override it, and it cannot be combined with `--generate-config`, `--task-config` or `--solver-config`. Export one from an existing log to reproduce a run:

```bash
inspect log export-config logs/<run>.eval > run.yaml
inspect eval --run-config run.yaml
```

## Epochs and repeatability

`--epochs 5` repeats each sample; the default reducer keeps the task's setting, `--epochs-reducer mean|median|mode|max|at_least_N|pass_at_K|pass_k_K` replaces it. Use epochs for stochastic sampling and compare means with their stderr, never single runs.

Official sources: https://inspect.aisi.org.uk/tasks.html, https://inspect.aisi.org.uk/datasets.html, https://inspect.aisi.org.uk/options.html
