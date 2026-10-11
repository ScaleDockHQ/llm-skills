# Operate and tear down

> Verified against modal 1.6.1, Modal docs (CLI reference for modal app, server, endpoint, volume, secret and workspace proxy-tokens; Apps guide), 2026-10-11

## Watch health and cost

```bash
modal app list
modal server info <app>/<server>
modal server logs <app>/<server> -f
modal endpoint stats <name> --since 2h        # best-effort, may be delayed
modal billing rates                            # live rates; do not copy numbers into notes
```

## Update and roll back

```bash
modal deploy app.py                            # a new version replaces the old
modal app history <app>
modal app rollback <app> [vN] --strategy rolling
modal app rollover <app> --strategy rolling    # fresh containers, same code
```

A redeploy resets any `update_autoscaler` changes. Change the model or the vLLM pin by editing the app, deploying, testing through the gateway, then retiring the old app.

## Teardown order

1. `modal app stop <app> --yes` for deployed Servers, or `modal endpoint stop <name> --yes` for Dedicated Endpoints. Both are permanent.
2. Remove the gateway entry; stop the LiteLLM container if it was started only for this.
3. Delete Volumes you created, after copying anything you need: `modal volume delete <name>` (bills until deleted).
4. Delete the Secret and revoke the proxy token if no longer needed: `modal secret delete <name>`, `modal workspace proxy-tokens delete <token-id> --yes`; remove the `0600` token file.
5. Verify: `modal app list`, `modal endpoint list`, `modal volume list`, `modal secret list`, `modal workspace proxy-tokens list`. The full ordered list is in the `modal` skill's teardown reference; repeat with `-e <env>` for each Environment used.
