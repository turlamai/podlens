# Security Policy

PodLens processes podcasts on your machine: subscriptions, playback
positions, downloaded audio, transcripts and summaries are local files,
and the only network traffic is what you point it at — podcast feeds,
the iTunes catalog, your own OpenAI-compatible AI endpoint, and the
signed update feed. Reports are taken seriously and handled quickly.

## Reporting a vulnerability

Email **security@jrtx.site** (or open a GitHub security advisory on this
repository). Include reproduction steps, affected versions, and your
assessment of impact. You will get an acknowledgment within 72 hours.

Please do not open public issues for security problems.

## Scope

In scope:

- **Your LLM API key (BYOK)** (`racket/core/secrets.rkt`,
  `racket/core/config.rkt`, `racket/core/openai.rkt`): the key is yours, not
  ours — PodLens never ships one and has no provider account. Storage
  goes to the OS secret vault where one is available (macOS Keychain,
  Windows DPAPI CurrentUser scope, Linux Secret Service via
  `secret-tool`), with an honestly-labelled 0600 file fallback;
  `config.json` keeps only an opaque `api-key-ref` plus the owning
  backend's name, and the ≤0.5.x plaintext-in-config layout is migrated
  out in one rewrite. Transmission: the key travels only as the
  `Authorization: Bearer` header to the **user-configured** `api-base`
  (`/chat/completions`, `/audio/transcriptions`, `/models`) — the audio
  file itself is uploaded to that same endpoint. A report that the key
  lands anywhere else (logs, transcripts, telemetry, a hardcoded host,
  or a request to a URL you did not configure) is a critical bug.
- **Update trust** (`racket/update.rkt`,
  `macos-host/Sources/RivetHost/UpdateService.swift`,
  `scripts/make-update-manifest.sh`; key id `podlens-2026-10`):
  verification of the Ed25519-signed `update-manifest.json` and its
  artifacts, the pinned public key + exact key ID duplicated in both
  trust roots (backend and the macOS host — the release workflow fails
  closed unless the signing key matches both), size and SHA-256 checks
  before any install, and the host-owned install/rollback steps. The
  4-hour silent-check throttle lives in the hosts; nothing downloads or
  quits without explicit user action.
- **Local data handling** (`racket/core/paths.rkt`,
  `racket/core/library.rkt`): `library.json` (subscriptions, episodes,
  playback positions), the `audio/` cache, `transcripts/<id>.json`
  (segments, translation, summary) and `chapters/<id>.json` — all under
  the platform data directory, never uploaded anywhere, never synced.
- **Feed and catalog fetching** (`racket/core/feed.rkt`,
  `racket/core/itunes.rkt`): the app fetches exactly the feeds you
  subscribe to and the iTunes search/catalog endpoints; it sends no
  library contents, transcripts or identifiers beyond the request
  itself.
- **The host/backend boundary**: hosts render and install; the Racket
  backend (`racket/backend.rkt`) decides. Crypto or trust decisions
  sneaking into a native host are a bug (update verification lives in
  the backend and its `rivet/distribution` layer).

Out of scope: the security of your chosen AI provider, podcast hosts
and feed content, social engineering, and physical access attacks.

## Design notes reviewers should know

- The masked settings value (`••••••••`) is a display convention: the
  backend refuses a masked value as a *write* and never returns raw key
  material except to the AI client itself.
- Secret storage degrades instead of raising: a locked Keychain or an
  absent session bus disables AI features with an honest "stored in a
  local 0600 file" label rather than crashing or silently falling back
  to plaintext config.
- The signed update feed **does not imply a publisher-signed
  installer**: macOS builds are ad-hoc signed (not notarized) and
  Windows binaries carry no Authenticode signature by default. Releases
  publish a checked `SHA256SUMS` file and Sigstore build-provenance
  attestations; verify downloads with those.
- Update downloads land under `<data-dir>/updates/` and never touch
  `config.json`, `library.json` or the audio cache; verification runs
  before anything executes.
- Nothing here is telemetry. The update check reveals nothing about
  your library; AI requests contain only the episode text/audio you
  explicitly send for processing, addressed to the endpoint you set.

## Supported versions

Security fixes land on `main` first and ship with the next tagged
release. During the 0.x preview there is no LTS branch.
