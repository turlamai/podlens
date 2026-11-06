# PodLens user guide

**English** · [简体中文](USER-GUIDE.zh-CN.md)

Listen to podcasts and optionally create sentence-aligned transcripts, translations and summaries with your own model key.

## Availability

Free BYOK application. There is no PodLens hosted-AI subscription; your configured providers charge for their usage.

## Platforms and installation

Desktop previews for macOS, Windows and Linux. Mobile/companion applications are not delivered; Linux language selection currently uses PODLENS_LANG.

Use [official Releases](https://github.com/turlamai/podlens/releases), select an explicitly listed OS/architecture asset, read its release notes and check supplied checksums. An absent asset/platform is not a delivery promise. Preview builds may lack publisher signing or notarization; do not disable system-wide security protections to install them.

## Your first successful session

1. Search Discover or add a podcast RSS URL, then play an episode without starting AI jobs.
2. Open Settings → Intelligence, enter an OpenAI-compatible base URL and key, and use **Test connection** to check the saved configuration before spending tokens.
3. Choose providers appropriate for audio transcription and text translation; they may require different model capabilities.
4. Press **Understand** on an episode. The confirmation shows the stages already done and the approximate text volume before anything is billed; **Cancel** stops a running job at its next checkpoint.
5. Read with the transcript toolbar: Bilingual, Translation or Original, plus Follow and Current. **Focus Listening** hides the library and episode lists without interrupting playback, and restores them in place.
6. Test a short episode, inspect usage, then check transcript export and playback recovery before processing a large library.

## Data, backup and recovery

Data normally lives in ~/.podlens: config.json, library.json, audio/ and transcripts/. Quit before backup.

The API key is not written to config.json. On first launch after upgrading, a plaintext key from an earlier version is moved once into the operating-system vault (macOS Keychain, Windows DPAPI or Linux Secret Service); config.json then keeps only an opaque reference. If no vault is available, the key is stored under `secrets/` in a file readable only by your account and the app says so in Settings. A backup of config.json is therefore not a backup of the key: re-enter the key in Settings after restoring on another machine, or restore the vault entry through your OS. Do not copy `secrets/` into shared backups, and rotate a key that has been exposed.

## Network, keys and privacy

RSS, directory search and audio downloads contact their respective hosts. Transcription uploads selected audio to the chosen provider; translation/summary requests send text. Local Ollama availability does not imply local audio-transcription support.

## Known limits

Long-job cancellation is available on macOS, Windows and Linux. Windows MSI updates use a new installer rather than silently replacing the installation. The 0.7 release aligns Windows and Linux with the reading-first information architecture, three reading modes, cancel action and storage transparency; controls remain native WinUI and GTK, and the in-app language switch is macOS-only for now. Windows 125–200% display scaling still needs a dedicated visual pass.

## Updates and removal

Back up data and read the destination release notes first. An in-app update check does not necessarily install an update for your channel; follow the manual for portable, installer and source paths. Never bypass a failed signature check or replace the program with an untrusted artifact. On failure, preserve data and the error, then recover with a trusted release. Removing the program does not necessarily erase its separate data directory; verify your backup before deleting personal data.

## Get help

Report problems in [GitHub Issues](https://github.com/turlamai/podlens/issues), in English or Chinese. Include the version, OS/architecture, installation channel, steps, expected result and actual result. Reproduce with synthetic input first; do not attach keys, credentials, databases, private source documents or complete logs. Public support has no guaranteed response time.

## Further reading

- [Update behavior](../docs/UPDATE.md)
- [Project overview and development](../README.md)
- [Current licence](../LICENSE)
