# Model licenses for self-hosted generative media

> Verified against the official license texts and Hugging Face model cards linked below, 2026-10-11

This isn't legal advice. Licenses change between model versions, so re-check the exact repo and revision you deploy. Serving a model to other people (colleagues, customers, a public endpoint) is usually what turns "personal use" into something the license regulates.

## Check before serving

1. Open the model card on Hugging Face and read the `license` metadata. `other` means a custom license: read the linked file.
2. Read the actual license text, not a summary. Look for: commercial use, revenue or user thresholds, territory, output restrictions, acceptable-use policy, attribution.
3. Check every component: diffusion model, text encoders, VAE, LoRAs, and voices. A permissive pipeline with a non-commercial LoRA is non-commercial.
4. Record the model id, revision, and license in your deployment notes next to the llama-swap entry.
5. Gated repos (click-through acceptance) need an HF token with access: `test -n "$HF_TOKEN" && echo set`.

Quick metadata lookup (read-only):

```bash
curl -s https://huggingface.co/api/models/<org>/<model> | jq '{license: .cardData.license, name: .cardData.license_name, link: .cardData.license_link, gated}'
```

## Image models

| Model | License | Key terms (from the license text) |
|---|---|---|
| [FLUX.1 [dev]](https://huggingface.co/black-forest-labs/FLUX.1-dev) | [FLUX.1 [dev] Non-Commercial License v1.1.1](https://github.com/black-forest-labs/flux/blob/main/model_licenses/LICENSE-FLUX1-dev) | Non-commercial purposes only. Use for revenue-generating activity or "in direct interactions with or that has impact on end users" is not a Non-Commercial Purpose. Outputs may be used commercially, but not to train a competing model. Commercial licenses come from BFL. Covers Fill/Depth/Canny/Redux/Kontext [dev] too. Gated on HF |
| [FLUX.1 [schnell]](https://huggingface.co/black-forest-labs/FLUX.1-schnell) | Apache-2.0 (model card) | permissive |
| [Stable Diffusion 3.5 Large](https://huggingface.co/stabilityai/stable-diffusion-3.5-large) | [Stability AI Community License](https://stability.ai/community-license-agreement) | Free for individuals and organizations with under USD 1,000,000 annual revenue. Commercial use requires registering with Stability AI. Above the threshold (counting affiliates, from any source), the license terminates and you must request one from Stability AI. Gated on HF |
| [SDXL base 1.0](https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0) | CreativeML OpenRAIL++-M (`openrail++`) | permissive with use-based restrictions |
| [Qwen-Image](https://huggingface.co/Qwen/Qwen-Image) | Apache-2.0 (model card) | permissive |
| [Z-Image-Turbo](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo) | Apache-2.0 (model card) | permissive |

## Video models

| Model | License | Key terms |
|---|---|---|
| [Wan 2.2](https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B) (T2V-A14B, TI2V-5B, ...) | Apache-2.0 (model cards; also stated in the ComfyUI Wan2.2 tutorial) | permissive, commercial use allowed |
| [LTX-2 / LTX-2.3](https://huggingface.co/Lightricks/LTX-2.3) | [LTX-2 Community License Agreement](https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2) | Free use, but entities with annual revenue of at least USD 10,000,000 need a paid commercial license; Attachment A use restrictions |
| [HunyuanVideo](https://huggingface.co/tencent/HunyuanVideo) / [HunyuanVideo 1.5](https://huggingface.co/tencent/HunyuanVideo-1.5) | [Tencent Hunyuan Community License](https://github.com/Tencent-Hunyuan/HunyuanVideo-1.5/blob/master/LICENSE) | Territory excludes the **European Union, United Kingdom and South Korea**: the license doesn't apply there. Products with more than 100 million monthly active users must request a license from Tencent. Acceptable Use Policy applies |

## Speech models

| Model | License | Key terms |
|---|---|---|
| [Whisper](https://github.com/openai/whisper) (OpenAI) | MIT per the openai/whisper README ("code and model weights"); HF cards vary: `whisper-large-v3` shows Apache-2.0, `whisper-large-v3-turbo` shows MIT | permissive either way |
| [faster-whisper conversions](https://huggingface.co/Systran/faster-whisper-large-v3) (Systran) | MIT (model card) | permissive |
| [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | Apache-2.0 (model card) | permissive |

## Server software licenses

| Software | License |
|---|---|
| stable-diffusion.cpp, whisper.cpp, Speaches, llama-swap | MIT |
| Kokoro-FastAPI | Apache-2.0 |
| ComfyUI, ComfyUI-Manager | GPL-3.0 (matters if you modify and distribute it; running it as a service internally is a different question, so check with counsel for your case) |

## Pitfalls

- "Open weights" doesn't mean "open license". FLUX.1 [dev] weights are downloadable but non-commercial; FLUX.1 [schnell] is Apache-2.0. Pick schnell for a commercial endpoint, or license dev.
- Revenue thresholds count the whole organization (and, in Stability's case, affiliates), not the project.
- Territory clauses (Hunyuan) apply to where you and your users are, which matters for EU/UK teams even when the server is elsewhere.
- Community LoRAs and fine-tunes are Derivatives under most of these licenses, so the base model's terms follow them, and their authors may add their own.
- Repackaged weights (for example `Comfy-Org/*_repackaged` repos) carry the original model's license, whatever the repackager's card says.
- Voices and likeness: TTS voice tuning and cloning features raise consent and right-of-publicity issues independent of the model license.

## Official links

- FLUX.1 [dev] license: https://github.com/black-forest-labs/flux/blob/main/model_licenses/LICENSE-FLUX1-dev
- Stability AI Community License: https://stability.ai/community-license-agreement
- LTX-2 Community License: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2
- Tencent Hunyuan Community License (HunyuanVideo 1.5): https://github.com/Tencent-Hunyuan/HunyuanVideo-1.5/blob/master/LICENSE
- openai/whisper license: https://github.com/openai/whisper/blob/main/LICENSE
- Hugging Face model card licenses: https://huggingface.co/docs/hub/repositories-licenses
