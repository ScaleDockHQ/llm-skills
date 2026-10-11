# GPT-QModel: evaluate and recover accuracy

> Verified against GPT-QModel v7.5.0 and main, 2026-10-11

Never ship a quant unmeasured. Compare the quantized model against the original on tasks that matter for the workload; perplexity alone hides behavior damage.

## Evalution (upstream's toolkit)

GPT-QModel integrates [Evalution](https://github.com/ModelCloud/Evalution) (153 benchmark suites per the README; extra `eval` installs `Evalution>=0.0.17`):

```python
import evalution as eval

run = (
    eval.GPTQModel(backend="marlin", device="cuda:0")
    .model(eval.Model(path="ModelCloud/Llama-3.2-1B-Instruct-gptqmodel-4bit-vortex-v1"))
    .run(eval.benchmarks.gsm8k_platinum(apply_chat_template=True, batch_size=16))
)
print(run.to_dict()["tests"][0]["metrics"])
```

Run the same benchmark on the original model and on each candidate (bits, group size, `act_group_aware`, GPTAQ/FOEM), and tabulate. For vLLM-served checks use your own tasks via `llm-evals`.

## Gates

- The quant must be within the accuracy loss you accept on your task set versus the original (set the number before measuring).
- Check with the chat template and tool-calling format the model uses in production.
- MoE: compare `FailSafe`, routing override and bypass (`quantize.md`); do not assume one wins.
- Re-measure after every change of library version or kernel backend; `GPTQMODEL_FP32_ACCUM` and Marlin fp32 toggles can shift outputs.

## EoRA (post-quant low-rank recovery, GPTQ only)

NVIDIA's EoRA adds a LoRA-style adapter computed from the quantization error (README: "currently only validated for GPTQ"; suggested rank 64 or 32 before 128 or 256, since higher ranks may overfit while using more memory).

```python
from gptqmodel import GPTQModel
from gptqmodel.adapter.adapter import Lora

eora = Lora(path=f"{quant_path}/eora_rank32", rank=32)     # path: save location when generating, load location when loading

GPTQModel.adapter.generate(
    adapter=eora,
    model_id_or_path=model_id,
    quantized_model_id_or_path=quant_path,
    calibration_dataset=calibration_dataset,
    calibration_dataset_concat_size=0,
)

model = GPTQModel.load(model_id_or_path=quant_path, adapter=eora)
```

Measure with and without the adapter; the adapter costs VRAM and an extra load step, and serving engines may not apply it.

## Other checks

- `mock_quantization=True` for pipeline smoke tests.
- Compare sizes: `du -sh` of source and output; expect roughly `bits/16` of BF16 plus group scales and zeros.
- Sample generations at temperature 0 on a fixed prompt set for qualitative diffing.
