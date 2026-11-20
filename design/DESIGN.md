# PodLens — visual and interaction contract

This editable prototype defines information architecture and interaction semantics for the macOS, Windows, and Linux implementations, which share one web UI on the glaze system-WebView carrier. Platform mechanisms follow each host's conventions through the carrier. The HTML prototype is a design reference and the landed visual baseline, not a replacement for the Racket engine.

## Scope and entry points

- `prototype/home.html`: continue listening and resume reading.
- `prototype/episodes.html`: subscribed episodes, show selection, and downloaded examples.
- `prototype/transcript.html`: bilingual reading, sentence seeking, following, and focus mode.
- `prototype/summary.html`: content overview and links back to source sentences.
- `prototype/discover.html`: local example search and subscription changes.
- `prototype/settings.html`: appearance, reading preferences, and service configuration form.
- `index.html`: opens the main listening view directly; no screen directory is retained.

All six entries share `prototype/shared.css` and `prototype/app.js`. In-app navigation changes the mounted view without depending on native document navigation. Each HTML file is also a direct entry. The prototype does not introduce new backend RPCs, a queue, favorites, waveform processing, or chapter-summary features.

## Direction

Continue the existing warm reading environment, restrained terracotta accent, and serif reading text. Increase typographic hierarchy and whitespace rather than introducing a new brand. Covers remain typographic artwork for the existing example shows; they are not official podcast assets. Program names and episode text are retained as example content, not represented as a fetched live catalog.

The home screen prioritizes the current episode, one primary playback action, and a direct return to reading. Recent updates follow; subscribed shows are secondary. The former Up Next area is removed because a queue is outside the current product scope.

## Tokens

| Token | Light | Dark |
|---|---|---|
| accent | `#AC4B2D` | `#EBAB8A` |
| accent-deep | `#893A23` | `#F5C1A6` |
| accent-soft | `#F6E8E1` | `#3B2C25` |
| on-accent | `#FFFFFF` | `#281B14` |
| canvas | `#FAF7F2` | `#1A1917` |
| surface | `#FFFFFF` | `#22211F` |
| raised | `#F2EEE8` | `#2B2925` |
| hairline | `#E4DED5` | `#403D37` |
| ink | `#252521` | `#F1EEE8` |
| ink-soft | `#69675F` | `#B2ADA3` |
| positive | `#276742` | `#8DD1A3` |
| danger | `#A52C2C` | `#F4A09A` |

Accent foreground/background pairs change together in dark mode. This is a contrast-oriented refinement of the prior palette, not a new palette system. Native implementation token mirrors still require an explicit implementation change; this prototype does not update those source files.

- UI: system sans stack with Chinese platform fallbacks.
- Reading: system serif, Georgia, Songti; English 20px / 1.65, translation 16px / 1.7.
- Body: 16px; secondary labels 13–14px; timestamps 11–12px monospace.
- Titles: 24–32px, with a larger serif episode title in the home continue section.
- Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48px.
- Corners: 4px labels, 8px controls and covers, 12px major containers.
- Icons: one outlined SVG family, 24-unit viewBox, 1.6-unit stroke; no character-based control glyphs.
- Controls use visible focus, accessible names, and text paired with status colors.
- Reduced motion disables animated scrolling. No decorative continuous animation.

## Shared state and interaction invariants

1. One selected episode and one position per episode drive the player, home progress, elapsed time, and remaining time. A selected episode cannot appear simultaneously paused and playing in different mounted controls.
2. Initial position is 00:38 of 54:00. The progress fraction is derived from those values, never independently hard-coded.
3. Playback is explicitly a timer-based demonstration. It does not load, download, or play audio. This boundary remains visible in the player and page chrome.
4. Selecting another episode restores its position. Restart resets the current episode to zero. Back and forward controls seek −15 / +30 seconds, bounded by the episode duration.
5. Transcript sample text covers the opening through 01:09 of the existing interfaces episode. Other episodes must not display that transcript or summary as their own. Missing content gets an explanatory state and an entry to the generation explanation.
6. Sentence selection updates the simulated position. Bilingual / translation / original modes retain the selected sentence and reading layout. Follow updates the current sentence inside the available sample; reading beyond that sample is never fabricated.
7. Summary timestamp actions return to the corresponding source sentence and start simulated progress. In the product, key points and quotes carry the sentence time they came from (the summary RPC normalizes legacy rows to unanchored objects, which render without a jump button). Summaries are labeled sample text in the prototype, not a completed model call.
8. Focus mode removes navigation without creating a new playback state. Exiting restores the surrounding application.
9. Space starts or pauses when the page body has focus; native buttons keep their own activation. Ctrl/Command + arrows seek. Enter or Space activates a focused sentence. F toggles reading focus mode. Inputs and open dialogs do not trigger these shortcuts.
10. Playback rate changes timer progression. Sleep timing stops the simulation; it is not a background audio guarantee.
11. Positions, reading mode, subscriptions, theme, and non-sensitive preferences attempt browser-local persistence. If storage is unavailable, the application retains in-memory behavior and discloses the limitation in settings. Reload does not automatically start playback.
12. Navigation restores per-view scroll position. Key view changes place focus on the heading. Local redraws attempt to restore the invoking control.

## Subscription and processing states

The initial sample has four subscribed shows. Subscription count, sidebar, home shows, and catalog button states derive from the same list. Search filters only the four local examples by name, topic, or description; it does not query iTunes or another directory.

The sample Sky episode demonstrates a cancellable 46% transcription state. Cancellation does not disable playback. No processor or background task runs. Other missing transcripts offer a pre-generation explanation; the prototype does not pretend to calculate unknown character counts, prices, or model results.

