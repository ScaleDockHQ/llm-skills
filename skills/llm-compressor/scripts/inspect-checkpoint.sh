#!/usr/bin/env bash
# Summarize the quantization config of a local checkpoint dir or a Hugging Face repo.
# Usage: inspect-checkpoint.sh <dir-or-hub-id> [revision]
# Needs bash 3.2+, jq, and curl for Hub ids. HF_TOKEN (if set) is sent as a header and never printed.
set -euo pipefail

target="${1:-}"
rev="${2:-main}"
[ -n "$target" ] || { echo "usage: $0 <dir-or-hub-id> [revision]" >&2; exit 2; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

fetch() { # fetch <file>; prints content or nothing if missing
  local name="$1"
  if [ -d "$target" ]; then
    [ -f "$target/$name" ] && cat "$target/$name" || true
  else
    command -v curl >/dev/null || { echo "error: curl is required for Hub ids" >&2; exit 1; }
    local url="https://huggingface.co/$target/resolve/$rev/$name"
    if [ -n "${HF_TOKEN:-}" ]; then
      curl -fsSL -H "Authorization: Bearer $HF_TOKEN" "$url" 2>/dev/null || true
    else
      curl -fsSL "$url" 2>/dev/null || true
    fi
  fi
}

cfg="$(fetch config.json)"
[ -n "$cfg" ] || { echo "no config.json found for $target" >&2; exit 1; }

echo "model: $target"
echo "$cfg" | jq -r '"architectures: \((.architectures // []) | join(", "))\ndtype: \(.torch_dtype // .dtype // "unknown")"'

if echo "$cfg" | jq -e '.quantization_config' >/dev/null 2>&1; then
  echo "--- quantization_config"
  echo "$cfg" | jq -r '.quantization_config
    | "quant_method: \(.quant_method // "unknown")",
      "format: \(.format // "n/a")",
      "quantization_status: \(.quantization_status // "n/a")",
      "kv_cache_scheme: \(if .kv_cache_scheme then (.kv_cache_scheme | tostring) else "none" end)",
      "ignore (\((.ignore // []) | length) entries, first 8): \(((.ignore // []) | .[:8]) | join(", "))",
      "config_groups:",
      ((.config_groups // {}) | to_entries[] |
        "  \(.key): targets=\(.value.targets | tostring) weights=\((.value.weights // {}) | {num_bits,type,strategy,group_size,symmetric,dynamic} | tostring) input_activations=\(((.value.input_activations // {}) | {num_bits,type,strategy,group_size,symmetric,dynamic}) | tostring)")'
else
  echo "no quantization_config in config.json (unquantized, or a ModelOpt checkpoint)"
fi

hq="$(fetch hf_quant_config.json)"
if [ -n "$hq" ]; then
  echo "--- hf_quant_config.json (NVIDIA Model Optimizer)"
  echo "$hq" | jq -r '.quantization | "quant_algo: \(.quant_algo // "n/a")", "kv_cache_quant_algo: \(.kv_cache_quant_algo // "none")", "group_size: \(.group_size // "n/a")", "exclude_modules: \((.exclude_modules // []) | join(", "))"'
fi
