# Choosing an Inference Engine: adjacent engines

> Verified against MLX v0.32.3 and mlx-lm v0.31.3 (GitHub), LM Studio docs (app overview), NVIDIA Dynamo v1.5.1 (README), Text Generation Inference v3.3.7 (GitHub), 2026-10-11

These are not in the main matrix. Each entry says what it is, its verified status, and when it changes the decision.

## MLX and mlx-lm (Apple Silicon)

- Status: `ml-explore/mlx` is active (v0.32.3, 2026-09-29, not archived). `ml-explore/mlx-lm` is not archived; its latest tagged release is v0.31.3 from 2026-04-22, which is older than the repository activity, so check the default branch for newer fixes.
- MLX is an array framework for Apple silicon. mlx-lm is the LLM runner on top of it.
- Choose it on a Mac when you want MLX checkpoints, MLX LoRA fine-tuning or the newest MLX-native model support. Choose `llama.cpp` or `Ollama` when you want GGUF and one tool across macOS, Linux and Windows.
- SGLang and TensorFold both list MLX-format paths on Apple Silicon. See the matrix.
- Skill status: an `mlx` skill may exist in this repo. Install: `npx skills add ScaleDockHQ/llm-skills --skill mlx`.

## LM Studio

- Status: a desktop app with a headless mode (`llmster`) and `lms` CLI, documented at lmstudio.ai. Per its docs it runs LLMs with `llama.cpp` (GGUF) on Mac, Windows and Linux, and with MLX on Apple Silicon Macs. It exposes an OpenAI-compatible API and has a parallel-requests and speculative-decoding setting page.
- It is a wrapper around the engines above, so engine capability limits still apply. The app is closed-source, so its release status could not be checked on GitHub in this pass. Treat release cadence as **(unverified)**.
- Choose it for a GUI, model management and a quick local server. Choose a headless engine for servers and automation.
- Skill: `npx skills add ScaleDockHQ/llm-skills --skill lm-studio` (if published).

## NVIDIA Dynamo

- Status: active (v1.5.1, 2026-10-07). Its README describes it as the orchestration layer above inference engines. It does not replace SGLang, TensorRT-LLM or vLLM; it coordinates them for multi-node serving, including disaggregated prefill and decode, and lists backends for all three.
- Choose it when you already run one of those engines on several GPU nodes and need independent scaling of prefill and decode. Do not choose it for a single node or a single user.
- Skill status: a `nvidia-dynamo` skill is planned. Until it exists, read the upstream docs at https://docs.nvidia.com/dynamo/.

## Text Generation Inference (TGI)

- Status: the `huggingface/text-generation-inference` repository is **archived** (read-only). Latest release v3.3.7 on 2025-12-19, last push 2026-03-21.
- Do not start new deployments on TGI. Migrate to vLLM, SGLang or another maintained engine. For an existing deployment, plan the move and run `llm-evals` on the new engine before cutting over.

## Sources

- https://github.com/ml-explore/mlx
- https://github.com/ml-explore/mlx-lm
- https://lmstudio.ai/docs/app
- https://github.com/ai-dynamo/dynamo
- https://github.com/huggingface/text-generation-inference
