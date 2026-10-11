# When to Fine-Tune

> Verified against Axolotl docs "Which Fine-Tuning Method Should I Use?" (docs.axolotl.ai/docs/choosing_method.html) and TRL docs (huggingface.co/docs/trl), 2026-10-11

Fine-tuning changes model weights. It is the most expensive way to change model behavior, and the slowest to iterate on. Use it when cheaper levers have been tried and measured.

## The ladder: try in this order

1. **Prompting.** System prompt, few-shot examples, output format instructions, structured output / JSON schema at the server. Hours, not days.
2. **Retrieval (RAG) and tools.** If the model lacks *facts* (docs, tickets, product data) give it the facts at request time. Facts change; weights don't.
3. **A bigger or different base model.** Often cheaper than training: try the next size up or a model specialized for the domain (code, math, multilingual).
4. **Fine-tuning** (this skill). Usually LoRA SFT first; preference tuning (DPO/KTO/ORPO) or RL (GRPO) only after SFT.

Measure each rung with the same eval set (owned by the `llm-evals` skill) so you know whether a rung helped.

## Fine-tuning is a good fit when

- **Format and style must be consistent** and prompting gets it right only most of the time (strict output schema, house style, tone, a specific language variety).
- **A narrow task repeats at volume** and a small fine-tuned model can replace a large general model (cost, latency, on-device).
- **Long prompts are eating your context.** Behavior that needs a 3k-token system prompt can often be trained in, shrinking every request.
- **Tool-calling / function-call shape** for your specific tool set needs to be reliable.
- **You have a verifiable reward** (unit tests, math answers, a checker) and want to improve reasoning on that task: GRPO.
- **You have preference data** (chosen vs rejected answers, or thumbs up/down) and want to steer away from bad outputs: DPO / KTO / ORPO.

## Fine-tuning is a poor fit when

- **The problem is missing or changing knowledge.** Training facts in is unreliable and stale on arrival; use retrieval.
- **You can't write down what "better" means.** No eval set = no way to tell if the run helped or hurt.
- **You have little data and no way to get more.** A few dozen examples rarely beat a good few-shot prompt; a few hundred to a few thousand clean examples is a typical starting range for LoRA SFT (rule of thumb, task-dependent).
- **The base model license forbids your use** or the distribution you plan (see `licenses.md`).
- **You need it tomorrow.** Data prep, a first run, eval and a second run take days.

## Questions to answer before starting

- What exact behavior should change? Write 10 input/expected-output pairs by hand.
- What is the baseline score of the base model (and of a prompted base model) on a held-out set?
- Where will training data come from: logs, human-written, synthetic from a stronger model (check that model's terms on using outputs for training)?
- Is PII or confidential data in the data? Who approves training on it?
- Where will the result run: vLLM with adapters, llama.cpp/Ollama as GGUF, a cloud endpoint? This decides merge vs adapter and export format.
- Which license applies to the base model, the data, and the outputs?

## Decision summary

| Situation | Do this |
|---|---|
| Model doesn't know facts | Retrieval, not fine-tuning |
| Output format/style inconsistent | Prompt + structured output first; LoRA SFT if still failing |
| Have input/output examples | SFT (LoRA) |
| Have chosen/rejected pairs | SFT first, then DPO (or ORPO in one stage) |
| Have only good/bad labels | KTO |
| Have a programmatic reward | GRPO (needs a generation server; more compute) |
| Need maximum quality, lots of GPU | Full fine-tune, only after LoRA proved the data works |

## Official links

- Axolotl method guide: https://docs.axolotl.ai/docs/choosing_method.html
- TRL documentation: https://huggingface.co/docs/trl
- Hugging Face PEFT: https://huggingface.co/docs/peft
