# Inspect AI: scorers, model grading and metrics

> Verified against inspect-ai 0.3.278 (docs: scorers, model-graded, metrics, scoring-workflow, models), 2026-10-11

## Built-in scorers

| Scorer                                     | Use                                                   | Note                                                             |
| ------------------------------------------ | ----------------------------------------------------- | ---------------------------------------------------------------- |
| `includes()`                               | target appears anywhere                               | substring, case-insensitive by default                           |
| `match()`                                  | target at `begin`, `end` (default), `any`, or `exact` | `numeric=True` compares numbers; ignores case and whitespace     |
| `pattern(regex)`                           | extract with a regex, compare                         | no match gives INCORRECT with `reason="invalid_response_format"` |
| `answer()`                                 | prompts that end with `ANSWER: X`                     | letter, word or rest of line                                     |
| `exact()`, `f1()`                          | normalized exact match, token F1                      | report `mean` and `stderr`                                       |
| `choice()`                                 | multiple choice from `multiple_choice()`              | supports `"A,B"` targets                                         |
| `math()`                                   | mathematical equivalence                              | needs `inspect-ai[math]`                                         |
| `model_graded_qa()`, `model_graded_fact()` | open-ended answers, fact present                      | needs a grader model                                             |
| `perplexity()`, `target_perplexity()`      | logprob benchmarks                                    | need `prompt_logprobs` and no streaming                          |

An empty completion gives `reason="no_response"`. Most scorers report `accuracy` and `stderr`.

## Model grading

```python
from inspect_ai.model import ModelRole
from inspect_ai.scorer import model_graded_qa

scorer = model_graded_qa(
    model_role=ModelRole("grader", required=True),   # error if no grader is bound
    partial_credit=False,
)
```

```bash
inspect eval task.py --model vllm/<candidate> --model-role grader=openai-api/judge/<judge-model>
```

Selection order: explicit `model=` (a list votes by `reducer`), else the bound `model_role` (default role name `grader`), else **the model being evaluated**. Without `required=True` and without a bound role the candidate grades itself.

- Default template and instructions ask for `GRADE: C` or `GRADE: I` and parse it with `grade_pattern`; if you change the instructions, change `grade_pattern` too.
- Template variables: `question`, `criterion` (from `Sample.target`), `answer`, `instructions`, plus unclashing `Sample.metadata` keys. A blank criterion in the viewer means `target` was not set.
- `partial_credit=True` (default instructions only) maps partial to 0.5.
- `include_history=True` shows the whole chat to the grader.
- Role values accept settings: `--model-role 'grader={model: openai/gpt-4o, temperature: 0}'` (inline YAML or JSON), a comma list for several graders.
- Use a pinned, versioned grader id (aliases drift) and calibrate on human labels before gating.

## Metrics and uncertainty

Built-ins: `accuracy()`, `mean()`, `stderr()`, `bootstrap_stderr()`, `std()`, `ci()`, `ci_wilson()` (prefer for binary scores), `grouped(accuracy(), "category")`, `frequency()`. Override with `Task(metrics=[...])`. The headline number in the viewer and `evals_df()` is the first metric of the first score; list `accuracy()` before `stderr()`. For correlated samples use `stderr(cluster="<metadata key>")`.

## Re-scoring without regenerating

```bash
inspect eval task.py --model <m> --no-score          # generate only
inspect score logs/<run>.eval                        # use the task's scorer; prompts to overwrite or writes *-scored
inspect score logs/<run>.eval --scorer match -S location=end
inspect score logs/<run>.eval --overwrite            # replace in place
```

Re-scoring appends the new score alongside old ones by default; overwrite mode replaces them. Use this when iterating on a scorer or a judge prompt: no new generation cost.

Official sources: https://inspect.aisi.org.uk/scorers.html, https://inspect.aisi.org.uk/model-graded.html, https://inspect.aisi.org.uk/metrics.html, https://inspect.aisi.org.uk/scoring-workflow.html
