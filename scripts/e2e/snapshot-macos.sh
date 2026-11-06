#!/usr/bin/env bash
set -euo pipefail

# Deterministic design evidence for macOS, no Screen Recording permission.
# Renders Home / episodes / reading / Discover at two window sizes plus every
# Settings tab, using the synthetic showcase library.

repo="$(cd "$(dirname "$0")/../.." && pwd)"
app="${PODLENS_APP:-$repo/.rivet/stage/RivetHost}"
out="${1:-$repo/.rivet/evidence/macos-0.6}"
[[ -x "$app" ]] || { echo "snapshot: app not built: $app" >&2; exit 1; }

data="$(mktemp -d)"
mkdir -p "$out"
export PODLENS_DATA_DIR="$data"
cat >"$data/config.json" <<'JSON'
{"ui-lang":"en","check-updates-enabled":"false","last-update-check":2000000000,"api-key":"sk-snapshot-demo"}
JSON
racket "$repo/scripts/e2e/seed-showcase.rkt"

cleanup() {
  local status=$?
  trap - EXIT
  if [[ -f "$data/config.json" ]]; then
    local ref store
    ref="$(sed -n 's/.*"api-key-ref":"\([^"]*\)".*/\1/p' "$data/config.json")"
    store="$(sed -n 's/.*"api-key-store":"\([^"]*\)".*/\1/p' "$data/config.json")"
    if [[ "$store" == "keychain" && -n "$ref" ]]; then
      /usr/bin/security -i >/dev/null 2>&1 <<<"delete-generic-password -s \"PodLens\" -a \"$ref\""
    fi
  fi
  rm -rf "$data"
  exit "$status"
}
trap cleanup EXIT

run() {
  local dir="$1"; shift
  mkdir -p "$dir"
  env PODLENS_SNAPSHOT_DIR="$dir" "$@" "$app" >/dev/null 2>&1 &
  local pid=$!
  local i
  for i in $(seq 1 40); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
    echo "snapshot: timed out for $dir" >&2
  fi
  wait "$pid" 2>/dev/null || true
}

run "$out/en" PODLENS_LANG=en PODLENS_SNAPSHOT_SIZE=1280x800 PODLENS_SNAPSHOT_SETTINGS=0
run "$out/zh" PODLENS_LANG=zh PODLENS_SNAPSHOT_SIZE=1280x800 PODLENS_SNAPSHOT_SETTINGS=0
run "$out/compact-1024" PODLENS_LANG=en PODLENS_SNAPSHOT_SIZE=1024x768 PODLENS_SNAPSHOT_SETTINGS=0

for tab in general intelligence advanced about; do
  dir="$out/settings/$tab"
  run "$dir" PODLENS_LANG=en PODLENS_SNAPSHOT_SIZE=1280x800 \
      PODLENS_SETTINGS_TAB="$tab" PODLENS_SNAPSHOT_SETTINGS=1
  mv "$dir/settings.png" "$out/settings/$tab.png" 2>/dev/null || true
  rm -rf "$dir"
done

echo "snapshots written to $out"
