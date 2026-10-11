# fal setup and auth

> Verified against fal.ai/docs quickstart, authentication (key-based), setting-up/genmedia, development/getting-started/installation, serverless/index, llms.txt, 2026-10-11

fal docs live at https://fal.ai/docs (index at https://fal.ai/docs/llms.txt, pages are also available as markdown).

## Two products

- **Model APIs:** 1,000+ hosted models, mainly image, video, audio and 3D, plus some LLMs. A free account is enough and no approval is needed.
- **Serverless:** deploy your own Python `fal.App` on fal GPUs. Access is approved per account: request it at https://fal.ai/dashboard/serverless-get-started.

## Keys

- Create keys at https://fal.ai/dashboard/keys. Header: `Authorization: Key $FAL_KEY` (note `Key`, not `Bearer`). The clients read `FAL_KEY`.
- Presets: `API`, `SERVERLESS`, `DEPLOY`, `COMPUTE`, `BILLING`, `READONLY`, `FULL`. Pick the narrowest one. At creation a key can get an expiry (1 hour to 1 year) and a list of allowed models.
- Keys belong to the account or to a team.
- Store the key in a `0600` file:

```bash
mkdir -p ~/.config/fal && chmod 700 ~/.config/fal
umask 077
read -rs K && printf '%s' "$K" > ~/.config/fal/key && unset K
export FAL_KEY="$(cat ~/.config/fal/key)"
```

- Never put `FAL_KEY` in browser code. Run a small server-side proxy and call fal from it.
- `app_auth="public"` on a serverless app allows unauthenticated calls, so use it only on purpose.

## Clients

```bash
pip install fal-client          # Python: fal_client.subscribe / run / submit
npm install @fal-ai/client      # JavaScript
```

Swift, Kotlin and Dart clients also exist. Pin versions in your lockfile.

## genmedia CLI

`genmedia` is a separate CLI for discovering and running models (it is not the `fal` serverless CLI).

```bash
curl https://genmedia.sh/install -fsS | bash    # read the script first if your policy needs it
genmedia setup                                   # interactive. Non-interactive: --non-interactive --no-save-key with FAL_KEY set
genmedia models "flux" --limit 5
genmedia schema <endpoint-id>
genmedia run ...                                 # see genmedia run --help
```

Output is JSON when piped or with `--json`. Check `genmedia --help` for current flags. An MCP server with OAuth is also available from fal's docs.

## Serverless CLI

```bash
pip install fal                 # Python 3.8+
fal --version
fal auth login                  # or use FAL_KEY with a SERVERLESS or FULL preset
fal auth whoami
fal team list ; fal team set <team> ; fal team unset
fal profile ...                 # see fal profile --help
```

## Verify

- [ ] `curl -sS https://fal.run/<small-model-id> -H "Authorization: Key $FAL_KEY" ...` or a queue submit returns a response, not 401.
- [ ] `fal auth whoami` prints the expected account or team.
- [ ] Concurrency limit is known (`references/billing-and-teardown.md`).
