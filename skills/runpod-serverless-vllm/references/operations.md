# Operate and tear down

> Verified against runpodctl v2.15.0 (serverless, template, network-volume references), docs.runpod.io (endpoint configurations), 2026-10-11

## Watch health and cost

```bash
runpodctl serverless list
runpodctl serverless health <id>              # workers ready/running/idle and queue depth
runpodctl serverless logs <id>
runpodctl user | jq 'del(.email, .id)'        # spend per hour against the baseline
```

Defaults that decide cost (from the endpoint configuration docs, re-check them): active workers 0, max workers 3, idle timeout 5 s, execution timeout 600 s. Set a lower max than the default for this stack.

## Update

```bash
runpodctl serverless update <id> --workers-max 2
```

To change the model or image tag, create a new template and endpoint, test it, move the gateway, then delete the old pair. A Serverless template binds to one endpoint.

## Teardown order

1. Drain: `runpodctl serverless update <id> --workers-max 0`.
2. Delete the endpoint, then its template; confirm the subcommands with `runpodctl serverless --help` and `runpodctl template --help`.
3. Delete any network volume you created, after copying data you need.
4. Remove the gateway entry and stop the LiteLLM container if it was started only for this.
5. Verify: `runpodctl serverless list`, `runpodctl network-volume list` and `runpodctl user` (spend per hour back to baseline). The full list is in the `runpod` skill's teardown reference.
