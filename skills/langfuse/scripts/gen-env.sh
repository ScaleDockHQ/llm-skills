#!/usr/bin/env bash
# Write a .env for assets/docker-compose.yaml with random secrets, mode 0600.
# Usage: scripts/gen-env.sh [path]   (default ./.env; refuses to overwrite)
# Needs bash 3.2+ and openssl. Prints only the path, never a secret.
set -euo pipefail

out="${1:-.env}"
[ -e "$out" ] && { echo "error: $out exists; refusing to overwrite" >&2; exit 1; }

umask 077
{
  echo "LANGFUSE_TAG=${LANGFUSE_TAG:-4.56.0}"
  echo "NEXTAUTH_URL=${NEXTAUTH_URL:-http://localhost:3000}"
  echo "NEXTAUTH_SECRET=$(openssl rand -base64 32)"
  echo "SALT=$(openssl rand -base64 32)"
  echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
  # hex keeps passwords safe inside DATABASE_URL (no characters that need URL encoding)
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
  echo "CLICKHOUSE_PASSWORD=$(openssl rand -hex 24)"
  echo "MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)"
  echo "REDIS_AUTH=$(openssl rand -hex 24)"
} > "$out"
chmod 600 "$out"
echo "wrote $out (mode 600)"
