#!/usr/bin/env bash
# Release preflight: every release identity on this tree must name the same
# version (taskly-family gate). Runs without racket, so CI and every release
# job can call it before any packaging step.
#
#   scripts/check-release-version.sh [tag]     e.g. scripts/check-release-version.sh v0.7.5
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="${1:-}"

fail() {
  echo "release preflight: $*" >&2
  exit 1
}

[[ -n "$VERSION" ]] || fail "VERSION is empty"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || \
  fail "VERSION '$VERSION' is not a supported semantic version"

if [[ -n "$TAG" ]]; then
  TAG_VERSION="${TAG#v}"
  [[ "$TAG_VERSION" == "$VERSION" ]] || \
    fail "tag '$TAG' does not match VERSION '$VERSION'"
fi

# The Rivet app manifest carries the product version on this tree.
RIVET_RKTD_VERSION="$(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' "$ROOT/rivet.rktd" | head -n1 | tr -d '"')"
[[ "$RIVET_RKTD_VERSION" == "$VERSION" ]] || \
  fail "rivet.rktd version '$RIVET_RKTD_VERSION' does not match VERSION '$VERSION'"

# The backend version module embeds the release identity for the RPC, the
# CLI and the update feed.
grep -qF "(define app-version \"$VERSION\")" "$ROOT/app/version.rkt" || \
  fail "app/version.rkt app-version does not match VERSION '$VERSION'"

# The generated native clients embed the same release identity. These files
# are marked do-not-edit: a mismatch means the tree forgot to regenerate
# them after the version bump (regenerate with `raco rivet build`, never
# hand-edit).
check_generated_version() {
  local file="$1" pattern="$2" found
  found="$(grep -oE "$pattern" "$ROOT/$file" | head -n1 | grep -oE '"[^"]*"' | tr -d '"')"
  [[ "$found" == "$VERSION" ]] || \
    fail "generated file '$file' version '${found:-missing}' does not match VERSION '$VERSION' (regenerate, do not hand-edit)"
}
check_generated_version \
  "macos-host/Sources/RivetHost/GeneratedBackend.swift" \
  'public static let version = "[^"]+"'
check_generated_version \
  "windows/GeneratedBackend.hpp" \
  'kVersion\[\] = "[^"]+"'
check_generated_version \
  "linux/GeneratedBackend.hpp" \
  'kVersion\[\] = "[^"]+"'

echo "release preflight: version $VERSION is aligned (VERSION == rivet.rktd == app/version.rkt == generated clients)"