Real product work still needs provider-derived cost estimation before execution, cancel/retry/recovery behavior, and real processing status. These are implementation requirements, not completed prototype capabilities.

## Settings honesty

- Reading and theme settings take effect locally.
- Service address validation checks HTTPS URL syntax only. It does not test connectivity or model support.
- The API key field is a temporary demonstration: mask/reveal works, the value is not persisted, and the interface says not to enter real credentials.
- Only non-sensitive preferences can be saved. The prototype never claims successful authentication or OS-vault storage.
- Advanced model and refresh fields are progressively disclosed. Refresh and update preferences do not start real background work.
- The real application must use secure platform storage for keys. No key should enter configuration JSON, browser storage, logs, or sync.

## Responsive and platform behavior

Desktop uses a 232px sidebar, normal-flow content, and a player that reserves its own space. Medium windows simplify columns; narrow windows use an expandable navigation area and reorganized player. Primary controls remain available at 375px without a simulated desktop titlebar. Focus mode remains available on every width.

| Mechanism | macOS | Windows | Linux |
|---|---|---|---|
| Shortcut modifier | Command | Ctrl | Ctrl |
| Carrier | glaze system WebView (WKWebView) | glaze system WebView (WebView2) | glaze system WebView (WebKitGTK) |
| Settings presentation | In-app settings view | Same | Same |
| Appearance choice | Follow System / Light / Dark (menu ⇧⌘T quick toggle) | Same three states in settings | Same three states in settings |
| Single-key shortcuts | F and / via the web key handler | Same | Same |
| Shared contract | Information architecture, action semantics, reading continuity, status vocabulary | Same | Same |

One web UI runs on all three carriers; platform mechanisms (tray, close-to-tray,
OS Now Playing, shortcuts modifiers) map through the glaze carrier and the
host bridge, never through per-platform UI forks.

## Glaze carrier rewrite record — #63 (2026-11-20)

- Family design standard read before the UI slices: revision
  `2026-11-20-minimal-family` (tlai-product references/design-standard.md),
  together with policy.md. Product start SHA for the rewrite:
  `1f62220` (main before the glaze rewrite branch).
- Carrier decision: glaze (system WebView + HTML/CSS/JS UI). No rivet hard
  trigger applies: the tray/close-to-tray behavior is the glaze carrier's
  own tray, not a product-deep integration; no mobile roadmap; not an
  all-day resident low-footprint app. Declared in podlens#63 for owner
  correction.
- OS Now Playing carrier decision (2026-11-20, glaze#153 / glaze PR#154):
  host-owned publication, not the web engine's MediaSession bridge.
  Evidence chain: WebKitGTK never owns an MPRIS name on headless CI
  (WebKit bug 279362; bus-identity forensics in podlens#63), and macOS 26
  private MediaRemote returns nothing even for audible playback. macOS
  uses public MediaPlayer.framework; Linux owns MPRIS2 over GIO/GDBus;
  Windows keeps the verified WebView2 web MediaSession → SMTC path (host
  stub inert). Page syncs via `api/host/now-playing`; OS commands return
  over SSE `now-playing-command`; acceptance probes read the host surface
  (`api/host/now-playing_os` readback / owned MPRIS name / SMTC probe).
- Main task: resume listening and resume reading one episode; primary
  action = play/pause in the reserved player; secondary = jump back to the
  current transcript sentence.
- Accent role: existing terracotta pair (light `#AC4B2D` / dark `#EBAB8A`)
  serves primary action, selection and focus; one high-emphasis action per
  task region. Density: standard preset (16–24 content padding, 36px
  controls); the transcript reading column uses the reading preset
  (16px serif body, 1.7–1.9 line height) — the family-allowed reading
  exception, self-hosted/system serif fallback, no runtime remote fonts.
- Font/icon mapping: system UI stack per family baseline for chrome;
  serif only for transcript/summary reading body; existing family linear
  SVG icon set (Lucide-outline compatible) retained, 16/20/24 viewBoxes.
- Exceptions registered: serif reading body (reading preset); typographic
  cover artwork for example shows (content, not chrome).
- UI acceptance evidence lives in podlens#63 (per-slice comments with
  platform screenshots and the real-window acceptance envelope); the
  prototype entries above remain the landed visual baseline the web UI
  was ported from.

## Exit and remaining implementation work

This revision delivers editable visual and local interaction source. No browser preview, screenshots, audio playback, or automated validation was performed in this revision. It does not establish production readiness or native implementation parity.

Before release: verify real playback/reading continuity across navigation and restart; secure key storage; service errors, retry and cancellation; actual download/offline behavior; large and empty libraries; font scaling; screen reader output; keyboard focus; and all three glaze carriers. These remain release work, not claims about this prototype.

## Interaction check — 2026-11-14

A follow-up check loaded all six HTML entries and their resources in a DOM runtime. Thirty checks passed after fixes to delegated sentence activation, current-sentence lookup with following disabled, and stale service-address feedback. Coverage included shared playback state, seek bounds, sentence click and Enter activation, language and focus modes, summary anchors, missing-content states, local search, subscriptions, navigation-menu reset, cancellation, settings validation, theme preferences, and API-key non-persistence.

The check stubs scrolling and native dialog methods; it does not establish rendered layout, actual native-dialog behavior, audio behavior, screen reader output, or browser-specific behavior. Browser access was unavailable and native Edge access was not approved, so desktop/narrow-window visual previews remain outstanding.


## Prototype source checkpoint — 2026-11-15

`index.html` opens the primary prototype directly. Screen-directory launchers have been removed. All local scripts, styles and referenced assets needed by this checkpoint are versioned under this directory; OpenDesign metadata is excluded. This is an editable prototype checkpoint, not a claim that the native product or external services implement these interactions.
