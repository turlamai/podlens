#!/usr/bin/env bash
# Build update-manifest.json for a release and sign it (docs/UPDATE.md).
#
#   scripts/make-update-manifest.sh <tag> <dist-dir> [key-path]
#
#   <tag>       release tag, e.g. v1.4.0 (must match the VERSION file)
#   <dist-dir>  directory containing the release artifacts, i.e. the names
#               the release pipeline produces:
#                 podlens-<ver>-macos-arm64.zip   podlens-<ver>-macos-x64.zip
#                 podlens-<ver>-windows-x64.zip
#                 podlens-<ver>-linux-x64.tar.gz
#                 podlens-<ver>-linux-arm64.tar.gz
#               (the DMG/MSI/deb/rpm/AppImage are human installers, not feed
#               entries; Linux hosts update through the tar.gz)
#   <key-path>  Ed25519 private key PEM (default: $UPDATE_KEY_PATH, then
#               ~/.podlens/update-signing-key.pem)
#
# The signing, artifact hashing, schema validation, and feed format live in
# `raco rivet sign-manifest`; this wrapper keeps PodLens' five artifacts,
# identity, and the Windows Git Bash path handling.
set -euo pipefail

TAG="${1:?usage: make-update-manifest.sh <tag> <dist-dir> [key-path]}"
DIST="${2:?usage: make-update-manifest.sh <tag> <dist-dir> [key-path]}"
KEY="${3:-${UPDATE_KEY_PATH:-$HOME/.podlens/update-signing-key.pem}}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git Bash hands out msys-style paths (/d/...), which Racket's path
# primitives misread as drive-relative; convert to Windows mixed form.
if command -v cygpath >/dev/null 2>&1; then
  ROOT="$(cygpath -m "$ROOT")"
  DIST="$(cygpath -m "$DIST")"
  KEY="$(cygpath -m "$KEY")"
fi

VERSION="${TAG#v}"
cd "$ROOT"
raco rivet check-release-version "$TAG"

APP_ID="$(sed -nE 's/.*\(identifier \. "([^"]+)"\).*/\1/p' "$ROOT/rivet.rktd" | head -n1)"
BUILD="$(sed -nE 's/.*\(build \. ([0-9]+)\).*/\1/p' "$ROOT/rivet.rktd" | head -n1)"
[[ -n "$APP_ID" && -n "$BUILD" ]] || {
  echo "error: could not read application id/build from rivet.rktd" >&2
  exit 1
}
[[ -f "$KEY" ]] || {
  echo "error: missing signing key $KEY (see scripts/update-keys.sh)" >&2
  exit 1
}

BASE_URL="${RELEASE_ASSET_BASE_URL:-https://github.com/turlamai/podlens/releases/download/$TAG}"

# Ed25519 needs OpenSSL 3+ (macOS ships LibreSSL, which cannot do it).
OPENSSL_BIN="${OPENSSL_BIN:-}"
if [[ -z "$OPENSSL_BIN" ]]; then
  for candidate in /opt/homebrew/opt/openssl@3/bin/openssl \
                   /usr/local/opt/openssl@3/bin/openssl openssl; do
    if command -v "$candidate" >/dev/null 2>&1 \
       && "$candidate" version 2>/dev/null | grep -q "OpenSSL 3"; then
      OPENSSL_BIN="$candidate"
      break
    fi
  done
fi
[[ -n "$OPENSSL_BIN" ]] || {
  echo "error: OpenSSL 3.x required for Ed25519 (brew install openssl@3," >&2
  echo "       or set OPENSSL_BIN=/path/to/openssl)" >&2
  exit 1
}

KEY_DER="$(mktemp "${TMPDIR:-/tmp}/podlens-key-XXXXXX.der")"
command -v cygpath >/dev/null 2>&1 && KEY_DER="$(cygpath -m "$KEY_DER")"
trap 'rm -f "$KEY_DER"' EXIT

# rivet's signer reads DER (OneAsymmetricKey); convert the PEM once here.
"$OPENSSL_BIN" pkey -in "$KEY" -outform DER -out "$KEY_DER"

raco rivet sign-manifest \
  --application-id "$APP_ID" \
  --version "$VERSION" \
  --build "$BUILD" \
  --channel stable \
  --base-url "$BASE_URL" \
  --key-id podlens-2026-10 \
  --private-key "$KEY_DER" \
  --output "$DIST/update-manifest.json" \
  --artifact "macos:arm64:zip:$DIST/podlens-$VERSION-macos-arm64.zip" \
  --artifact "macos:x64:zip:$DIST/podlens-$VERSION-macos-x64.zip" \
  --artifact "windows:x64:zip:$DIST/podlens-$VERSION-windows-x64.zip" \
  --artifact "linux:x64:targz:$DIST/podlens-$VERSION-linux-x64.tar.gz" \
  --artifact "linux:arm64:targz:$DIST/podlens-$VERSION-linux-arm64.tar.gz" \
  --rollback-allowed

echo "manifest: $DIST/update-manifest.json (5 artifacts, key-id podlens-2026-10)"
