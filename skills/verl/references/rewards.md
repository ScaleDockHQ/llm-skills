# Rewards in verl

> Verified against verl-project/verl v0.9.1 (docs/advance/reward_loop.rst, verl/trainer/config/reward/), 2026-10-11

The Reward Loop is the default reward implementation: a distributed reward manager (`reward.num_workers` workers across nodes) that can stream rewards while rollouts run when the reward is rule-based or the reward model has its own resource pool (`reward.reward_model.enable_resource_pool`).

## Rule-based reward (custom function)

Set the file and function name:

```bash
reward.custom_reward_function.path=/abs/path/my_reward.py \
reward.custom_reward_function.name=compute_score     # default name
```

```python
def compute_score(data_source, solution_str, ground_truth, extra_info):
    # return a float, or a dict containing "score"
    return {"score": 1.0 if solution_str.strip().endswith(str(ground_truth)) else 0.0}
```

The function may be sync or async; verl detects which. Use async for external API calls or sandboxes. Without a custom function verl falls back to its built-in scorers selected by `data_source` (for example `verl/utils/reward_score/gsm8k.py`).

## Reward managers

- `naive`: simplest.
- `dapo`: DAPO with overlong-reward penalty.
- `limit`: caps concurrency, for rate-limited external APIs.
- `remote`: separate process, for CPU-heavy checks such as Math-Verify.

## Reward models

- Discriminative (DisRM): `reward.reward_model.enable=True` and `reward.reward_model.model_path=<e.g. Skywork/Skywork-Reward-Llama-3.1-8B-v0.2>`. Only the last output is scored.
- Generative (GenRM): set both `reward.reward_model.model_path` and a `custom_reward_function`; GenRM requires the custom function.
- Hybrid (rule + GenRM): the custom function combines both.

## Sandboxed code reward

`docs/examples/sandbox_fusion_example.rst` documents SandboxFusion for code rewards. Never run model-generated code on the training host without isolation.

## Checks before a long run

- Unit-test the function on 3 correct and 3 wrong answers.
- Confirm the log shows a spread of `critic/score/mean` or reward metrics; a constant 0 means the answer extraction does not match the model's output format.
- Match the prompt's required answer format to the extractor (GSM8K uses the `####` marker).
