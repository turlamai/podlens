#!/usr/bin/env bash
# Release preflight: every release identity on this tree must name the same
# version (taskly-family gate). Runs without racket, so CI and every release
# job can call it before any packaging step.
#
#   scripts/check-release-version.sh [tag]     e.g. scripts/check-release-version.sh v0.1.0
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

# The backend version module embeds the release identity for the RPC, the
# CLI and the update feed. The glaze carrier takes its installer identity
# from the release workflow's --version flag, which reads this same VERSION
# file (glaze.rktd only declares the schema contract, not the version).
grep -qF "(define app-version \"$VERSION\")" "$ROOT/racket/version.rkt" || \
  fail "racket/version.rkt app-version does not match VERSION '$VERSION'"

echo "release preflight: version $VERSION is aligned (VERSION == racket/version.rkt == glaze build --version)"