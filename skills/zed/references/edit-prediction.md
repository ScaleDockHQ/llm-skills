# Zed: self-hosted edit prediction

> Verified against Zed v1.23.2 (docs: ai/edit-prediction), 2026-10-11

Edit prediction (tab completion) has its own provider under `edit_predictions`, separate from the Agent models. The default provider is Zeta, which needs a Zed account; self-hosting uses a local model instead.

## Ollama

```jsonc
{
  "edit_predictions": {
    "provider": "ollama",
    "ollama": {
      "api_url": "http://localhost:11434",
      "model": "qwen2.5-coder:7b-base",
      "prompt_format": "infer",
      "max_output_tokens": 512,
    },
  },
}
```

## Any OpenAI completions server (vLLM, llama.cpp, LocalAI)

```jsonc
{
  "edit_predictions": {
    "provider": "open_ai_compatible_api",
    "open_ai_compatible_api": {
      "api_url": "http://localhost:8080/v1/completions",
      "model": "deepseek-coder-6.7b-base",
      "prompt_format": "deepseek_coder",
      "max_output_tokens": 512,
    },
  },
}
```

- The server must implement `POST /v1/completions` (raw prompt, not chat). Zed sends `model`, `prompt`, `max_tokens`, `temperature` (0.2) and `stop`.
- `api_url` here is the full completions URL, unlike the chat providers.
- `prompt_format` values: `infer` (default, from the model name), `zeta`, `zeta2`, `zeta2_1`, `code_llama`, `star_coder`, `deepseek_coder`, `qwen`, `code_gemma`, `codestral`, `glm`, `sweep`. `infer` maps models named `zeta2` or `zeta2.1` to the Zeta formats; otherwise set the format explicitly to match the model's fill-in-the-middle tokens.
- Use a base (non-instruct) FIM model; chat-tuned models give poor completions.

## Practical notes

- Each keystroke can send editing context to the provider, so latency and privacy are set by where the server runs. Keep it on loopback or a private network.
- Keep `max_output_tokens` small (512 in the examples) so predictions return fast.
- Verify by typing in a file and watching the server log for `/v1/completions`; if nothing arrives, check the status bar provider and that edit predictions are enabled for the language.
- Key handling: no key field is documented for these providers; if your server needs one, front it with a proxy that accepts local traffic, or use a gateway with a header Zed can send. Treat this as a verification gap and test.

## Official links

- Edit Prediction: https://zed.dev/docs/ai/edit-prediction
