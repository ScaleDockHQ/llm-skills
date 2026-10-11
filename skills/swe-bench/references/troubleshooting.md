# SWE-bench troubleshooting

> Verified against swebench 5.0.2 (PyPI wheel contents) and upstream docs on main, 2026-10-11

| Symptom                                                                 | Cause and fix                                                                                                                                                                          |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `swebench: command not found` or `No such command 'infer'` / `'submit'` | Not installed in this venv, or PyPI 5.0.2 lacks them (they are on `main`). `swebench --help` lists what exists; see `install.md`.                                                      |
| `Requires-Python` error on install                                      | Python <3.10. Use a newer interpreter in a venv.                                                                                                                                       |
| Same score after changing patches                                       | Results cached by `run_id` plus `instance_id`. Use a new `run_id` or remove `logs/evaluation/<run_id>`.                                                                                |
| `Run ... did not record which dataset it used, so pass -d`              | Run predates run metadata. `swebench report <id> -d verified`.                                                                                                                         |
| Unknown dataset `lite`                                                  | Alias exists only on `main`. Use `SWE-bench/SWE-bench_Lite`.                                                                                                                           |
| `0 failed` but `Instances with errors: N`                               | The progress line counts harness crashes only. Open `logs/evaluation/<run>/<model>/<id>/run_instance.log`: patch did not apply, container did not start, or timeout.                   |
| Many timeouts or stuck run                                              | Too many workers for the Docker VM, or too little disk. Lower `-j`, raise Docker Desktop CPU, check `docker system df`; consider a larger `-t`.                                        |
| Disk full                                                               | `docker system df`; `docker container prune`; `docker image prune`; `swebench images clean --run-id <id>`; legacy `--cache_level env --clean True`.                                    |
| Gold patch not resolved                                                 | Harness, image or host problem, not your model. Retry one instance with `-j 1`; if images are suspect pass `--task-repo ./swe-bench-tasks`; on ARM use `--task-repo` for local builds. |
| Slow or failing pulls and builds on Apple Silicon or ARM                | arm64 is experimental; prefer an x86_64 host or `--task-repo` with Buildx.                                                                                                             |
| Docker permission denied (Linux)                                        | Add the user to the `docker` group, new login, then `docker run hello-world`.                                                                                                          |
| Too many open files                                                     | Raise `--open-file-limit` (default 4096) and the shell `ulimit -n`.                                                                                                                    |
| Everything is "empty patch"                                             | The scaffold produced no diffs: check agent trajectories, context length, tool-call parsing, `--split test`.                                                                           |
| Local model agent loops or errors on cost                               | Add `cost_tracking: "ignore_errors"`; verify `api_base`, the key variable and the served model name.                                                                                   |
| Scores differ from published numbers                                    | Different dataset version, scaffold, step limit, model settings or harness version. Compare only like with like.                                                                       |

## Safe checks

```bash
swebench eval verified --gold -i sympy__sympy-20590 -j 1 --run-id gold-check-$(date +%s)
docker ps --format '{{.Names}}' | head
tail -n 30 logs/evaluation/<run_id>/<model>/<instance_id>/run_instance.log
```
