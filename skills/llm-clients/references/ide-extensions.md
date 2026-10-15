# IDE extensions: Cursor, Continue, Cline, Roo Code, Kilo Code

> Verified against Cursor help docs (bring your own API key), Continue v2.0.0-vscode docs, Cline v4.1.23 docs, Roo Code v3.54.0 docs, Kilo Code v7.8.8 docs, 2026-10-11

Stack notes only. Per-client config, capability flags and troubleshooting live in the product skills.

## How they plug into this stack

The first question: does the request leave from the user's machine or from the vendor's cloud? That decides whether `localhost` works.

| Extension | Request origin   | API sent                                                |
| --------- | ---------------- | ------------------------------------------------------- |
| Cursor    | Cursor's servers | OpenAI-style, chat models only                          |
| Continue  | User's machine   | Chat Completions; Responses for some OpenAI model names |
| Cline     | User's machine   | Chat Completions ("OpenAI Compatible")                  |
| Roo Code  | User's machine   | Chat Completions; project archived upstream, no skill   |
| Kilo Code | User's machine   | Chat Completions, Responses or Anthropic Messages       |

Stack pitfalls:

- Cursor needs a public HTTPS endpoint with its own budgeted virtual key; never expose the gateway master key.
- Declare context window, max output, tool and vision support for every non-catalog model; `/v1/models` carries none of it.
- Keep keys out of committed config (env var, `~/.continue/.env`, client secret store).
- Verify with an agent task that creates a file; watch the gateway log for the path and model name actually sent.

Depth:

- `cursor`: `npx skills add ScaleDockHQ/llm-skills --skill cursor`
- `continue`: `npx skills add ScaleDockHQ/llm-skills --skill continue`
- `cline`: `npx skills add ScaleDockHQ/llm-skills --skill cline`
- `kilo-code`: `npx skills add ScaleDockHQ/llm-skills --skill kilo-code`
