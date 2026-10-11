# Install Weaviate

> Verified against Weaviate v1.40.0 (docs deploy/installation-guides/docker-installation, Docker Hub semitechnologies/weaviate tags), 2026-10-11

Latest release at the check date: v1.40.0 (2026-10-07). Images are `cr.weaviate.io/semitechnologies/weaviate:<version>`; Docker Hub tags seen: `1.40.0-<sha>`, `stable-v1.40-<sha>`, `1.39.11`, `latest`, plus `preview-*` builds. Pin an explicit version tag (the upstream docs template uses the current release); check the docs page for the exact current tag because Docker Hub also lists suffixed tags.

```bash
install -d -m 700 ~/weaviate && cd ~/weaviate
umask 077; printf 'AUTHENTICATION_APIKEY_ALLOWED_KEYS=%s\nAUTHENTICATION_APIKEY_USERS=admin\nOPENAI_APIKEY=%s\n' \
  "$(openssl rand -hex 24)" "placeholder" > weaviate.env   # OPENAI_APIKEY: the key your embeddings endpoint expects
docker compose up -d      # with templates/docker-compose.yml
```

Upstream's minimal one-liner is `docker run -p 8080:8080 -p 50051:50051 cr.weaviate.io/semitechnologies/weaviate:<version>`. Defaults it lists: `PERSISTENCE_DATA_PATH` is `./data`, `AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED` is `true`, `QUERY_DEFAULTS_LIMIT` is 10. That form is for tests only.

Key environment variables in the compose example: `PERSISTENCE_DATA_PATH=/var/lib/weaviate` (mount a volume there), `CLUSTER_HOSTNAME=node1`, `ENABLE_MODULES=text2vec-openai,backup-filesystem`, `AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=false`, `AUTHENTICATION_APIKEY_ENABLED=true`, `AUTHENTICATION_APIKEY_ALLOWED_KEYS`, `AUTHENTICATION_APIKEY_USERS`, `BACKUP_FILESYSTEM_PATH=/var/lib/weaviate/backups`, `PROMETHEUS_MONITORING_ENABLED=true` (metrics on port 2112 by default), `GOMEMLIMIT`.

Volumes: named volume `weaviate_data` or a host path mounted at `PERSISTENCE_DATA_PATH`. Without a mount, data disappears with the container.

Check:

```bash
curl -fsS http://127.0.0.1:8080/v1/.well-known/ready -o /dev/null -w '%{http_code}\n'
set -a; . ~/weaviate/weaviate.env; set +a
curl -fsS -H "Authorization: Bearer ${AUTHENTICATION_APIKEY_ALLOWED_KEYS%%,*}" http://127.0.0.1:8080/v1/meta | jq .version
```

Other paths: Kubernetes (Helm chart), Weaviate Cloud; see upstream docs.
