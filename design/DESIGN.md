# PodLens — visual and interaction contract

This editable prototype defines information architecture and interaction semantics for the macOS, Windows, and Linux implementations, which share one web UI on the glaze system-WebView carrier. Platform mechanisms follow each host's conventions through the carrier. The HTML prototype is a design reference and the landed visual baseline, not a replacement for the Racket engine.

**Source of truth**: token, font, spacing, corner and motion values live only in `prototype/shared.css` (light/dark pairs); this document records semantic names, usage, decisions and boundaries only (slimmed 2026-11-23 to the family minimal-docs standard). Change values in CSS; change semantics here.

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

| Token | Usage |
|---|---|
| accent / accent-deep / accent-soft / on-accent | primary action, selection and focus / hover-deep / quiet fill / foreground on accent |
| canvas / surface / raised / hairline | page canvas / cards and sheets / raised areas / structural rules |
| ink / ink-soft | primary text / secondary text |
| positive / danger | success state / error and destructive state |

Accent foreground/background pairs change together in dark mode. This is a contrast-oriented refinement of the prior palette, not a new palette system. Native implementation token mirrors still require an explicit implementation change; this prototype does not update those source files.

- UI: system sans stack with Chinese platform fallbacks. Reading: system serif (Georgia / Songti fallbacks) for transcript and summary body only.
- Type roles: reading (original and translation), body, secondary labels, timestamps (monospace), titles, and a larger serif episode title in the home continue section — sizes and line heights per `shared.css`.
- Spacing rhythm, the embedded/control/panel corner hierarchy and the single outlined SVG icon family (no character-based control glyphs) are defined in `shared.css`.
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

Desktop uses a fixed-width sidebar (see CSS), normal-flow content, and a player that reserves its own space. Medium windows simplify columns; narrow windows use an expandable navigation area and reorganized player. Primary controls remain available at phone width without a simulated desktop titlebar. Focus mode remains available on every width.

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
- Accent role: the existing terracotta pair (values in `shared.css`)
  serves primary action, selection and focus; one high-emphasis action per
  task region. Density: standard preset for chrome; the transcript reading
  column uses the family reading preset (serif body, taller line height) —
  the family-allowed reading exception, self-hosted/system serif fallback,
  no runtime remote fonts.
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

## Mobile views (iOS)

### Product-line declaration

