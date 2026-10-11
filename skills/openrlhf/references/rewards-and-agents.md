# Rewards and agents in OpenRLHF

> Verified against OpenRLHF/OpenRLHF v0.11.2 (README.md, examples/python/reward_func.py, examples/python/agent_func*.py, openrlhf/cli/train_ppo_ray.py), 2026-10-11

## Reward sources (pick one per run)

- Reward model: `--reward.model_name_or_path <rm>` (train it with `openrlhf.cli.train_rm`).
- Python reward function: `--reward.remote_url /abs/path/reward_func.py` (a file path; an HTTP URL such as `http://host:5000/get_reward` also works; comma-separated values are split into a list). `--data.label_key <field>` passes the dataset field as `labels`.
- Serve a reward model over HTTP: `python3 -m openrlhf.cli.serve_rm --reward.model_name_or_path <rm> ...` (`examples/scripts/serve_remote_rm.sh`); bind it to localhost or a private network.
- Agent file: `--train.agent_func_path /abs/path/agent_func.py` for multi-turn or fully custom reward logic.

## reward_func

```python
import torch

def reward_func(queries, prompts, labels, **kwargs):
    # queries: prompt + response text; prompts: prompt text; labels: dataset answers
    rewards = torch.tensor([1.0 if str(l) in q.split(p)[-1] else 0.0
                            for q, p, l in zip(queries, prompts, labels)])
    return {
        "rewards": rewards,          # used for advantages
        "scores": rewards,           # 0-1 values, used by dynamic filtering
        "extra_logs": {"acc": rewards.mean().item()},   # logged to wandb
    }
```

Unit-test it on known right and wrong answers before launching; the repository example returns random rewards and is only a signature demo.

## Dynamic filtering (DAPO style)

`--algo.dynamic_filtering_enable --algo.dynamic_filtering_range 0.0 1.0`. Requires `--rollout.n_samples_per_prompt > 1` and either `--reward.remote_url` or `--train.agent_func_path` (the CLI asserts all three). Prompts whose group scores fall outside the open range are filtered. Example: `examples/scripts/train_dapo_ray_hybrid_engine.sh`.

## Multi-turn agents

Implement `AgentInstanceBase` (`__init__`, `reset(states)`, `step(states)`) and wrap it:

```python
from openrlhf.utils.agent import AgentInstanceBase, MultiTurnAgentExecutor

class AgentInstance(AgentInstanceBase):
    async def __init__(self, *args, **kwargs): ...
    async def reset(self, states: dict, **kwargs):
        return {"observation": states["observation"]}
    async def step(self, states: dict, **kwargs):
        # states has observation_text, action_text, label
        return {"rewards": ..., "scores": ..., "environment_feedback": "...",
                "done": True, "sampling_params": states.get("sampling_params"),
                "extra_logs": {}}

class AgentExecutor(MultiTurnAgentExecutor):
    def __init__(self):
        super().__init__(AgentInstance)
```

Launch with `--train.agent_func_path /path/agent_func.py` (optionally `--train.async_enable`). For a fully custom token-level flow inherit `AgentExecutorBase` and implement `execute()`. `examples/python/agent_func_openai_server_executor.py` wraps vLLM as a local `/v1/chat/completions` server and collects token traces; `examples/python/vlm_multiturn_agent.py` shows image feedback. Agent and reward files run arbitrary Python (and often code or tools) on the training workers: review them, and sandbox any model-generated code execution.
