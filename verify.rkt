#lang racket/base

;; Real-window verification for the PodLens glaze host (#63, slice 1).
;; The family pattern (glaze docs/product-acceptance.md): wait for the
;; native window, check title/URL, capture a PNG, drive the typed routes
;; over the loopback HTTP adapter, probe the Range media carrier, then
;; close. Slice 5 extends this into the full transcript-follow / playback
;; journey harness.
;;
;; Run: racket verify.rkt   (needs a graphical session; WebView2 runtime
;; on Windows, WKWebView on macOS, WebKitGTK + Xvfb on Linux CI).

(require glaze/app
         glaze/window
         glaze/tray/main
         json
         net/url
         net/http-client
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         "backend/main.rkt")

;; Surface glaze's hatch/readback log lines (current-logger, no receiver by
;; default) in headless CI evidence.
(void
 (thread
  (lambda ()
    (define rcv (make-log-receiver (current-logger) 'info))
    (let loop ()
      (define v (sync rcv))
      (eprintf "[glaze-log] ~a: ~a\n" (vector-ref v 0) (vector-ref v 1))
      (loop)))))

(define-runtime-path frontend-dist "apps/desktop/dist")
(define-runtime-path evidence-dir ".glaze/verify")
(define-runtime-path seed-script "scripts/e2e/seed-listening-fixture.rkt")
(define-runtime-path nowplaying-probe-src "scripts/acceptance/nowplaying-probe.swift")

;; Isolation: the verifier never touches the real ~/.podlens.
(define home (make-temporary-file "podlens-verify-~a" 'directory))
(putenv "PODLENS_DATA_DIR" (path->string home))

;; Open the in-page journey harness gate for this verifier only.
(putenv "PODLENS_E2E" "1")

;; The seeded journeys start media from synthetic clicks; WebView2 /
;; WKWebView / WebKitGTK reject play() without a real user gesture (even
;; muted). Acceptance-only escape hatch, default off in shipped apps
;; (glaze#143).
(putenv "GLAZE_ALLOW_PROGRAMMATIC_PLAYBACK" "1")

;; Seed the offline listening fixture (same data the native acceptance
;; uses): one feed, an 8s silent wav, a 4-sentence bilingual transcript and
;; a mixed anchored/legacy summary. Separate process, same isolated home.
(define seed-exit
  (system*/exit-code (find-executable-path "racket") (path->string seed-script)))

(define verdicts '())
(define journey-reports (box '()))

;; ---- slice 5: OS-level Now Playing probes -------------------------------
;; The in-page journey asserts the MediaSession contract; these probes assert
;; the OS surface each platform derives from it: Windows SMTC (Chromium /
;; WebView2 bridge), macOS Now Playing (host-owned MediaPlayer.framework,
;; glaze#153), Linux MPRIS (host-owned GIO/GDBus name, glaze#153). Probe-only code:
;; nothing here ships in the product.
(define fixture-title "A small episode about focused listening")

(define (run-capture exe . args)
  ;; process* pipes: system* neither searches PATH nor writes into a
  ;; parameterized string port (it inherits the OS-level stdout).
  ;; Racket 9.x returns one list value; 8.x returned five values.
  (define resolved (or (find-executable-path exe) exe))
  (define parts
    (call-with-values (lambda () (apply process* resolved args))
      (lambda vs (if (and (= 1 (length vs)) (list? (car vs))) (car vs) vs))))
  (define in (list-ref parts 0))
  (define out (list-ref parts 1))
  (define err (list-ref parts 3))
  (define ctrl (list-ref parts 4))
  (define text (port->string in))
  (define etext (port->string err))
  (close-input-port in)
  (close-output-port out)
  (close-input-port err)
  (ctrl 'wait)
  (values (ctrl 'exit-code) (string-append text etext)))

(define powershell-smtc-probe
  #<<PS1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($Op, $ResultType) {
  $m = $asTaskGeneric.MakeGenericMethod($ResultType)
  $t = $m.Invoke($null, @($Op))
  $t.Wait()
  $t.Result
}
$mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
foreach ($s in $mgr.GetSessions()) {
  $p = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
  Write-Output ("TITLE=" + $p.Title)
  Write-Output ("SOURCE=" + $s.SourceAppUserModelId)
}
PS1
  )

;; The macOS probe source lives in scripts/acceptance/nowplaying-probe.swift
;; (single source: CI precompiles it, local runs compile it on demand).

;; Forensic aids for the Linux probe: a per-second timeline of bus names
;; and the owning process of each unique connection, dumped only when the
;; probe times out (headless runners have no desktop session to inspect).
(define poll-log-box (box '()))
(define last-names-box (box '()))
(define (bus-identity name)
  (define-values (_c pid-out)
    (run-capture "dbus-send" "--session" "--print-reply"
                 "--dest=org.freedesktop.DBus" "/org/freedesktop/DBus"
                 "org.freedesktop.DBus.GetConnectionUnixProcessID"
                 (string-append "string:" name)))
  (define pid-m (regexp-match #px"uint32 (\\d+)" pid-out))
  (define cmd
    (and pid-m
         (with-handlers ([exn:fail? (lambda (_) "")])
           (string-replace
            (file->string (string-append "/proc/" (cadr pid-m) "/cmdline"))
            "\0" " "))))
  (format "~a pid=~a cmd=~a"
          name (if pid-m (cadr pid-m) "?") (or cmd "")))

;; Poll the platform surface until the fixture title shows up (the bridges
;; publish shortly after playback starts) or the budget runs out.
(define (probe-nowplaying url)
  (define probe-t0 (current-inexact-milliseconds))
  (define deadline (+ probe-t0 30000))
  (let loop ()
    (define-values (ok text)
      (case (system-type)
        [(windows)
         (run-capture "powershell" "-NoProfile" "-Command" powershell-smtc-probe)]
        [(macosx)
         ;; Host-owned surface (glaze#153): read MPNowPlayingInfoCenter
         ;; back through the public API; the private MediaRemote probe
         ;; stays as secondary evidence only.
         (define os (post-json url "api/host/now-playing_os" (hasheq)))
         (define host-text (format "host-os-info=~s" os))
         (define bin (wait-swift-probe-bin))
         (define-values (_rc mr)
           (if bin
               (run-capture (path->string bin))
               (values 1 "swiftc precompile unavailable")))
         (values 0 (string-append host-text "\n--- MediaRemote ---\n" mr))]
        [(unix)
         (define-values (_lc names)
           (run-capture "dbus-send" "--session" "--print-reply"
                        "--dest=org.freedesktop.DBus" "/org/freedesktop/DBus"
                        "org.freedesktop.DBus.ListNames"))
         (define name-lines
           (filter-map
            (lambda (line)
              (define m (regexp-match #px"\"([^\"]*)\"" line))
              (and m (cadr m)))
            (string-split names "\n")))
         (define mpris
           (filter (lambda (s) (string-prefix? s "org.mpris.MediaPlayer2.site_jrtx_podlens"))
                   name-lines))
         (set-box! last-names-box name-lines)
         (set-box! poll-log-box
                   (cons (format "t=~as mpris=~a bus-names=~a"
                                 (/ (- (current-inexact-milliseconds) probe-t0) 1000.0)
                                 (length mpris)
                                 (string-join
                                  (filter (lambda (s) (string-prefix? s ":")) name-lines)
                                  ","))
                         (unbox poll-log-box)))
         (define outs
           (for/list ([name (in-list mpris)])
             (define-values (_c meta)
               (run-capture "dbus-send" "--session" "--print-reply"
                            (string-append "--dest=" name) "/org/mpris/MediaPlayer2"
                            "org.freedesktop.DBus.Properties.Get"
                            "string:org.mpris.MediaPlayer2.Player" "string:Metadata"))
             (define-values (_s status)
               (run-capture "dbus-send" "--session" "--print-reply"
                            (string-append "--dest=" name) "/org/mpris/MediaPlayer2"
                            "org.freedesktop.DBus.Properties.Get"
                            "string:org.mpris.MediaPlayer2.Player" "string:PlaybackStatus"))
             (string-append name "\n" meta "\n" status)))
         (values 0 (string-append names "\n" (string-join outs "\n")))]
        [else (values 1 "unsupported platform")]))
    (cond
      [(string-contains? text fixture-title) (cons #t text)]
      [(>= (current-inexact-milliseconds) deadline)
       (cons #f (string-append
                 text
                 "\n--- bus identities ---\n"
                 (string-join
                  (map bus-identity
                       (filter (lambda (s) (string-prefix? s ":"))
                               (unbox last-names-box)))
                  "\n")
                 "\n--- poll timeline ---\n"
                 (string-join (reverse (unbox poll-log-box)) "\n")))]
      [else (sleep 1.0) (loop)])))

(define nowplaying-result (box (cons #f "probe not run")))

;; swiftc cold-compiles the probe on hosted macOS runners; compile once in
;; the background at module load (no -O: the probe is I/O-bound, and -O
;; tripled the cold compile) so the probe thread only executes the binary
;; while playback is live.
(define swift-bin-box (box #f))
(define (precompile-swift-probe!)
  (thread
   (lambda ()
     (with-handlers ([exn:fail? void])
       ;; CI precompiles the probe in its own step (hosted macOS swiftc cold
       ;; compiles slower than the probe budget); local runs compile here.
       (define env-bin (getenv "PODLENS_NOWPLAYING_PROBE_BIN"))
       (cond
         [(and env-bin (file-exists? env-bin))
          (set-box! swift-bin-box (string->path env-bin))]
         [else
          (define src (build-path home "nowplaying-probe.swift"))
          (define bin (build-path home "nowplaying-probe"))
          (copy-file nowplaying-probe-src src #:exists-ok? #t)
          (define-values (cc _) (run-capture "swiftc" (path->string src) "-o" (path->string bin)))
          (when (zero? cc) (set-box! swift-bin-box bin))])))))
(define (wait-swift-probe-bin)
  (let wait ([n 90])
    (cond [(unbox swift-bin-box)]
          [(> n 0) (sleep 1) (wait (sub1 n))]
          [else #f])))
(when (eq? (system-type) 'macosx) (precompile-swift-probe!))
(define (start-nowplaying-probe! url)
  (thread
   (lambda ()
     (with-handlers ([exn:fail? (lambda (e)
                                  (set-box! nowplaying-result
                                            (cons #f (exn-message e))))])
       (set-box! nowplaying-result (probe-nowplaying url))))))

;; Start the engine transport (the app's module+ main does the same).
(start-engine!)

(define (post-json base path body)
  (define url (string->url (string-append base path)))
  (define resp
    (post-pure-port url
                    (string->bytes/utf-8 (jsexpr->string body))
                    '("Content-Type: application/json")))
  (define text (port->string resp))
  (close-input-port resp)
  (with-handlers ([exn:fail? (lambda (_) text)])
    (string->jsexpr text)))

;; Raw GET with status + headers (media carrier probes).
(define (get-raw base path headers)
  (define u (string->url (string-append base path)))
  (define-values (status hs port)
    (http-sendrecv (url-host u) (string-append "/" path)
                   #:port (url-port u)
                   #:method #"GET"
                   #:headers headers))
  (define body (port->bytes port))
  (close-input-port port)
  (values status hs body))

(define (header-ref hs name)
  ;; net/http-client returns header lines as raw bytes, e.g. #"Server: Racket".
  (define nm (if (bytes? name) (bytes->string/latin-1 name) name))
  (define prefix (string->bytes/latin-1 (string-append (string-downcase nm) ": ")))
  (for/or ([line (in-list hs)])
    (define low (string->bytes/latin-1 (string-downcase (bytes->string/latin-1 line))))
    (and (>= (bytes-length low) (bytes-length prefix))
         (bytes=? (subbytes low 0 (bytes-length prefix)) prefix)
         (subbytes line (bytes-length prefix)))))

(define (bytes-ci=? a b)
  (bytes=? (string->bytes/latin-1 (string-downcase (bytes->string/latin-1 a)))
           (string->bytes/latin-1 (string-downcase (bytes->string/latin-1 b)))))

(define-values (_kind stop)
  (run-app
   #:public-dir frontend-dist
   #:api api
   #:transport 'http
   #:api-token #f
   #:events event-bus
   #:title "PodLens"
   #:width 1200
   #:height 800
   #:on-ready
   (lambda (wv url)
     ;; Wait for the page (its <title> starts with PodLens). WebView2 cold
     ;; starts on loaded runners can exceed 20s before the title lands.
     (define deadline (+ (current-inexact-milliseconds) 45000))
     (define loaded?
       (let loop ()
         (cond
           [(and (string? (webview-title wv))
                 (string-prefix? (webview-title wv) "PodLens")) #t]
           [(>= (current-inexact-milliseconds) deadline) #f]
           [else (sleep 0.1) (loop)])))
     (sleep 1.5)
     (define url-ok? (equal? (webview-url wv) url))
     (define shot (webview-capture! wv))
     ;; A rendered capture at the right URL is page-loaded evidence even if
     ;; the title probe timed out (WebView2 title updates lag navigation).
     (define loaded-final?
       (or loaded? (and url-ok? (string? shot) (file-exists? shot))))
     (define saved-shot
       (cond
         [(and shot (file-exists? shot))
          (make-directory* evidence-dir)
          (define dest (build-path evidence-dir "podlens-window.png"))
          (copy-file shot dest #:exists-ok? #t)
          dest]
         [else #f]))
     ;; Drive the typed routes over the same adapter the page uses.
     (define health (post-json url "api/health" (hasheq)))
     (define engine-health (post-json url "api/rpc/health" (hasheq)))
     (define feeds (post-json url "api/rpc/feed-list" (hasheq)))
     (define catalog (post-json url "api/rpc/catalog-list" (hasheq)))
     (define settings (post-json url "api/rpc/settings-list" (hasheq)))
     (define set-ok (post-json url "api/rpc/settings-set"
                               (hasheq 'key "appearance" 'value "dark")))
     (define settings2 (post-json url "api/rpc/settings-list" (hasheq)))
     (define appearance
       (for/or ([r (in-list (if (list? settings2) settings2 '()))])
         (and (list? r) (equal? (car r) "appearance") (cadr r))))
     (define sec (post-json url "api/rpc/security-status" (hasheq)))
     (define us (post-json url "api/rpc/update-state" (hasheq)))
     (define resume (post-json url "api/rpc/resume-last" (hasheq)))
     (define pos-unknown (post-json url "api/rpc/position-save"
                                    (hasheq 'id "nope" 'seconds "1" 'done "0")))
     ;; Negative path: the engine's message must reach the client (glaze
     ;; bad-param channel), never a generic internal error.
     (define bad-setting (post-json url "api/rpc/settings-set"
                                    (hasheq 'key "no-such-key" 'value "x")))
     ;; ---- media carrier: Range streaming from the engine audio cache ----
     (define audio-dir-path (build-path home "audio"))
     (make-directory* audio-dir-path)
     (define aid "abcdef0123456789abcdef0123456789abcdef01")
     (define payload (make-bytes 4096 65))
     (call-with-output-file (build-path audio-dir-path (string-append aid ".mp3"))
       (lambda (out) (write-bytes payload out)))
     (define-values (st-full hs-full body-full)
       (get-raw url (string-append "api/audio/" aid) '()))
     (define-values (st-part hs-part body-part)
       (get-raw url (string-append "api/audio/" aid)
                (list #"Range: bytes=100-199")))
     (define-values (st-open hs-open body-open)
       (get-raw url (string-append "api/audio/" aid)
                (list #"Range: bytes=4000-")))
     (define-values (st-suffix hs-suffix body-suffix)
       (get-raw url (string-append "api/audio/" aid)
                (list #"Range: bytes=-50")))
     (define-values (st-bad hs-bad body-bad)
       (get-raw url (string-append "api/audio/" aid)
                (list #"Range: bytes=9000-9999")))
     (define-values (st-404 hs-404 body-404)
       (get-raw url "api/audio/no-such-id" '()))
     (define-values (st-trav hs-trav body-trav)
       (get-raw url "api/audio/..%2Fescape" '()))
     ;; ---- thin host: tray + launch-at-login contract ----
     (install-host! wv url)
     (define autostart (post-json url "api/host/autostart" (hasheq)))
     (define autostart-dev (post-json url "api/host/autostart_set" (hasheq 'enabled #t)))
     ;; ---- acceptance harness gate + in-page journey (#e2e, slice 2) ----
     (define e2e-state (post-json url "api/host/e2e" (hasheq)))
     ;; glaze exposes no JS injection, so the journey runs inside the page:
     ;; navigate to #e2e and collect the harness reports over the host gate.
     (webview-navigate wv (string-append url "#e2e"))
     (define journey-deadline (+ (current-inexact-milliseconds) 75000))
     (define probe-started? #f)
     (define reports
       (let loop ()
         (define st (post-json url "api/host/e2e" (hasheq)))
         (define rs (if (hash? st) (hash-ref st 'reports '()) '()))
         ;; Once playback is live, probe the OS Now Playing surface in parallel
         ;; (SMTC / MediaRemote / MPRIS) without stalling the journey clock.
         (when (and (not probe-started?)
                    (for/or ([r (in-list (if (list? rs) rs '()))])
                      (and (hash? r)
                           (equal? (hash-ref r 'id #f) "journey-play-mediasession")
                           (eq? #t (hash-ref r 'ok #f)))))
           (set! probe-started? #t)
           (start-nowplaying-probe! url))
         (cond
           [(for/or ([r (in-list (if (list? rs) rs '()))])
              (and (hash? r) (equal? (hash-ref r 'id #f) "journey-complete")))
            rs]
           [(>= (current-inexact-milliseconds) journey-deadline) rs]
           [else (sleep 0.25) (loop)])))
     (set-box! journey-reports reports)
     ;; Give the OS probe its own budget after the journeys finish; playback
     ;; stays live until webview-close below.
     (when probe-started?
       (define probe-deadline (+ (current-inexact-milliseconds) 60000))
       (let wait-probe ()
         (unless (or (car (unbox nowplaying-result))
                     (>= (current-inexact-milliseconds) probe-deadline))
           (sleep 0.25)
           (wait-probe))))
     (define (step-ok? id)
       (for/or ([r (in-list (if (list? reports) reports '()))])
         (and (hash? r) (equal? (hash-ref r 'id #f) id) (eq? #t (hash-ref r 'ok #f)))))
     (define e2e-shot (webview-capture! wv))
     (define saved-e2e-shot
       (cond
         [(and e2e-shot (file-exists? e2e-shot))
          (make-directory* evidence-dir)
          (define dest (build-path evidence-dir "podlens-e2e.png"))
          (copy-file e2e-shot dest #:exists-ok? #t)
          dest]
         [else #f]))
     (set! verdicts
           (list (cons 'page-loaded loaded-final?)
                 (cons 'url url-ok?)
                 (cons 'capture (and saved-shot (> (file-size saved-shot) 0)))
                 (cons 'health-ok (and (hash? health) (equal? "true" (hash-ref health 'ok #f))))
                 (cons 'engine-health (and (string? engine-health)
                                           (string-contains? engine-health "podlens")))
                 (cons 'feed-list (and (list? feeds) (= 1 (length feeds))))
                 (cons 'catalog (and (list? catalog) (>= (length catalog) 1)))
                 (cons 'settings (and (list? settings) (>= (length settings) 5)))
                 (cons 'settings-set (eq? #t set-ok))
                 (cons 'settings-reflect (equal? appearance "dark"))
                 (cons 'security-status (and (string? sec)
                                             (hash? (with-handlers ([exn:fail? (lambda (_) #f)])
                                                      (string->jsexpr sec)))))
                 (cons 'update-state (and (hash? us) (equal? "idle" (hash-ref us 'phase #f))))
                 (cons 'resume-fixture (and (list? resume) (= 3 (length resume))
                                            (equal? (caddr resume) "1")))
                 (cons 'position-unknown (eq? #f pos-unknown))
                 (cons 'error-message (and (hash? bad-setting)
                                           (string? (hash-ref bad-setting 'error #f))
                                           (string-contains? (hash-ref bad-setting 'error "")
                                                             "unknown setting")))
                 (cons 'media-200 (and (bytes-ci=? st-full #"HTTP/1.1 200 OK")
                                       (= 4096 (bytes-length body-full))
                                       (bytes=? body-full payload)
                                       (equal? #"bytes" (header-ref hs-full #"Accept-Ranges"))))
                 (cons 'media-206 (and (bytes-ci=? st-part #"HTTP/1.1 206 Partial Content")
                                       (= 100 (bytes-length body-part))
                                       (bytes=? body-part (subbytes payload 100 200))
                                       (equal? #"bytes 100-199/4096"
                                               (header-ref hs-part #"Content-Range"))))
                 (cons 'media-open-range (and (bytes-ci=? st-open #"HTTP/1.1 206 Partial Content")
                                              (= 96 (bytes-length body-open))
                                              (equal? #"bytes 4000-4095/4096"
                                                      (header-ref hs-open #"Content-Range"))))
                 (cons 'media-suffix (and (bytes-ci=? st-suffix #"HTTP/1.1 206 Partial Content")
                                          (= 50 (bytes-length body-suffix))
                                          (bytes=? body-suffix (subbytes payload 4046 4096))))
                 (cons 'media-416 (bytes-ci=? st-bad #"HTTP/1.1 416 Range Not Satisfiable"))
                 (cons 'media-404 (bytes-ci=? st-404 #"HTTP/1.1 404 Not Found"))
                 (cons 'media-traversal-refused
                       (and (not (bytes-ci=? st-trav #"HTTP/1.1 200 OK"))
                            (not (bytes-ci=? st-trav #"HTTP/1.1 206 Partial Content"))
                            (not (bytes=? body-trav payload))))
                 (cons 'autostart-get (and (hash? autostart) (hash-has-key? autostart 'enabled)
                                           (eq? #f (hash-ref autostart 'installed #t))))
                 (cons 'autostart-dev-guard (and (hash? autostart-dev)
                                                 (string-contains? (hash-ref autostart-dev 'error "")
                                                                   "installed build")))
                 (cons 'tray (or (not (tray-supported?)) (host-tray-live?)))
                 (cons 'e2e-gate (and (hash? e2e-state) (eq? #t (hash-ref e2e-state 'enabled #f))))
                 (cons 'journey-boot (step-ok? "boot-loaded"))
                 (cons 'journey-episodes (step-ok? "nav-episodes"))
                 (cons 'journey-discover (step-ok? "nav-discover"))
                 (cons 'journey-settings (step-ok? "nav-settings"))
                 (cons 'journey-theme (step-ok? "theme-toggle"))
                 (cons 'journey-home (step-ok? "nav-home"))
                 (cons 'fixture-seeded (and (zero? seed-exit)
                                            (file-exists? (build-path home "listening-fixture.json"))))
                 (cons 'journey-open-episode (step-ok? "journey-open-episode"))
                 (cons 'journey-sentence-seek (step-ok? "journey-sentence-seek"))
                 (cons 'journey-play-mediasession (step-ok? "journey-play-mediasession"))
                 (cons 'journey-follow-sync (step-ok? "journey-follow-sync"))
                 (cons 'journey-summary-anchors (step-ok? "journey-summary-anchors"))
                 (cons 'journey-pause-position (step-ok? "journey-pause-position"))
                 (cons 'journey-complete (step-ok? "journey-complete"))
                 (cons 'nowplaying-os (car (unbox nowplaying-result)))
                 (cons 'e2e-capture (and saved-e2e-shot (> (file-size saved-e2e-shot) 0)))))
     (webview-close wv))))

(stop)
(host-teardown!)
(for ([verdict (in-list verdicts)])
  (printf "[verify] ~a = ~a\n" (car verdict) (cdr verdict)))
(define np-detail (cdr (unbox nowplaying-result)))
(printf "[verify] nowplaying detail: ~a\n"
        (substring np-detail 0 (min 6000 (string-length np-detail))))
(for ([r (in-list (if (list? (unbox journey-reports)) (unbox journey-reports) '()))])
  (when (and (hash? r) (equal? (hash-ref r 'id #f) "journey-play-mediasession"))
    (printf "[verify] play journey detail: ~a\n" (hash-ref r 'detail ""))))
(unless (and (pair? verdicts) (andmap cdr verdicts))
  (eprintf "[verify] native UI verification failed\n")
  (for ([r (in-list (if (list? (unbox journey-reports)) (unbox journey-reports) '()))])
    (when (and (hash? r) (not (eq? #t (hash-ref r 'ok #f))))
      (eprintf "[verify] harness ~a failed: ~a\n"
               (hash-ref r 'id "?") (hash-ref r 'detail ""))))
  (exit 1))
(displayln "[verify] ALL PASS")