# DeepEval: test cases, metrics and datasets

> Verified against deepeval 4.2.8 (docs: getting-started, metrics-introduction, evaluation-unit-testing-in-ci-cd; metric source on main), 2026-10-11

## A test

```python
# test_golden.py
import pytest
from deepeval import assert_test
from deepeval.dataset import EvaluationDataset, Golden
from deepeval.metrics import AnswerRelevancyMetric, GEval
from deepeval.test_case import LLMTestCase, SingleTurnParams

dataset = EvaluationDataset(goldens=[
    Golden(input="What is the capital of France?", expected_output="Paris"),
])

correctness = GEval(
    name="Correctness",
    criteria="Is the actual output correct according to the expected output?",
    evaluation_params=[SingleTurnParams.ACTUAL_OUTPUT, SingleTurnParams.EXPECTED_OUTPUT],
    threshold=0.5,
)

def my_app(question: str) -> str:      # call your model or service here
    return "Paris"

@pytest.mark.parametrize("golden", dataset.goldens)
def test_app(golden: Golden):
    case = LLMTestCase(input=golden.input, actual_output=my_app(golden.input),
                       expected_output=golden.expected_output)
    assert_test(test_case=case, metrics=[correctness, AnswerRelevancyMetric(threshold=0.7)])
```

Run with `deepeval test run test_golden.py -x` (see `references/running-and-ci.md`). The repo ships no Python files; `templates/test_example.py.txt` is the same example to copy into your project.

## `LLMTestCase` fields

`input`, `actual_output` (what your app produced), `expected_output`, `context` (ideal context for hallucination checks), `retrieval_context` (what the retriever returned, required by RAG metrics), `tools_called`, `expected_tools`, plus `expected_labels` for classifiers. Multi-turn evals use conversational test cases and goldens (`ConversationalGolden`).

## Metrics: required fields (from the metric source on main)

| Metric                                                 | Needs                                           | Judge?               |
| ------------------------------------------------------ | ----------------------------------------------- | -------------------- |
| `GEval(name, criteria, evaluation_params, threshold)`  | the params you list                             | yes                  |
| `AnswerRelevancyMetric`                                | `input`, `actual_output`                        | yes                  |
| `FaithfulnessMetric`                                   | `input`, `actual_output`, `retrieval_context`   | yes                  |
| `ContextualPrecisionMetric`, `ContextualRecallMetric`  | `input`, `retrieval_context`, `expected_output` | yes                  |
| `ContextualRelevancyMetric`                            | `input`, `retrieval_context`                    | yes                  |
| `HallucinationMetric`                                  | `input`, `actual_output`, `context`             | yes                  |
| `ExactMatchMetric(threshold=1)`                        | `input`, `actual_output`, `expected_output`     | no                   |
| `PatternMatchMetric(pattern, ignore_case)`             | `input`, `actual_output`                        | no                   |
| `JsonCorrectnessMetric(expected_schema=PydanticModel)` | `input`, `actual_output`                        | score no; reason may |

More families exist (agentic, conversational, safety, multimodal); see https://deepeval.com/docs/metrics-introduction. A metric missing a required field raises an error; `--skip-on-missing-params` / `SKIP_DEEPEVAL_MISSING_PARAMS=1` skips instead.

## Metric behaviour

- Scores are 0 to 1; a metric passes when `score >= threshold`. `strict_mode=True` forces a binary score. `include_reason=True` (default for LLM metrics) adds a `reason`, which costs an extra judge call. `verbose_mode=True` prints the judge's intermediate steps.
- `async_mode=True` is the default; set `False` for a fragile local judge.
- `flaky=True` stops a metric from deciding pass/fail.
- One-off use: `metric.measure(case)`, then `metric.score`, `metric.reason`, `metric.is_successful()`.
- Pass `model=judge` per metric to override the global judge (`references/judges.md`).

## Datasets

`EvaluationDataset` loads goldens from files and in code: `add_goldens_from_json_file`, `add_goldens_from_jsonl_file`, `add_goldens_from_csv_file`, `add_golden`, plus `pull`/`push` for Confident AI (cloud; ask first). Keep one golden per line with `input`, `expected_output` and your own tags (such as `critical`) in `additional_metadata`. Check the field-name mapping arguments of the loader on the installed version with `help(EvaluationDataset.add_goldens_from_jsonl_file)`.

`evaluate(test_cases=[...], metrics=[...])` runs a batch outside pytest; `dataset.evals_iterator(metrics=[...])` loops goldens for traced apps (`@observe`) and records component-level results; both accept async, display, cache and error configs (`references/running-and-ci.md`).

## Calibrating

LLM-judged scores are opinions. Label 30 to 50 cases by hand, compare with the judge's pass/fail per metric, and tune `criteria`, threshold and judge before gating (strategy in `llm-evals`).

Official sources: https://deepeval.com/docs/getting-started, https://deepeval.com/docs/metrics-introduction, https://deepeval.com/docs/evaluation-datasets
