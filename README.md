# PodLens

Podcasts, in your language. A cross-platform desktop podcast player that transcribes, translates and summarizes English episodes with your own LLM API key — for listeners who understand far more reading than hearing.

[![CI](https://github.com/turlamai/podlens/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/podlens/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/turlamai/podlens)](https://github.com/turlamai/podlens/releases/latest) ![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey) [![License](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE)

**English** · [中文](README.zh-CN.md)

## Start here

Free BYOK application. There is no PodLens hosted-AI subscription; your configured providers charge for their usage. Desktop releases for macOS, Windows and Linux. Mobile/companion applications are not delivered (the glaze carrier is desktop-only by family policy); the interface language is chosen in Settings.

[Installation, first use, privacy, backup and recovery](docs/USER-GUIDE.md) · [简体中文](docs/USER-GUIDE.zh-CN.md)

## Install

Download from [Releases](https://github.com/turlamai/podlens/releases/latest):

| Platform | Download | Updates |
|---|---|---|
| macOS 14+ (Apple Silicon & Intel) | `podlens-<version>-macos-<arch>.dmg` — `arm64` / `x64`, or the portable `podlens-<version>-macos-<arch>.zip` | in-app check + verified download (signed manifest), then replace the app with the newer DMG/zip |
| Windows 10+ x64 | `podlens-<version>-windows-x64.msi` installer (start-menu & desktop shortcuts), or `podlens-<version>-windows-x64.zip` portable | in-app check + verified download; portable: extract the newer zip over the install dir; MSI: re-run the newer installer (the app points you to it) |
| Linux x64 / arm64 | `podlens-<version>-linux-<arch>.AppImage`, `.deb` (ships the GStreamer plugin closure incl. `gst-libav` for m4a/mp3), `.rpm`, the portable `tar.gz` (`bin/` + `lib/` + `public/`, run `bin/podlens`), or a `podlens-<version>-linux-<arch>.flatpak` bundle (app id `site.jrtx.podlens`; install with `flatpak --user install` — sandboxed data dir, so it starts a fresh library) | tar.gz: in-app check + verified download, then extract the newer tarball over the app directory; deb/rpm: package manager; AppImage/Flatpak: replace the file / install the newer bundle |

Every release carries a `SHA256SUMS` manifest and Sigstore build provenance
(`gh attestation verify <file> -R turlamai/podlens`).

Updates arrive through an Ed25519-signed manifest
([docs/UPDATE.md](docs/UPDATE.md)); the app verifies signature, hash and
size before anything is installed, and installation stays user-driven per
the table above. macOS releases are Developer ID signed and notarized when
the release credentials are configured; the release pipeline fails closed
without them.

## Why PodLens?

Listening comprehension is the last wall for most non-native English speakers. Feeds have no translation, nobody summarizes an hour of talk, and pausing to look things up kills the flow. PodLens fixes this with a per-episode pipeline:

- **Transcribe** — speech-to-text through any OpenAI-compatible `/audio/transcriptions` endpoint (Whisper and friends), with timestamps per sentence
- **Translate** — sentence-aligned translation into Chinese (or English), rendered alongside the original
- **Summarize** — a TL;DR, 5–8 key points, notable quotes and topic tags for every episode

The transcripts, translations and summaries are cached on disk, so an episode is processed once and stays yours.

### How it compares

| | PodLens | Apple Podcasts | Overcast |
|---|---|---|---|
| UI | **one shared web UI on the system WebView** | AppKit | web wrapper |
| Transcript | **on demand, yours** | limited podcasts | limited podcasts |
| Translation | **per sentence, local cache** | — | — |
| Summary | **TL;DR + key points** | AI recaps (US only) | — |
| LLM provider | **BYOK, any OpenAI-compatible** | Apple-only | — |

## How it works

PodLens is built on [glaze](https://github.com/turlamai/glaze): one shared Racket backend (feed parsing, library storage, the AI pipeline, the update client) serving one shared web UI inside each platform's own system WebView — WKWebView, WebView2, WebKitGTK. Not Electron: no bundled browser, no helper daemon.

```text
                 Racket application core
      feeds · library · ASR/translate/summarize · updater
                          │
                 typed RPC over loopback HTTP
                 (token-gated, same-origin UI)
                          │
              one web UI (HTML/CSS/TS)
                    ┌─────┼─────┐
                macOS   Windows  Linux
              WKWebView WebView2 WebKitGTK
```

- The backend embeds Racket CS in-process — no helper daemon, no console window
- Playback is HTML5 audio in the carrier; the host streams cached audio over a Range-capable loopback route; OS Now Playing (Control Center / SMTC / MPRIS) is bridged per platform
- The UI talks only to the typed contract in `racket/backend.rkt` — changing it is a cross-platform release

## What's inside

- **One-click Understand**: download → transcribe → translate → summarize as a single job — finished stages are skipped on re-run, a confirmation shows the text volume before anything is billed, and a running job can be cancelled at its next checkpoint
- Subscribe to RSS podcast feeds (RSS 2.0 + iTunes tags), refresh with new-episode detection, auto-refresh every 30 minutes with new-episode notifications
- Playback: 1.0–3.0× speed, ±15/30 s skip, sleep timer, chapter jumps (Podcasting 2.0 `podcast:chapters`), continuous playback into the next episode, resume-on-launch, media keys + Control Center (macOS) / SMTC (Windows) / MPRIS (Linux)
- **Reading-first detail**: a serif transcript set like a reading surface, follow-along highlighting, keyboard-operable sentences, and bilingual / translation-only / original-only modes
- **Focus Listening** hides the library and episode lists without interrupting playback, preserving the episode, position and reading context; the same control restores the library in place
- Structured summaries (TL;DR, key points, quotes, topics) plus show notes from the feed, led by a designed summary card
- Library basics: mark played/unplayed, unplayed badges per show, per-episode job progress
- Discover panel: curated catalog of classic English shows plus full-directory search (iTunes Search API, no key needed, results carry Apple's authoritative feed URLs) — nothing is ever auto-subscribed
- Try before you subscribe: a one-click audition on every Discover card peeks the feed, caches the newest episode's audio and plays it outside your library (`feed-peek` / `preview-audio`; CLI: `peek`, `preview`)
- Bring-your-own-key: OpenAI, DeepSeek, Groq, SiliconFlow, Ollama, any OpenAI-compatible endpoint
- **Credential hygiene**: the key lives in the OS vault (macOS Keychain / Windows DPAPI / Linux Secret Service) with an owner-only file fallback, never in config.json or CLI output; Settings can test the saved connection without billing tokens
- Agent-friendly CLI over the same core (`add`, `episodes`, `pipeline`,
  `estimate`, `transcribe`, `translate`, `summarize`, `show`, `export`,
  `find`, `done`, `search`, `peek`, `preview`, `--json`, exit codes 0/1/2)
- Signed in-app updates (Ed25519 manifest + SHA-256, see [docs/UPDATE.md](docs/UPDATE.md))

## Quick Start

### 1. Configure your API key

Open Settings and fill in:

- `api-base` — e.g. `https://api.openai.com/v1` (or DeepSeek/Groq/Ollama base)
- `api-key` — your key, stored in the operating-system vault (not in `config.json`), never synced; use **Test connection** before the first AI job

### 2. Listen

Add a podcast RSS URL, pick an episode, press **Understand** (一键听懂). Or from a terminal:

```bash
git clone https://github.com/turlamai/podlens && cd podlens
raco pkg install --auto --no-docs 'https://github.com/turlamai/glaze.git#<GLAZE_PIN from .github/workflows/ci.yml>'
racket racket/cli.rkt add "https://feeds.example.com/show.xml"
racket racket/cli.rkt episodes <feed-id>
racket racket/cli.rkt transcribe <episode-id>
racket racket/cli.rkt show <episode-id> --json
```

The CLI is the same Racket source the GUI embeds, run headless. (Shipping a
single self-contained CLI binary is on the roadmap; inside the repo it needs
no API key for `--help`, `list`, `doctor` and `config`.)

## Repository layout

```text
podlens/
├── glaze.rktd              # carrier schema contract (app id, window, tray)
├── main.rkt                # glaze build entry (wraps backend/main.rkt)
├── VERSION                 # release identity, checked against racket/version.rkt
├── backend/
│   └── main.rkt            # host: typed RPC routes, audio Range streaming, tray, close-to-tray
├── apps/desktop/           # the one web UI (TypeScript + Vite); i18n projected from racket/core/i18n.rkt
├── racket/
│   ├── backend.rkt         # the typed wire contract (RPCs, events, state)
│   ├── update.rkt          # signed-manifest update checks (glaze/update)
│   ├── cli.rkt             # agent-facing CLI (--json, exit codes)
│   └── core/               # feeds, library, config, openai, pipeline, chapters, i18n
├── tests/                  # backend tests incl. a fake OpenAI server and the update flow
├── verify.rkt              # real-window acceptance journeys (per platform, headless-capable)
├── scripts/                # update-keys.sh, make-update-manifest.sh, acceptance/, e2e seeds
├── flatpak/                # bundle manifest + launcher for the Linux flatpak artifact
├── design/                 # landed prototype + DESIGN.md visual/interaction contract
├── docs/                   # UPDATE.md (update contract) · USER-GUIDE · release-runbook
├── site/                   # podlens.jrtx.site (GitHub Pages)
└── .github/workflows/      # ci · acceptance · release · appimage-upgrade-qualification · pages
```

## Development

Prerequisites: [Racket CS](https://racket-lang.org/) (stable, full distribution) with the pinned glaze package installed, and Node.js for the web UI build. Linux additionally needs GTK3 + WebKitGTK 4.1 + GStreamer runtime packages (see `.github/workflows/acceptance.yml` for the exact list).

```bash
raco pkg install --auto --no-docs 'https://github.com/turlamai/glaze.git#<GLAZE_PIN>'
npm --prefix apps/desktop ci && npm --prefix apps/desktop run build
raco test tests/        # backend tests (no API key needed — fake server)
racket verify.rkt       # real-window acceptance journeys on this platform
raco glaze build --entry main.rkt --version "$(cat VERSION)"   # packaged tree in dist/
```

## Honest gaps

- **No waveform, gapless playback or Up Next queue** — seek, ±15/30 s skip, 1.0–3.0× speed, sleep timer, chapter jumps and continuous playback are there; a drag-reorderable queue is not
- **Chapters only via Podcasting 2.0 feed pointers** — embedded ID3/M4A chapter atoms are not parsed; per-chapter summaries are deliberately not built (N× the LLM bill)
- **Translation cost is bounded only by your usage** — every sentence of a chosen episode goes through your API; long episodes cost real money. The header shows a sentence/character estimate before you start, and `podlens estimate <id>` prints it
- **One target language at a time** — the pipeline retranslates when you change `target-lang`
- **macOS signing depends on release credentials** — with the Developer ID and notary secrets configured, releases are signed and notarized; without them a tag release fails closed rather than shipping ad-hoc artifacts
- **Flatpak starts a fresh library** — the sandboxed data dir is separate from `~/.podlens/`; use the tar.gz/deb/rpm forms to keep an existing library

## Roadmap

The design roadmap lives in [docs/DESIGN-ROADMAP.md](docs/DESIGN-ROADMAP.md). Mobile companions are out of scope: the glaze carrier is desktop-only by family policy.

- [x] RSS subscription + episode cache + playback positions
- [x] ASR / translation / summary pipeline with job progress events
- [x] One-click "understand this episode" (pipeline RPC) + cost estimates
- [x] One shared web UI on the glaze system-WebView carrier (macOS / Windows / Linux)
- [x] Ed25519-signed update channel
- [x] System media keys (Control Center / SMTC / MPRIS), skip, sleep timer, 3× speed
- [x] Chapter marks (Podcasting 2.0), mark played, unplayed badges, continuous playback, resume on launch
- [x] Notarized macOS releases; Linux five-form packaging (deb/rpm/AppImage/Flatpak/tar.gz)
- [ ] Authenticode-signed Windows releases
- [ ] Per-chapter summaries, listening stats and vocabulary export

## License

Licensed under the [AGPL-3.0 License](LICENSE).