Desktop = glaze carrier (per #63, 2026-11-20, unchanged); Mobile = native iOS app (Swift), owner decision 2026-11-22.

This section and `prototype/mobile-*.html` are the design contract for the iOS app. Binding/sync architecture (companion vs standalone) will be decided when implementation is initiated; this prototype does not lock that architecture. Adding native iOS does not move the desktop UI to a different carrier or extend the glaze carrier onto mobile. The earlier #63 statement that no mobile roadmap existed describes that historical decision, superseded for mobile by this owner decision.

### Deliverables and entry points

Each screen has an independent HTML entry referencing the same-directory `shared.css` and `app.js`, with no remote assets or additional runtime packages:

- `prototype/mobile-home.html`: current episode cover, title, shared progress, play/pause, continue reading, and recent subscription updates.
- `prototype/mobile-now-playing.html`: large typographic artwork, progress seeking, play/pause, minus/plus 15-second controls, current-sentence jump, and end playback.
- `prototype/mobile-episodes.html`: subscribed episode list, downloaded filter, show-specific lists, processing/canceled/missing transcript labels, and episode playback.
- `prototype/mobile-discover.html`: local example search, add/remove subscriptions, and opening a show's episodes.
- `prototype/mobile-transcript.html`: bilingual sentence reading, current-row marker, original/translation/bilingual selection, and an in-view Summary tab with source-time anchors. No seventh mobile-summary page is introduced.
- `prototype/mobile-settings.html`: appearance, follow preference, playback rate, non-sensitive service preferences, inline URL validation, subscription management, and prototype limitations.

`index.html` is restored as the requested grouped navigation page, with Desktop and Mobile sections and links to local mobile state examples. The previous direct home redirect is superseded by this request. Existing desktop screen files remain unchanged.

### Design contract

- Each mobile page is a pure content canvas with a phone-width maximum (see CSS) centered on the existing neutral canvas token. It shrinks naturally on narrower viewports. There is no phone bezel, hardware frame, Dynamic Island, fake status bar, glass, glow, texture, or decorative gradient.
- The shared stylesheet remains the token source. Mobile rules are scoped beneath `.mobile-prototype`, reference its existing semantic variables, and introduce no new color palette or font family. The existing typographic sample-cover artwork and inline outline SVG set are reused.
- Chrome uses the existing system UI font stack; mobile interface text, supporting text and page titles keep their own roles (sizes in the `.mobile-prototype` rules). Transcript original and summary body reuse the serif reading preset; translation uses the existing sans translation role.
- Content padding follows the shared rhythm. Targets and list rows are at least 44 logical pixels. Rounded shapes retain the embedded/control/panel hierarchy and single-pixel rules. A large player button remains a control shape, not a new floating decorative shape.
- The existing terracotta pair is the only product action accent. Each task region has at most one filled primary action. The mini-player uses quiet transport so it does not compete with the home or full-player primary button.
- Light and dark use the same existing `:root`/`.dark` mechanism; both theme foregrounds and surfaces change. Focus remains visible. The current sentence is indicated by text and a semantic background, never by color alone.
- Motion uses the existing motion token (within the requested short range). The shared reduced-motion rule disables smooth scrolling and transitions.
- The app frame uses normal-flow header, a scrolling main region, and reserved bottom chrome. Bottom navigation and the mini-player consume their own layout space rather than covering reading content. Real safe-area inset padding is supported without drawing decorative system UI.

### Navigation and state

The bottom tabs are Home / Discover / Episodes / Settings, labeled in the existing Chinese UI language as 主页 / 发现 / 单集 / 设置. Detail pages expose an explicit back action. Mini-player taps open Now Playing; it remains available for a loaded episode whether playing or paused, and disappears when no episode is selected. It is omitted on Now Playing to avoid duplicating transport.

In-page navigation preserves the active episode, per-episode position, reading selection/language, follow state, subscriptions, search text, list filter/show selection, and non-sensitive service draft. Back restores the previous view and scroll position; tab changes retain each view's context. Local storage is a prototype convenience, isolated from the desktop prototype state; it does not declare an iOS binding/sync design. Reload restores local content state with playback paused. Storage-denied previews retain in-memory interactions and disclose the limit.

The mobile seek mapping is minus/plus 15 seconds as explicitly requested. This is a documented mobile control mapping; desktop's existing minus 15 / plus 30 behavior remains unchanged. Sentence taps only demonstrate playback-position changes; no audio is fetched or played. Summary anchors select their source sentence, switch back to the transcript, and retain the position without claiming generated content for unrelated episodes.

### Applicable states and recovery

- No active episode: Home and Now Playing explain the empty state and lead to Episodes; no inactive mini-player is drawn. End Playback preserves saved positions while clearing the loaded episode.
- Empty subscriptions: Home and Episodes lead to Discover; the catalog can add subscriptions without automatically starting playback.
- Processing: the existing Sky example shows an explicitly labeled sample 46% state and a direct cancel action. Playback stays available. This percentage is seeded demonstration data, not claimed backend telemetry.
- Failed processing: an explicitly labeled failure example preserves episode and position, offers retry information and access to service settings. It does not pretend to restart an unconnected API task.
- Missing content: other episodes do not reuse the interfaces sample transcript or summary. They display an explanation and the existing pre-generation information.
- Settings error: malformed/non-HTTPS service addresses get a local inline error, retain the entered draft, and can be corrected in place. Valid format is not represented as successful connectivity. No real keys are requested or saved.
- Loading: HTML entries show a brief loading message while the local script initializes; there are no remote-loading dependencies or fake ongoing network states.
- Offline, permission, and OS-media integration behavior require native implementation evidence and are not simulated as real capabilities.

State deep links are `?state=empty-player`, `?state=empty-subscriptions`, `?state=processing`, and `?state=error`; Summary is reachable with `?section=summary`. State-example sessions do not overwrite normal saved content. These links live in the directory, not as designer controls inside the product UI.

### Exit conditions and family UI checklist

- [ ] All six mobile key screens exist with functioning local navigation.
- [ ] Back navigation, tab changes, playback position, reading position, and list/search context remain consistent.
- [ ] Light and dark work through existing tokens; text contrast meets 4.5:1 and control/state semantics do not rely on color alone.
- [ ] There are zero external runtime resources, and all relative dependencies resolve.
- [ ] Touch targets are at least 44×44; necessary controls remain reachable with expanded text and reduced motion.
- [ ] Applicable family checks cover subtraction, shared family typography/components, full text layout, empty/processing/error/canceled states, focus and recovery, themes/accessibility, and truthful platform scope.
- [ ] Native iOS reading, VoiceOver, Dynamic Type, real audio, system media, safe areas, secure storage, installation, and lifecycle behavior are verified during Swift implementation; HTML checks cannot certify those behaviors.

Family guidance used: `tlai-product` design-standard revision `2026-11-20-minimal-family`. The project workspace has no Git metadata, so no starting SHA or commit/push result is asserted. Validation evidence for this mobile slice is recorded below after the requested checks; unperformed host checks remain explicitly unverified.

### Mobile slice self-check — 2026-11-22

Requested source/DOM checks passed: 53/53, plus JavaScript syntax checking. Evidence was collected from the six actual mobile HTML entries, their shared stylesheet/script, all local fixture entries, and the six desktop entries as regressions.

- Local-resource scan: all six mobile HTML entries use only same-directory `shared.css` / `app.js`; the directory's relative page links resolve. Shared CSS contains no imports, image URLs, or remote font resources. The mobile CSS adds no literal color values or alternative font stack. Service URL text is editable configuration content, not a fetched resource.
- DOM initialization: six mobile entries render one main heading and four tabs inside a maximum-width phone content canvas. No desktop sidebar/player or device/statusbar decoration mounts in a mobile entry. Existing desktop entries still initialize their original workspace without mobile tabs.
- Interactions: current episode/progress agrees between Home, mini-player, and Now Playing; seek boundaries and minus/plus 15 seconds work; explicit back returns to the previous view; sentence selection, language changes, Summary anchors, theme persistence, reload-paused behavior, search/tab context, subscription mutation, empty recovery, cancellation, settings correction, and storage-denied operation passed.
- Theme contrast: CSS-computed foreground/background checks for visible mobile text roles passed at least 4.5:1 in both themes on all six initial screens. This checks semantic color application, not a photographed or native-rendered result.
- Touch sizing: active controls' declared CSS heights are at least 44px; primary/icon/tab controls declare minimum widths of at least 44px, range control is explicitly at least 44px high, and the checkbox has a full-width label with a 44px minimum hit height. Flow widths allocate space to text controls. Pixel-level overlap and hit-testing still require rendered-browser or native verification.
- Fixture checks cover empty playback, empty subscriptions, processing/cancel, failure/recovery, and Summary anchors. Fixture interactions do not write normal stored state. No uncaught application errors were observed in the checked flows.

These are source/DOM tests, not browser visual previews. DOM checks stub native dialog open/close and scrolling; they do not prove rendered geometry, actual modal focus trapping, VoiceOver, 200% text layout, or iOS lifecycle behavior. No screenshots, real audio playback, API calls, Swift build, or physical-device acceptance was performed. Those applicable host checks remain unverified; no full family-UI acceptance claim is made.

For this prototype slice, the first four exit conditions above are met at the source/DOM level. Touch declarations are checked, while expanded-text/actual hit testing remains pending. Native iOS conditions and the remaining rendered family checks are implementation/acceptance work rather than missing prototype files.
