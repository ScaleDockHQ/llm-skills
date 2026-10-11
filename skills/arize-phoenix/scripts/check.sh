#!/usr/bin/env bash
# Read-only Phoenix health check. Never prints secrets.
# Usage: PHOENIX_HOST_URL=http://localhost:6006 [PHOENIX_API_KEY_FILE=~/.phoenix.key] scripts/check.sh
# Needs bash 3.2+, curl and jq.
set -u

base="${PHOENIX_HOST_URL:-${PHOENIX_COLLECTOR_ENDPOINT:-http://localhost:6006}}"
base="${base%/v1/traces}"
base="${base%/}"
key_file="${PHOENIX_API_KEY_FILE:-}"
fail=0

ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }
note() { printf 'note  %s\n' "$1"; }

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

if curl -fsS -m 5 "$base/healthz" >/dev/null 2>&1; then ok "liveness $base/healthz"; else bad "liveness $base/healthz unreachable"; fi

ready_code="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "$base/readyz" 2>/dev/null || echo 000)"
if [ "$ready_code" = "200" ]; then ok "readiness (database answers)"; else bad "readiness returned HTTP $ready_code (503 means the database is unreachable)"; fi

version="$(curl -fsS -m 5 "$base/arize_phoenix_version" 2>/dev/null | tr -d '"' || true)"
if [ -n "$version" ]; then ok "server version $version"; else note "version endpoint not answering"; fi

auth_args=()
if [ -n "$key_file" ] && [ -r "$key_file" ]; then
  auth_args=(-H "Authorization: Bearer $(tr -d '\n' < "$key_file")")
  ok "using API key from file (value not shown)"
fi

code="$(curl -sS -m 5 -o /tmp/phoenix-projects.$$ -w '%{http_code}' ${auth_args[@]+"${auth_args[@]}"} "$base/v1/projects" 2>/dev/null || echo 000)"
case "$code" in
  200)
    names="$(jq -r '.data[]?.name' /tmp/phoenix-projects.$$ 2>/dev/null | tr '\n' ' ')"
    ok "projects: ${names:-none yet}"
    if [ "${#auth_args[@]}" -eq 0 ]; then note "no key sent and the API answered: authentication appears to be off"; fi
    ;;
  401|403)
    if [ "${#auth_args[@]}" -eq 0 ]; then note "authentication is on; set PHOENIX_API_KEY_FILE to a 0600 file holding a system API key"; else bad "API key rejected (HTTP $code)"; fi
    ;;
  *) bad "projects endpoint returned HTTP $code" ;;
esac
rm -f /tmp/phoenix-projects.$$

exit "$fail"
