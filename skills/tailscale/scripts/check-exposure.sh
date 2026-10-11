#!/usr/bin/env bash
# check-exposure.sh - read-only audit of what an LLM host exposes.
#
# Lists TCP listeners that are not bound to loopback (engine ports should be
# 127.0.0.1 only) and prints the Tailscale Serve and Funnel configuration.
# Never prints secrets. Dependencies: bash 3.2+, and ss or lsof; tailscale and
# jq are optional.
#
# Usage: check-exposure.sh [port ...]
#   With no ports, the usual LLM ports are checked:
#   4000 8000 8080 8088 8089 11434 5555

set -u

PORTS=("$@")
[ "${#PORTS[@]}" -gt 0 ] || PORTS=(4000 8000 8080 8088 8089 11434 5555)

listeners() {
  if command -v ss >/dev/null 2>&1; then
    ss -H -tln 2>/dev/null | awk '{print $4}'
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $9}'
  else
    echo "check-exposure: need ss or lsof" >&2
    return 1
  fi
}

echo "== listeners on LLM ports (only 127.0.0.1 / ::1 is acceptable)"
bad=0
all=$(listeners) || exit 2
for p in "${PORTS[@]}"; do
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    case "$addr" in
      *":$p") ;;
      *) continue ;;
    esac
    case "$addr" in
      127.0.0.1:*|\[::1\]:*|localhost:*)
        echo "ok     $addr" ;;
      *)
        echo "OPEN   $addr   <- reachable beyond loopback"
        bad=1 ;;
    esac
  done <<EOF
$all
EOF
done

if command -v tailscale >/dev/null 2>&1; then
  echo
  echo "== tailscale serve status"
  tailscale serve status 2>&1 | head -20
  echo
  echo "== tailscale funnel status (anything listed is PUBLIC)"
  tailscale funnel status 2>&1 | head -20
  if command -v jq >/dev/null 2>&1; then
    echo
    echo "== node"
    tailscale status --json 2>/dev/null |
      jq -r '"name: \(.Self.DNSName // "?")\ntags: \((.Self.Tags // []) | join(","))\nkey expiry: \(.Self.KeyExpiry // "none (expiry disabled or tagged)")"'
  fi
else
  echo
  echo "tailscale not installed: skipping Serve and Funnel checks"
fi

[ "$bad" = 0 ] && echo && echo "result: no LLM port is open beyond loopback" && exit 0
echo
echo "result: at least one LLM port is open beyond loopback (see OPEN lines)"
exit 1
