# Release runbook

How a PodLens release ships. The operator document; `docs/UPDATE.md`
explains the trust model.

## 0. Prerequisites (one-time)

- Ed25519 update key pair: `scripts/update-keys.sh` (stored outside the repo)
- GitHub secret `UPDATE_ED25519_PRIVATE_KEY` = the PEM contents:
  ```bash
  gh secret set UPDATE_ED25519_PRIVATE_KEY < ~/.podlens/update-signing-key.pem -R turlamai/podlens
  ```
- macOS production signing secrets (`DEVELOPER_ID_P12_B64`,
  `DEVELOPER_ID_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_P8_B64`) — a tag release **fails closed** without them;
  workflow_dispatch smoke builds may run ad-hoc without them
- (optional) Windows Authenticode certificate — release.yml labels the
  MSI unsigned when absent (family policy: optional)

## 1. Version bump

The root `VERSION` file and `racket/version.rkt` carry the same version;
bump both (`scripts/check-release-version.sh` enforces the alignment
locally, in CI and in the release pipeline). Add a matching `## X.Y.Z`
section to CHANGELOG.md — the tag validator rejects a tag without one.
The glaze carrier takes its installer identity from the release
workflow's `--version` flag, which reads `VERSION`.

## 2. Tagged pipeline

```bash
git tag -s v0.1.0 -m "PodLens 0.1.0"
git push origin v0.1.0
```

`.github/workflows/release.yml` then:

1. validates tag == VERSION == racket/version.rkt == CHANGELOG section,
   and reads the single-source `GLAZE_PIN` from `ci.yml`;
2. macOS (arm64 + x64 matrix): `raco glaze build --installer --sign
   --notarize` → notarized DMG (human installer) + ditto zip (update
   feed) + per-artifact sha256;
3. Windows: `raco glaze build --installer` → x64 MSI + staged portable
   zip + sha256;
4. Linux (x64 + arm64): `raco glaze build --installer` → deb/rpm/AppImage
   + staged tar.gz (`bin/` + `lib/` + `public/`); Flatpak bundle built
   from the staged tree against the pinned GNOME runtime;
5. release job: `scripts/make-update-manifest.sh` signs the single-file
   wrapper (`update-manifest.json`, five portable artifacts) with
   `raco glaze manifest-sign`; `raco glaze verify-release-assets`
   re-verifies every listed artifact against the staged files before
   publish; SHA256SUMS from the per-artifact sums;
   `gh release create --generate-notes`; Sigstore provenance attestation.

## 3. Publish checklist

- [ ] Release page lists per-arch DMG + zip (`podlens-<ver>-macos-{arm64,x64}.{dmg,zip}`),
      `podlens-<ver>-windows-x64.{msi,zip}`,
      `podlens-<ver>-linux-{x64,arm64}.{deb,rpm,AppImage,flatpak,tar.gz}`,
      per-artifact `.sha256`, the signed `update-manifest.json` wrapper
      and `SHA256SUMS` (20 lines: 16 distribution artifacts + 2 SBOMs +
      2 third-party notices)
- [ ] `raco glaze verify-release-assets update-manifest.json <dir> <pubkey>
      --base-url https://github.com/turlamai/podlens/releases/download/<tag>`
      passes with the PUBLIC key only
- [ ] Previous-version install reports "update available" on manual check
- [ ] `appimage-upgrade-qualification.yml` dispatched on the new pair of
      published releases: evidence artifact green on both architectures
- [ ] Site download copy matches the release (platform/arch coverage)

## 4. Rollback

Never re-upload an artifact under an existing version URL — hashes are
pinned by the signed manifest. Pull = publish a new patch version whose
signed manifest points at it. User-side rollback is the documented
install-form path in reverse (keep the previous tree/installer); the
qualification workflow executes and boots it.