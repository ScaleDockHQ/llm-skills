# Troubleshooting TRL

> Verified against huggingface/trl v1.15.0 docs and source (sft_trainer, vllm_integration, clis, reducing_memory_usage), 2026-10-11

Start every investigation with `trl env` and the full traceback. Entries marked (inferred) come from reading the docs, not from reproducing the error.

| Symptom                                           | Cause and fix                                                                                                                                                                                |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `assistant_only_loss` errors or all labels masked | Chat template lacks `{% generation %}`/`{% endgeneration %}` markers. TRL patches known families (for example Qwen3); otherwise use a template that has them (upstream points to SmolLM3's). |
| Model never stops generating after SFT            | EOS token does not match the chat template. Set `eos_token` in `SFTConfig`, for example `<                                                                                                   | im_end | >` for Qwen base models. |
| Conversational dataset fails on a base model      | Tokenizer has no chat template. Use an instruct model, `clone_chat_template()` or `chat_template_path`.                                                                                      |
| `trl.experimental...` import fails after upgrade  | Experimental modules move or change. Pin the TRL version or move to the stable trainer.                                                                                                      |
| vLLM import or compatibility errors               | TRL supports vLLM 0.21.0 to 0.31.0 only. Check `pip show vllm`.                                                                                                                              |
| Server mode hangs or cannot update weights        | Server missing `VLLM_SERVER_DEV_MODE=1` or `--weight-transfer-config` (`combos/grpo-vllm.md`); trainer and server must be on separate CUDA devices (inferred for the hang).                  |
| OOM in online methods                             | Enable `vllm_enable_sleep_mode`, lower `vllm_gpu_memory_utilization` (default 0.3), shorten `max_completion_length`, or use server mode (`peft-and-memory.md`).                              |
| OOM in SFT                                        | PEFT/QLoRA, packing, padding-free (with FlashAttention), activation offloading, lower `max_length` (`peft-and-memory.md`).                                                                   |
| `padding_free=True` ignored in DPO                | Temporarily unsupported in `DPOTrainer`; it warns and pads normally.                                                                                                                         |
| Batch contamination with padding-free             | Not using FlashAttention 2/3; switch attention implementation or disable padding-free.                                                                                                       |
| GRPO reward flat at 0                             | Check the reward function on literal strings, the completion format (string vs message dicts), and that dataset columns are read through `**kwargs`.                                         |
| Reward function crashes on arguments              | It must accept keyword arguments; add `**kwargs`.                                                                                                                                            |
| Data parallel vLLM does nothing for a dense model | Offline data parallel for non-MoE models is unsupported since vLLM 0.14.0; use `--tensor-parallel-size`.                                                                                     |
| CLI cannot read a local file                      | Docs show only Hub dataset names for the CLI; use a Python script (`trainers.md`).                                                                                                           |
