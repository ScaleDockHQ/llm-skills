# Aider with self-hosted endpoints: troubleshooting

> Verified against Aider v0.86.0 (docs: troubleshooting/warnings, token-limits, models-and-keys, llms/_, config/_), 2026-10-11

Run `scripts/check-endpoint.sh` first. If it fails the endpoint is the problem. Otherwise read the startup banner (version, model, edit format, repo map) and `/tokens`. `/help <question>` inside aider answers questions about aider itself.

| Symptom                                                      | Cause                                                                          | Fix                                                                                          |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `Unknown context window size and costs, using sane defaults` | Name not in LiteLLM's list                                                     | Harmless; add `.aider.model.metadata.json` to silence it.                                    |
| `Did you mean one of these?`                                 | Typo or missing prefix                                                         | Use `openai/<served-name>`; `aider --list-models <part>`.                                    |
| `Missing these environment variables`                        | Provider key variable unset                                                    | Export the named variable or put it in `.env`; on Windows restart the shell after `setx`.    |
| `Unknown which environment variables are required`           | Model prefix unrecognized by aider                                             | Check the LiteLLM provider docs for that prefix; for local servers use `openai/`.            |
| `AuthenticationError` / 401                                  | Wrong or missing `OPENAI_API_KEY`, key in a YAML other than OpenAI/Anthropic   | Set the key in the environment or `.env`; for keyless servers set a dummy non-empty value.   |
| `NotFoundError` / 404                                        | `OPENAI_API_BASE` lacks `/v1` or duplicates it; wrong model name               | Base ends in `/v1` once; name after `openai/` equals `/v1/models` ID.                        |
| `model not found` from the server                            | Prefix forwarded wrongly or name casing                                        | Exact served name; with LiteLLM use the `model_name` alias.                                  |
| Edits "did not match any lines" or empty edits               | Model cannot follow the edit format                                            | `--edit-format whole` for that model (model settings), or a stronger model.                  |
| Answer arrives all at once, UI frozen                        | Proxy buffers SSE                                                              | Disable buffering; or `--no-stream`.                                                         |
| `Model ... has hit a token limit!`                           | Input over the context window or output over the max                           | `/drop` files, smaller edits; raise the server window; aider never enforces limits itself.   |
| Ollama ignores earlier files, loses context silently         | Default 2k window; context above the window is discarded                       | Use `ollama_chat/`, set `num_ctx` in model settings or `OLLAMA_CONTEXT_LENGTH`; `ollama ps`. |
| Ollama via `openai/` truncates                               | Aider's automatic `num_ctx` is documented for the Ollama routes, not `openai/` | Set `OLLAMA_CONTEXT_LENGTH` on the server or use `ollama_chat/`.                             |
| `does not support 'thinking_tokens', ignoring`               | Model settings lack `accepts_settings`                                         | Add it, or `--no-check-model-accepts-settings` to force.                                     |
| `<think>` text breaks edits                                  | Inline reasoning not recognized                                                | `reasoning_tag: think` in model settings, or enable the engine's reasoning parser.           |
| `400` mentioning `temperature` or a system message           | Backend or model rejects them                                                  | `use_temperature: false`, `use_system_prompt: false` in model settings.                      |
| Requests time out on first use                               | Model is loading (llama-swap, Ollama)                                          | `--timeout <seconds>`, keep the model warm.                                                  |
| TLS error to a private endpoint                              | CA not trusted                                                                 | Trust the CA in the Python environment; avoid `--no-verify-ssl`.                             |
| `.env` ignored                                               | Different directory or an earlier file overridden by a later one               | Load order: home, repo root, cwd, `--env-file`; check each.                                  |
| Wrong model starts, or OpenRouter onboarding appears         | No `--model` and keys unavailable                                              | Pass `--model` or set `AIDER_MODEL`.                                                         |
| Settings file not applied                                    | `name` does not equal the exact model string including prefix                  | Use `openai/<name>` exactly as on the command line.                                          |
| `aider` command not found                                    | Installer environment not on `PATH`                                            | Reopen the shell after `aider-install`; see the docs page "Aider not found".                 |
| Dependency conflicts                                         | Installed into a shared environment                                            | Use `aider-install` or an isolated tool environment.                                         |

Report upstream with `aider --version`, the startup banner, model name and endpoint engine (no keys).
