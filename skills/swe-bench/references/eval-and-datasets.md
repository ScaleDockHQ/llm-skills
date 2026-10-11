# Datasets, eval, report and images

> Verified against swebench 5.0.2 (PyPI wheel contents) and upstream docs on main, 2026-10-11

## Datasets

| Alias (5.0.2)      | HuggingFace id                     | Notes                                                                                               |
| ------------------ | ---------------------------------- | --------------------------------------------------------------------------------------------------- |
| `full`             | `SWE-bench/SWE-bench`              | 2,294 instances                                                                                     |
| (none; use the id) | `SWE-bench/SWE-bench_Lite`         | upstream docs disagree on size (300 in the FAQ, 534 in the datasets guide); count the rows you load |
| `verified`         | `SWE-bench/SWE-bench_Verified`     | 500 engineer-verified instances; the usual headline set                                             |
| `multilingual`     | `SWE-bench/SWE-bench_Multilingual` | 300 instances, 9 languages, 42 repositories                                                         |
| `multimodal`       | `SWE-bench/SWE-bench_Multimodal`   | dev split has 100 instances; test grading goes through the hosted API (sb-cli)                      |

A dataset argument also accepts a local path.

## Evaluate

```bash
# Harness check: reference patch for one instance
swebench eval verified --gold -i sympy__sympy-20590 -j 1 --run-id validate-gold

# Model predictions
swebench eval verified -p preds.jsonl -j 8 --run-id my-model-2026-10-11

# Narrow to instances; run on Modal instead of local Docker
swebench eval verified -p preds.jsonl -i sympy__sympy-20590 --run-id try1
swebench eval full --gold --modal
```

Options in 5.0.2 (from the wheel): `--gold` or `-p/--predictions` (exactly one), `--run-id` (default `run`), `-i/--instance` (repeatable), `-s/--split` (default `test`), `-j/--workers` (default 4), `-t/--timeout` seconds per instance (default 1800), `--report-dir` (default `.`), `--task-repo`, `--modal`, `--open-file-limit` (4096). Predictions may be `.json` or `.jsonl`.

The older form still works with the same semantics and underscore flags (`--max_workers`, `--cache_level`, `--clean`, `--force_rebuild`, `--namespace`):

```bash
python -m swebench.harness.run_evaluation --dataset_name SWE-bench/SWE-bench_Verified \
  --predictions_path preds.jsonl --max_workers 8 --run_id my-model
```

## Sizing

- Workers: stay below `min(0.75 * cpu_count, 24)`. Eight cores: about 6; sixteen: about 12.
- Cache level (legacy form): `none` and `base` about 120GB during a run, `env` (default) about 100GB retained, `instance` about 2,000GB. Use `--cache_level env --clean True` to drop instance images as you go.
- Layers: base image, about 60 environment images, one instance image per task.
- Reclaim space with `docker system df` first, then `docker container prune`, `docker image prune`; `swebench images clean --run-id <id>` removes leftover containers of a run.

## Results

Written relative to the directory where you ran the command:

```
logs/evaluation/<run_id>/results.json
logs/evaluation/<run_id>/<model>/<instance_id>/{report.json,test_output.txt,run_instance.log,eval.sh,patch.diff}
logs/build_images/
```

```bash
jq . logs/evaluation/<run_id>/results.json | head -40     # key names vary by version, read before scripting
```

Counts: resolved plus unresolved are the graded instances. "Instances with errors" means no `report.json` was produced (patch did not apply, container did not start, timeout); "0 failed" in the live progress line only counts harness crashes. "Empty patches" never ran. Read `run_instance.log` of any errored instance.

## Re-grade without containers

```bash
swebench report <run_id>              # dataset from the run record when present
swebench report <run_id> -d verified  # older runs, or a deliberate different dataset
```

## Cache rule

Results are cached by `run_id` plus `instance_id`, not by patch content. A re-run with the same `run_id` skips instances that already have a `report.json`. Use a new `run_id` for new patches, or delete `logs/evaluation/<run_id>` on purpose.

## Images

```bash
swebench images check ./swe-bench-tasks           # which images are missing from the registry
swebench images build ./swe-bench-tasks -j 8 --dry-run
swebench images build ./swe-bench-tasks -i sympy__sympy-20590
```

`images push` publishes under the names a task declares and needs registry credentials: leave it to the user.

## Cloud

- Modal: `modal setup` once, then `--modal` (5.0.2 flag) or legacy `--modal true`.
- sb-cli (hosted evaluation on AWS, required for Multimodal test): `pip install sb-cli`, `sb login`, `sb submit`. Login and submission send patches to a third party: ask first.
