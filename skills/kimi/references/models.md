# Kimi models: generations, sizes, context, licenses

> Verified against moonshotai Hugging Face org listing and model cards (Kimi-K3, K2.7-Code, K2.6, K2.5, K2-Thinking, K2-Instruct-0905, Kimi-Linear-48B-A3B-Instruct, Kimi-VL-A3B-Thinking-2506), the Kimi K3 and Kimi K2 LICENSE files and the arXiv Kimi K3 report, 2026-10-11

## Current generations

Newest first. "Active" is the activated parameters per token. Hugging Face org: https://huggingface.co/moonshotai

| Model (HF id)                                        | Total / active | Context                  | Modality                | Weights format                            | License         |
| ---------------------------------------------------- | -------------- | ------------------------ | ----------------------- | ----------------------------------------- | --------------- |
| `moonshotai/Kimi-K3`                                 | 2.8T / 104B    | 1,048,576                | text, image (and video) | MXFP4 experts + MXFP8 act. (QAT), 1.56 TB | Kimi K3 License |
| `moonshotai/Kimi-K2.7-Code`                          | 1T / 32B       | 256K                     | text, image, video      | native INT4 (compressed-tensors)          | Modified MIT    |
| `moonshotai/Kimi-K2.6`                               | 1T / 32B       | 256K                     | text, image, video      | native INT4 (compressed-tensors)          | Modified MIT    |
| `moonshotai/Kimi-K2.5`                               | 1T / 32B       | 256K                     | text, image, video      | compressed-tensors                        | Modified MIT    |
| `moonshotai/Kimi-K2-Thinking`                        | 1T / 32B       | 256K                     | text                    | native INT4 (QAT, compressed-tensors)     | Modified MIT    |
| `moonshotai/Kimi-K2-Instruct-0905`                   | 1T / 32B       | 256K                     | text                    | FP8                                       | Modified MIT    |
| `moonshotai/Kimi-K2-Instruct` / `-Base`              | 1T / 32B       | 128K (per the 0905 card) | text                    | FP8                                       | Modified MIT    |
| `moonshotai/Kimi-Linear-48B-A3B-Instruct` / `-Base`  | 48B / 3B       | 1M                       | text                    | BF16 safetensors                          | MIT             |
| `moonshotai/Kimi-VL-A3B-Thinking-2506` / `-Instruct` | 16B / 3B       | (see below)              | text, image, video      | BF16 safetensors                          | MIT             |

Dates seen on the Hub (last modified): K3 2026-09-02, K2.7-Code 2026-06-15, K2.6 2026-05-19, K2.5 2026-04-30. K3 was published 2026-07-27 (arXiv 2607.24653). Treat K3 as the flagship, K2.7-Code as the coding-tuned K2.x, K2.6 as the general K2.x.

Other repos in the org (out of scope here): Moonlight-16B-A3B, Kimi-Dev-72B (Qwen2.5-72B fine-tune), Kimi-Audio-7B, MoonViT-SO-400M.

## Architecture facts that change serving

| Model family        | Attention                                 | Experts (routed, per token, shared) | Notes                                                             |
| ------------------- | ----------------------------------------- | ----------------------------------- | ----------------------------------------------------------------- |
| K3                  | 69 KDA (linear) + 24 gated MLA, 93 layers | 896, 16, 2 (latent MoE)             | Recurrent KDA state plus MLA KV; vision encoder MoonViT-V2 (401M) |
| K2.x (K2 to K2.7)   | MLA, 61 layers, 64 heads                  | 384, 8, 1                           | DeepSeek-V3-style backbone; vision (K2.5+) MoonViT (400M)         |
| Kimi-Linear 48B-A3B | KDA : MLA at 3:1                          | (MoE, 3B active)                    | Needs `fla-core >= 0.4.0` for the HF path                         |

K3's KDA layers keep a constant-size recurrent state instead of growing KV. vLLM therefore needs a hybrid cache manager and K3's prefix caching is off by default (see `known-issues.md`).

## Modes per generation

