# Ollama: models, formats and Modelfiles

> Verified against Ollama v0.40.3, 2026-10-11

Docs: cli, modelfile, import; cmd/cmd.go flags; Hugging Face Ollama integration page

## CLI cheat sheet

| Command                              | What it does                                                                                                                                                                                    |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ollama pull <model>`                | Download from the library (`name:tag`) or `hf.co/<user>/<repo>[:quant]`                                                                                                                         |
| `ollama run <model> ["prompt"]`      | Interactive chat or one-shot; pulls if missing. `""` as prompt preloads                                                                                                                         |
| `ollama run <model> --keepalive 30m` | Keep loaded this long. Other flags: `--think=true\|false\|high\|medium\|low`, `--hidethinking`, `--format json`, `--verbose` (timings), `--truncate=false`, `--dimensions N` (embedding models) |
| `ollama ls`                          | Local models and sizes                                                                                                                                                                          |
| `ollama ps`                          | Loaded models: `NAME ID SIZE PROCESSOR CONTEXT UNTIL`                                                                                                                                           |
| `ollama stop <model>`                | Unload now                                                                                                                                                                                      |
| `ollama show <model>`                | Architecture, parameters, context length, quantization, capabilities. Flags: `--modelfile`, `--parameters`, `--template`, `--system`, `--license`, `-v`                                         |
| `ollama create <name> -f Modelfile`  | Build a model from a Modelfile. Safetensors: `-q/--quantize nvfp4` (example upstream gives)                                                                                                     |
| `ollama cp <src> <dst>`              | Copy or rename (also a way to alias a model to a name a client hardcodes, for example `gpt-3.5-turbo`)                                                                                          |
| `ollama rm <model> [...]`            | Delete. Blobs shared between tags are kept until unused                                                                                                                                         |
| `ollama push <user>/<model>`         | Publish to ollama.com (needs an account and your public key)                                                                                                                                    |
| `ollama signin` / `signout`          | Link or unlink an ollama.com account (cloud models, private models, push)                                                                                                                       |
| `ollama launch [integration]`        | Configure and start Claude Code, Codex, OpenCode, VS Code, Droid and others against Ollama                                                                                                      |
| `ollama serve`                       | Run the server in the foreground                                                                                                                                                                |

In the interactive REPL: `/set parameter num_ctx 32768`, `/show info`, `/bye`; wrap multiline input in `"""`. Images in `ollama run` take a file path inside the prompt.

## Library models

Browse https://ollama.com/library (search filters: `?c=cloud`, `?c=thinking`, tools, vision, embedding). Tags carry size and quantization (`qwen3:8b`, `gpt-oss:20b`). The default tag is usually a 4-bit quant. Pick tags by file size against free memory, then add room for the KV cache (`performance-tuning.md`). Library tags can drop or rename; re-check the page before documenting a tag as current.

Local storage keeps content-addressed blobs plus manifests, so tags that share layers cost no extra space. Pulls are large; run them where a failed network does not matter, and set `HTTPS_PROXY` if needed.

## Hugging Face GGUF

Any GGUF repo on the Hub runs without a Modelfile:

```bash
ollama run hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF                 # picks Q4_K_M if present, else a reasonable quant
ollama run hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q8_0            # quant tag (case-insensitive)
ollama run hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Llama-3.2-3B-Instruct-IQ3_M.gguf   # exact file
```

`huggingface.co/...` works as the domain too. The template is chosen from the GGUF's `tokenizer.chat_template` metadata. To override, add files named `template` (a Go template, not Jinja), `system` and `params` (JSON) to the repo. Private repos work after adding the contents of `~/.ollama/id_ed25519.pub` as an SSH key in your Hugging Face account. More in `combos/hugging-face-gguf.md`.

## Import local weights

Ollama does not quantize GGUF files on import. Quantize first, for example with llama.cpp's `llama-quantize`.

```dockerfile
# Modelfile
FROM ./model-Q4_K_M.gguf          # absolute or relative to the Modelfile
# split GGUF: keep the original shard names and use a wildcard
# FROM ./model-*.gguf             (or list each shard in separate FROM lines)
```

```bash
ollama create my-model -f Modelfile && ollama run my-model
```

Safetensors: `FROM /path/to/safetensors/directory` (or `FROM .` next to the weights) for a supported architecture, then `ollama create my-model`. Unsupported architecture, wrong template or missing tool-calling support is the usual reason to prefer llama.cpp (`llama-cpp` skill) for new models.

**LoRA adapters are not supported.** An `ADAPTER` line fails in the CLI with "LoRA adapters are no longer supported", and the API rejects `adapters` and adapter GGUFs with the same message. Merge the adapter into the base model, convert, quantize, import the merged GGUF (`fine-tuning-llms` and `model-quantization` skills cover the merge).

## Modelfile

Case-insensitive instructions, any order, `#` comments.

| Instruction            | Use                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| `FROM`                 | Required. Library model, GGUF path, or safetensors directory                                      |
| `PARAMETER name value` | Defaults for this model (table below). Repeat `stop` for several stop strings                     |
| `TEMPLATE """..."""`   | Full prompt template, Go template syntax with `{{ .System }}`, `{{ .Prompt }}`, `{{ .Response }}` |
| `SYSTEM """..."""`     | Default system message                                                                            |
| `MESSAGE role text`    | Seed history; roles `system`, `user`, `assistant`                                                 |
| `LICENSE`              | License text                                                                                      |
| `REQUIRES version`     | Minimum Ollama version, for example `0.14.0`                                                      |
| `CAPABILITY name`      | Add a capability to a GGUF or MLX model (repeatable); `decision` only for System One weights      |

Parameters documented for v0.40.3: `num_ctx` (documented default 2048 in the Modelfile page, but the server default is `OLLAMA_CONTEXT_LENGTH`/VRAM-based, see `performance-tuning.md`), `repeat_last_n` (64), `repeat_penalty` (1.0), `temperature` (0.8), `seed` (0), `stop`, `num_predict` (-1), `top_k` (40), `top_p` (0.9), `min_p` (0.0), `draft_num_predict` (speculative draft tokens; separate draft models default to 4, embedded MTP tensors need it set, 0 disables). `typical_p` is deprecated and cannot be set in a Modelfile.

Example (also `templates/Modelfile`):

```dockerfile
FROM qwen3:8b
PARAMETER num_ctx 32768
PARAMETER temperature 0.6
SYSTEM """You are a concise, accurate assistant."""
```

`ollama show --modelfile <model>` prints a model's Modelfile as a starting point (its `FROM` is a blob path; replace with the tag).

## Sizing quickly

File size on disk is close to the weights' memory. Add KV cache (grows with context times parallel slots) and a gigabyte or two of overhead. If `ollama ps` shows a CPU share the model is partly offloaded, which is much slower. See `performance-tuning.md`.
