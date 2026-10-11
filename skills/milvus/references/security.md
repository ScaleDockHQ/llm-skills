# Milvus security

> Verified against Milvus v3.0.2 (configs/milvus.yaml common.security, milvus-docs authenticate and tls pages, standalone compose), 2026-10-11

Defaults to change before real use:

| Default                                                     | Why it matters                                              |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| `common.security.authorizationEnabled: false`               | Anyone who reaches 19530 has full access                    |
| `root` password `Milvus` (`defaultRootPassword`)            | Public default; clients use token `root:Milvus`             |
| MinIO `minioadmin` / `minioadmin`                           | Object storage holds every vector and index file            |
| Compose publishes 19530, 9091, 9000, 9001 on all interfaces | Exposes data, admin console and MinIO                       |
| `adminAuthEnabled: false`                                   | Port 9091 management, `/debug/pprof`, WebUI unauthenticated |

## Enable authentication

In `user.yaml` (mounted at `/milvus/configs/user.yaml`):

```yaml
common:
  security:
    authorizationEnabled: true
    adminAuthEnabled: true # protects /management/*, /log/level, /eventlog, pprof and the web console (HTTP Basic, root)
```

Restart the container. Connect with token `user:password` (pymilvus `token="root:<password>"`, REST header `Authorization: Bearer root:<password>`). Then change the root password immediately with `update_password` or the users API; do not rely on `defaultRootPassword` (upstream comments advise rotating root with UpdateCredential). Create per-application users and roles (RBAC) instead of using `root` in apps. Port 9091 stays plaintext: use a trusted network or TLS proxy, and when `adminAuthEnabled` is on, requests without an Origin must send `X-Milvus-Admin-Request: true`.

## MinIO keys

Set `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` on the MinIO container and `MINIO_ACCESS_KEY_ID` and `MINIO_SECRET_ACCESS_KEY` for Milvus (or `minio.accessKeyID` and `minio.secretAccessKey` in `user.yaml`); they must match. Keep the values in a `0600` env file.

## TLS

`proxy.tlsMode` (0 off, 1 one-way, 2 mutual), `proxy.serverPemPath`, `proxy.serverKeyPath`, `proxy.caPemPath`; internal TLS is separate (`common.security.internaltlsEnabled`). With both auth and TLS on, clients provide token and certificate paths. Alternatively terminate at a reverse proxy (`caddy`).

## Network

Publish `127.0.0.1:19530:19530` and `127.0.0.1:9091:9091`, or use the shared Docker network. Never publish etcd or MinIO. The embedded-etcd script also publishes 2379; remove that mapping.
