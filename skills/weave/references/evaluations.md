# Weave: evaluations

> Verified against Weave docs "Evaluations" and weave 0.53.12, 2026-10-11

Use `weave.Evaluation` to run a model or function over a dataset and score the outputs, with results versioned and comparable in the UI. Methodology (golden sets, judge bias, sample size) belongs to `llm-evals`.

```python
import asyncio, weave
weave.init("<entity>/<project>")

@weave.op()
def match(expected: str, output: dict) -> dict:           # scorer: parameter names map to dataset columns
    return {"correct": expected.lower() in str(output).lower()}

dataset = [{"question": "capital of France?", "expected": "Paris"}]

@weave.op()
def model(question: str) -> str:
    ...                                                     # call your endpoint here

evaluation = weave.Evaluation(dataset=dataset, scorers=[match])
asyncio.run(evaluation.evaluate(model))
```

- Scorers are ops or `weave.Scorer` subclasses; the model output arrives as the `output` argument (check the upstream guide for the exact parameter contract in your version).
- Point the model at a self-hosted endpoint (`tracing-and-integrations.md`) to compare local models; evaluation calls are traced like any other, so apply the privacy controls to evaluation data too.
- LLM judges send content to another model; use a local judge endpoint if data must stay on your network.
- Pin the SDK during a comparison; scorer behavior can change across versions.

## Official links

- Evaluations: https://docs.coreweave.com/products/wandb/weave/guides/core-types/evaluations
- Scorers: https://docs.coreweave.com/products/wandb/weave/guides/evaluation/scorers
