# Contributing to PodLens

Thank you for looking under the hood. PodLens is free software
(AGPL-3.0, see [LICENSE](LICENSE)): by submitting a pull request you
agree your contribution is licensed under AGPL-3.0.

PodLens follows the Rivet application architecture: Racket owns domain
logic, native hosts own UI, and the contract between them lives in
`racket/backend.rkt` (RVT1) plus `rivet-schema.json`. Keep that split
intact.

## Ground rules

1. **The wire contract is cross-platform.** Changing any RPC/State in
   `racket/backend.rkt` is a three-platform release: regenerate the
   checked-in clients with `raco rivet build`
   (`macos-host/Sources/RivetHost/GeneratedBackend.swift`,
   `windows/GeneratedBackend.hpp`, `linux/GeneratedBackend.hpp`) in the
   same commit — they are build inputs, never hand-edit them.
2. **Update trust has two roots and they must agree.** The Ed25519
   public key and the exact key id (`podlens-2026-10`) are pinned in
   both `racket/update.rkt` and
   `macos-host/Sources/RivetHost/UpdateService.swift`; the release
   workflow fails closed unless the signing secret matches both. Never
   weaken a verification step (signature, key id, size, SHA-256) to
   make a change green.
3. **Secrets degrade honestly.** The BYOK API key lives in the OS
   secret vault (Keychain / DPAPI / Secret Service) with a labelled
   0600-file fallback
   (`racket/core/secrets.rkt`); a locked vault must never take the app or
   a CLI command down. The raw key value is never displayed, logged or
   returned — settings show the mask, the mask itself is refused as a
   write, and the key travels only as the `Authorization: Bearer`
   header to the user-configured `api-base`.
4. **Privacy is a feature.** Library, audio, transcripts and summaries
   stay on disk under the platform data directory. The only network
   traffic is feed/catalog fetches, the user's own AI endpoint, and the
   signed update feed. No telemetry, no accounts.
5. **Fail honestly.** A bad feed, an unavailable provider or a failed
   update verification reports what failed and what to do next — no
   silent fallbacks; a failed update aborts and the running version
   keeps working.
6. **Tests pin contracts.** If you change behavior a test covers,
   change the test in the same commit and say why.

## Before you push

```bash
raco test tests/                       # backend contract tests
raco make racket/backend.rkt              # backend compiles against the RVT1 contract
bash scripts/check-release-version.sh  # VERSION == rivet.rktd == racket/version.rkt == generated clients
racket scripts/verify-catalog.rkt      # catalog feeds must parse on the live wire
```

These mirror the CI jobs; the platform hosts compile in their own CI
jobs. If you touch `macos-host/`, `windows/` or `linux/`, say whether
you were able to build locally.

## Releasing

Releases are tag-driven (`v*`). A release bump moves `VERSION`,
`rivet.rktd` and `racket/version.rkt` in the same commit and regenerates
the clients — `scripts/check-release-version.sh` enforces all four
identities and the dated CHANGELOG entry. The pipeline refuses to
publish without the Ed25519 update signing key and signs one merged
feed from the publish job.

## Areas that especially want help

- Linux playback polish: the GStreamer plugin closure and AppImage
  bundling (`linux/CMakeLists.txt`, `scripts/e2e/e2e-linux.sh`)
- Keeping the Chinese user path in lockstep with the English one
  (`README.zh-CN.md`, `docs/USER-GUIDE.zh-CN.md`) — the language policy
  in [AGENTS.md](AGENTS.md) requires reciprocal updates

## Reporting issues

Include: OS + version, PodLens version (Settings ▸ About or
`podlens version`), install shape (DMG / portable zip / MSI /
AppImage / deb / rpm / tarball), steps to reproduce, and the provider
error text for AI-pipeline issues (redact your API key — reports
should never contain it). Security issues go through
[SECURITY.md](SECURITY.md), not public issues.