| Model            | Thinking / instant                                                            | Notes                                                                 |
| ---------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| K3               | Thinking always on; `reasoning_effort` `low` / `high` / `max` (default `max`) | Instant mode not supported; preserved thinking history required       |
| K2.7-Code        | Thinking forced; `preserve_thinking` forced on                                | About 30% fewer thinking tokens than K2.6; instant mode not supported |
| K2.6             | Thinking (default) and instant; `preserve_thinking` off by default            | Same architecture as K2.5, deployment reusable                        |
| K2.5             | Thinking and instant                                                          | Ollama retired its `kimi-k2.5` library entry on 2026-07-31            |
| K2-Thinking      | Thinking, interleaved with tool calls (200-300 sequential calls claimed)      | Text only                                                             |
| K2-Instruct-0905 | Non-thinking                                                                  | Context raised from 128K to 256K versus the first K2-Instruct         |

## Licenses

- **Kimi K3 License** (K3 weights and code). Free use, modification and distribution with the copyright notice kept. Two conditions: (a) if you operate a "Model as a Service" business (giving third parties inference or fine-tuning access with meaningful control over inputs, parameters or training data) and you and your affiliates exceed 20M USD revenue over any 12 months, you need a separate agreement with Moonshot AI before commercial use; (b) if a commercial product has more than 100M monthly active users or more than 20M USD monthly revenue, "Kimi K3" must be prominently shown in its UI. Internal use, and use through Moonshot's official products or certified inference partners, is exempt from (a) and (b). Read the full text before advising a hosting business: https://huggingface.co/moonshotai/Kimi-K3/blob/main/LICENSE
- **Modified MIT** (K2 family, K2.5, K2.6, K2.7-Code). MIT plus one condition: products with more than 100M monthly active users or more than 20M USD monthly revenue must prominently display "Kimi K2" in the UI. The HF license metadata is `other`, name `modified-mit`.
- **MIT**: Kimi-Linear and Kimi-VL (HF license metadata `mit`).
- NVIDIA's NVFP4 re-quants carry their own license metadata (K2.6-NVFP4: `nvidia-open-model-license`); check the quant's card before redistributing.

This is a summary of upstream texts, not legal advice.

## Context limits

| Model                                                | Native                                   | Beyond native                                                                                       |
| ---------------------------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------- |
| K3                                                   | 1,048,576                                | None documented. vLLM recipe serves `--max-model-len 1048576` on 8 GPUs with `--kv-cache-dtype fp8` |
| K2.5, K2.6, K2.7-Code, K2-Thinking, K2-Instruct-0905 | 256K (262,144)                           | No YaRN extension documented on the cards                                                           |
| Kimi-Linear                                          | 1M (card table)                          | vLLM example uses `--max-model-len 1048576` with TP 4                                               |
| Kimi-VL-Thinking-2506                                | card example runs `max_model_len=131072` | Plans for up to 32K generated tokens                                                                |

Unsloth suggests starting with 98,304 context for K2.6 and going up to 262,144 as memory allows.

## Sources

- K3: https://huggingface.co/moonshotai/Kimi-K3 , https://arxiv.org/abs/2607.24653 , https://github.com/MoonshotAI/Kimi-K3
- K2.7-Code: https://huggingface.co/moonshotai/Kimi-K2.7-Code
- K2.6: https://huggingface.co/moonshotai/Kimi-K2.6
- K2.5: https://huggingface.co/moonshotai/Kimi-K2.5
- K2-Thinking: https://huggingface.co/moonshotai/Kimi-K2-Thinking
- K2-Instruct-0905: https://huggingface.co/moonshotai/Kimi-K2-Instruct-0905
- Kimi-Linear: https://huggingface.co/moonshotai/Kimi-Linear-48B-A3B-Instruct
- Kimi-VL: https://huggingface.co/moonshotai/Kimi-VL-A3B-Thinking-2506
- Licenses: https://huggingface.co/moonshotai/Kimi-K3/blob/main/LICENSE , https://huggingface.co/moonshotai/Kimi-K2-Instruct/blob/main/LICENSE
- Org listing: https://huggingface.co/moonshotai
