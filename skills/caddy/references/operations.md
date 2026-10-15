# Operations: reload, logs, metrics, update

> Verified against Caddy v2.11.7 (docs: Running Caddy, Command line, log directive, global options, metrics), 2026-10-11

## Change a config safely

```bash
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak
sudoedit /etc/caddy/Caddyfile
caddy fmt --diff /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
curl -sS -o /dev/null -w '%{http_code}\n' https://llm.example.com/v1/models
```

`reload` swaps config in place. WebSocket connections and long streams on the old config are closed unless `stream_close_delay` is set (`llm-reverse-proxy.md`). Changes to environment variables need `systemctl restart caddy`.

Note: `validate` loads the config and prints "Valid configuration" but also reads environment placeholders: run it with the same `EnvironmentFile` values or it may validate a different config.

## Logs

- Service output: `journalctl -u caddy --no-pager | less +G`.
- Access logs are off until a `log` directive is added to a site. JSON format, file output and rolling are options (see `assets/Caddyfile.llm-edge` for a `log` block with `output file` and `format json`).
- `Cookie`, `Set-Cookie`, `Authorization` and `Proxy-Authorization` are logged as `REDACTED` by default; `log_credentials` (global option) disables that: leave it off.
- Access logs record request metadata (URL, headers, status, duration), not bodies, to my reading of the log docs (not separately verified): prompts should not appear, but URLs and query strings do (use the `query` filter to replace values).
- Skip health-check noise with `log_skip` for a matcher on `/health*`.

## Metrics

Enable Prometheus metrics with the `metrics` global option (and per-server `metrics` in `servers`); they are served by the admin API at `/metrics` on the admin address (default `localhost:2019`). For LLM-level metrics (tokens, cost, latency per model) use the gateway and the `llm-observability` skill: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`. I did not verify the exact `metrics` option syntax in this pass: check the global options page before enabling.

## Update

```bash
caddy version
curl -fsS https://api.github.com/repos/caddyserver/caddy/releases/latest | jq -r '.tag_name, .published_at'
sudo apt update && sudo apt install --only-upgrade caddy      # apt install
sudo systemctl restart caddy && caddy version
```

Docker: pull the new tag and recreate. Binary or `.deb`: install the new one. Read the release notes first: https://github.com/caddyserver/caddy/releases. v2.11.7 added `Incremental: ?1` (RFC 10036) handling in `reverse_proxy` and `encode`; earlier 2.11.x behave without it.

Rollback: `sudo apt install caddy=<previous-version>` (list with `apt-cache policy caddy`), or reinstall the previous `.deb`, then restore `Caddyfile.bak`.

## Do not

- Expose the admin API (`localhost:2019` default). Disable it for loopback fronts with `admin off` (then `caddy reload` is unavailable: use `systemctl restart`).
- Run two Caddy instances against the same storage with different configs.

## Official links

- [Running Caddy](https://caddyserver.com/docs/running)
- [Command line](https://caddyserver.com/docs/command-line)
- [log directive](https://caddyserver.com/docs/caddyfile/directives/log)
- [Global options](https://caddyserver.com/docs/caddyfile/options)
- [Releases](https://github.com/caddyserver/caddy/releases)
