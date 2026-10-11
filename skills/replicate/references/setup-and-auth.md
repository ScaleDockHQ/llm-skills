# Replicate setup and auth

> Verified against replicate.com/docs topics/api-tokens, reference/http, reference/client-libraries, reference/mcp, replicate/cli README, 2026-10-11

Replicate joined Cloudflare in November 2025 and remains a distinct brand. The API is unchanged. Cloudflare has said it plans to bring the Replicate catalog to Workers AI, so check https://replicate.com/docs for news before assuming today's layout lasts.

## Token

- Create and disable tokens at https://replicate.com/account/api-tokens. Tokens start with `r8_`.
- Replicate scans GitHub and disables tokens it finds leaked. Never commit one.
- Header: `Authorization: Bearer $REPLICATE_API_TOKEN`.

```bash
mkdir -p ~/.config/replicate && chmod 700 ~/.config/replicate
umask 077
read -rs T && printf '%s' "$T" > ~/.config/replicate/token && unset T
export REPLICATE_API_TOKEN="$(cat ~/.config/replicate/token)"
curl -sS https://api.replicate.com/v1/account -H "Authorization: Bearer $REPLICATE_API_TOKEN" | jq 'keys'
```

The official clients and the CLI read `REPLICATE_API_TOKEN` from the environment. The LiteLLM provider reads `REPLICATE_API_KEY`.

## Clients

| Client    | Install                                                       | Notes                                                                                                                          |
| --------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Python    | `pip install replicate`                                       | `replicate.run("owner/model", input={...})`                                                                                    |
| Node      | `npm install replicate`                                       | Same shape                                                                                                                     |
| Go, Swift | see https://replicate.com/docs/reference/client-libraries     |                                                                                                                                |
| CLI       | `brew tap replicate/tap && brew install replicate`            | Commands for hardware, model, prediction, scaffold, training. `run`, `stream` and `train` aliases. Reads `REPLICATE_API_TOKEN` |
| MCP       | remote `https://mcp.replicate.com`, or `npx -y replicate-mcp` | See the MCP page for client setup                                                                                              |

Check the installed version with `pip show replicate`, `npm ls replicate`, `replicate --version`, and pin it. The clients cannot delete deployments. Use HTTP for that.

## Cog

Cog packages a model as a container. Install per https://github.com/replicate/cog (the docs show downloading the release binary for your OS and architecture). Check `cog --version`. Cog needs Docker.

Log in before pushing: `cog login` (it prompts for a token. Do not paste tokens in shell history).

## Which endpoint host

Everything lives at `https://api.replicate.com/v1`. Streaming output uses URLs returned in the prediction (`stream.replicate.com`).

## Verify

- [ ] `GET /v1/account` returns 200.
- [ ] The token file is `0600`.
- [ ] You know whether the account is prepaid credit or billed in arrears (`references/billing-and-teardown.md`).
