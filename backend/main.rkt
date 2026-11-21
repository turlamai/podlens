#lang racket/base

;; PodLens glaze backend (#63) — the single web UI's backend adapter.
;;
;; The Racket engine (racket/) is unchanged: this module loads the
;; production backend, drives it over real in-process RVT1 frames
;; (backend/rvt1.rkt) and exposes every registered RPC 1:1 as a typed
;; glaze route. rivet-schema.json remains the single source of the RPC
;; contract — backend/wire-codec.rkt converts camelCase JSON DTOs to the
;; schema's field-ordered wire values and back, and
;; scripts/check-rpc-surface.py gates this route surface against it.
;;
;; Carrier decision (#63, declared on the issue): production runs glaze's
;; first-class HTTP adapter on 127.0.0.1 with a per-launch token. The
;; engine's audio cache is streamed to the webview's <audio> element
;; through a Range-capable host route (GET api/audio/:id) on the same
;; origin; the token bootstrap cookie authenticates media requests just
;; like RPC calls. The native GLZ1 carrier remains available for
;; development (PODLENS_TRANSPORT=native) but cannot serve media.
;;
;; Run:  pnpm --filter @podlens/desktop build   (once)
;;       racket backend/main.rkt
;; Dev:  raco glaze dev  /  PODLENS_TRANSPORT=native for the GLZ1 carrier.

(require glaze/app        ; run-app, open-app-window, app-quit!, current-app
         glaze/api        ; POST, GET, exn:fail:glaze:bad-param
         glaze/api-macros ; define-api-routes
         glaze/events     ; make-event-bus, bus-broadcast!
         glaze/shell      ; shell-spawn! (reveal / open external)
         glaze/types      ; GString, GInt64, GBool, GValue, goptional, grecord
         glaze            ; make-tray, make-menu-item, tray-supported?
         (only-in glaze/now-playing ; host-owned OS Now Playing (glaze#153)
                  now-playing-set! now-playing-clear!
                  now-playing-os-info now-playing-set-command-handler!
                  now-playing-supported?)
         glaze/autolaunch ; auto-launch-set! / auto-launch-enabled?
         (only-in glaze/server path->mime-type)
         web-server/http/response-structs ; response/full, response/output
         web-server/http/request-structs  ; request-headers/raw, headers-assq
         racket/file
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         json
         "../racket/core/i18n.rkt"   ; tr — the i18n single source (tray labels)
         (only-in "../racket/core/paths.rkt"
                  [data-dir podlens-data-dir]
                  [audio-dir podlens-audio-dir]) ; engine data home
         "../racket/version.rkt"
         ;; Static require: registration happens at load time AND raco exe
         ;; embeds the engine for packaged builds (a runtime dynamic-require
         ;; cannot resolve source paths inside the distribution).
         (prefix-in engine: "../racket/backend.rkt")
         "rvt1.rkt"
         "wire-codec.rkt")

;; The route list schema tooling reads (glaze.rktd points here).
;; start-engine! wires the codec to the in-process RVT1 transport — the
;; app entry and the real-window verifier both call it; schema checks
;; load this module without starting anything.
(provide api start-engine!
         event-bus
         install-host! host-teardown!
         host-tray-live? host-open-external!
         audio-file-for)

;; Development serves the vite build straight from the workspace; a packaged
;; app (raco glaze build) ships the same tree as `public/` next to the exe
;; (macOS: inside the bundle's Resources, which the generated entry makes the
;; working directory), so prefer that copy when it exists.
(define-runtime-path dev-frontend-dist "../apps/desktop/dist")
(define frontend-dist
  (let* ([run (find-system-path 'run-file)]
         [exe-dir (and (path? run) (path-only run))]
         [candidates (list (and exe-dir (build-path exe-dir "public"))
                           (and exe-dir (build-path exe-dir ".." "public"))
                           (and exe-dir (build-path exe-dir ".." "Resources" "public"))
                           (build-path (current-directory) "public"))])
    (or (for/or ([dir (in-list candidates)])
          (and dir (directory-exists? dir) dir))
        dev-frontend-dist)))

(define bus (make-event-bus))
(define event-bus bus)

;; ---- engine event relay -------------------------------------------------
;; The podlens engine really emits its five declared events (notify,
;; job-progress, episodes-changed, open-url, update-available). Relay each
;; by name onto the glaze bus so both carriers push it to every window.
;; Payloads must be JSON-serializable: normalize recursively (void → null)
;; before broadcasting — a #<void> would kill an SSE connection mid-stream.
(define (json-safe v)
  (cond
    [(void? v) 'null]
    [(hash? v)
     (for/hash ([(k val) (in-hash v)])
       (values (if (symbol? k) k (json-safe k)) (json-safe val)))]
    [(list? v) (map json-safe v)]
    [(pair? v) (cons (json-safe (car v)) (json-safe (cdr v)))]
    [else v]))

(define engine-events
  '("notify" "job-progress" "episodes-changed" "open-url" "update-available"))

(set-event-handler!
 (lambda (payload)
   (match payload
     [(list name data)
      #:when (and (string? name) (member name engine-events))
      (when (equal? name "open-url")
        ;; The engine asks the host to open a page (releases, episode
        ;; links); the web UI never navigates the app window away.
        (host-open-external! (format "~a" data)))
      (bus-broadcast! bus (string->symbol name) (json-safe data))]
     [_ (bus-broadcast! bus 'engine-event (json-safe payload))])))

;; ---- typed RPC surface (1:1 with rivet-schema.json) ----------------------
;; Structured DTOs (records/lists) ride GValue at the transport boundary;
;; their shapes are enforced by the schema-driven codec, and the surface
;; gate keeps names/arity/scalar types aligned with rivet-schema.json.

(define-api-routes api-typed
  ;; health
  [(POST "api/rpc/health" #:returns GString)
   (health)
   (rpc/json "health" (hasheq))]

  ;; feeds
  [(POST "api/rpc/feed-add" #:returns GString)
   (feedAdd [url GString])
   (rpc/json "feed-add" (hasheq 'url url))]
  [(POST "api/rpc/feed-remove" #:returns GBool)
   (feedRemove [id GString])
   (rpc/json "feed-remove" (hasheq 'id id))]
  [(POST "api/rpc/feed-list" #:returns GValue)
   (feedList)
   (rpc/json "feed-list" (hasheq))]
  [(POST "api/rpc/feed-refresh" #:returns GInt64)
   (feedRefresh [id GString])
   (rpc/json "feed-refresh" (hasheq 'id id))]
  [(POST "api/rpc/feed-refresh-all" #:returns GInt64)
   (feedRefreshAll)
   (rpc/json "feed-refresh-all" (hasheq))]

  ;; discovery
  [(POST "api/rpc/catalog-list" #:returns GValue)
   (catalogList)
   (rpc/json "catalog-list" (hasheq))]
  [(POST "api/rpc/catalog-search" #:returns GValue)
   (catalogSearch [query GString])
   (rpc/json "catalog-search" (hasheq 'query query))]
  [(POST "api/rpc/feed-peek" #:returns GValue)
   (feedPeek [url GString])
   (rpc/json "feed-peek" (hasheq 'url url))]
  [(POST "api/rpc/preview-audio" #:returns GString)
   (previewAudio [enclosureUrl GString])
   (rpc/json "preview-audio" (hasheq 'enclosureUrl enclosureUrl))]

  ;; episodes
  [(POST "api/rpc/episode-list" #:returns GValue)
   (episodeList [feedId GString])
   (rpc/json "episode-list" (hasheq 'feedId feedId))]
  [(POST "api/rpc/episode-recent" #:returns GValue)
   (episodeRecent)
   (rpc/json "episode-recent" (hasheq))]
  [(POST "api/rpc/episode-download" #:returns GString)
   (episodeDownload [id GString])
   (rpc/json "episode-download" (hasheq 'id id))]
  [(POST "api/rpc/episode-transcribe" #:returns GString)
   (episodeTranscribe [id GString])
   (rpc/json "episode-transcribe" (hasheq 'id id))]
  [(POST "api/rpc/episode-translate" #:returns GString)
   (episodeTranslate [id GString])
   (rpc/json "episode-translate" (hasheq 'id id))]
  [(POST "api/rpc/episode-summarize" #:returns GString)
   (episodeSummarize [id GString])
   (rpc/json "episode-summarize" (hasheq 'id id))]
  [(POST "api/rpc/episode-remove-audio" #:returns GBool)
   (episodeRemoveAudio [id GString])
   (rpc/json "episode-remove-audio" (hasheq 'id id))]
  [(POST "api/rpc/episode-pipeline" #:returns GString)
   (episodePipeline [id GString])
   (rpc/json "episode-pipeline" (hasheq 'id id))]
  [(POST "api/rpc/episode-estimate" #:returns GString)
   (episodeEstimate [id GString])
   (rpc/json "episode-estimate" (hasheq 'id id))]
  [(POST "api/rpc/episode-set-done" #:returns GBool)
   (episodeSetDone [id GString] [done GString])
   (rpc/json "episode-set-done" (hasheq 'id id 'done done))]
  [(POST "api/rpc/resume-last" #:returns GValue)
   (resumeLast)
   (rpc/json "resume-last" (hasheq))]
  [(POST "api/rpc/episode-chapters" #:returns GValue)
   (episodeChapters [id GString])
   (rpc/json "episode-chapters" (hasheq 'id id))]
  [(POST "api/rpc/episode-transcript" #:returns GValue)
   (episodeTranscript [id GString])
   (rpc/json "episode-transcript" (hasheq 'id id))]
  [(POST "api/rpc/episode-summary" #:returns GString)
   (episodeSummary [id GString])
   (rpc/json "episode-summary" (hasheq 'id id))]
  [(POST "api/rpc/position-save" #:returns GBool)
   (positionSave [id GString] [seconds GString] [done GString])
   (rpc/json "position-save" (hasheq 'id id 'seconds seconds 'done done))]

  ;; jobs
  [(POST "api/rpc/job-status" #:returns GString)
   (jobStatus [jobId GString])
   (rpc/json "job-status" (hasheq 'jobId jobId))]
  [(POST "api/rpc/job-cancel" #:returns GBool)
   (jobCancel [jobId GString])
   (rpc/json "job-cancel" (hasheq 'jobId jobId))]

  ;; settings
  [(POST "api/rpc/settings-list" #:returns GValue)
   (settingsList)
   (rpc/json "settings-list" (hasheq))]
  [(POST "api/rpc/security-status" #:returns GString)
   (securityStatus)
   (rpc/json "security-status" (hasheq))]
  [(POST "api/rpc/ai-test" #:returns GString)
   (aiTest)
   (rpc/json "ai-test" (hasheq))]
  [(POST "api/rpc/settings-set" #:returns GBool)
   (settingsSet [key GString] [value GString])
   (rpc/json "settings-set" (hasheq 'key key 'value value))]

  ;; updates
  [(POST "api/rpc/update-check" #:returns GValue)
   (updateCheck)
   (rpc/json "update-check" (hasheq))]
  [(POST "api/rpc/start-download" #:returns GValue)
   (startDownload)
   (rpc/json "start-download" (hasheq))]
  [(POST "api/rpc/update-state" #:returns GValue)
   (updateState)
   (rpc/json "update-state" (hasheq))]
  [(POST "api/rpc/open-releases" #:returns GValue)
   (openReleases)
   (rpc/json "open-releases" (hasheq))]

  ;; ---- host capabilities (not engine RPCs; outside the surface gate) ----
  [(POST "api/health" #:returns (grecord "Health" "ok" GString "version" GString))
   (healthHost)
   (hasheq 'ok "true" 'version app-version)]
  [(POST "api/host/reveal" #:returns GBool)
   (reveal [path GString])
   (reveal-path path)]
  [(POST "api/host/open_external" #:returns GBool)
   (openExternal [url GString])
   (host-open-external! url)]
  ;; Launch-at-login: the OS entry is the source of truth (no config key).
  [(POST "api/host/autostart" #:returns GValue)
   (autostart)
   (host-autostart-state)]
  [(POST "api/host/autostart_set" #:returns GValue)
   (autostartSet [enabled GBool])
   (host-autostart-set! enabled)]
  ;; Host-owned OS Now Playing (glaze#153): the page syncs playback state
  ;; here and the host publishes the OS surface (macOS MediaPlayer,
  ;; Linux own MPRIS; Windows stub inert — web SMTC stays the path there).
  ;; now-playing_os reads the OS surface back for acceptance evidence.
  [(POST "api/host/now-playing" #:returns GBool)
   (nowPlaying [info GValue])
   (host-now-playing! info)
   #t]
  [(POST "api/host/now-playing_os" #:returns GValue)
   (nowPlayingOs)
   (or (now-playing-os-info) (hasheq))]

  ;; ---- acceptance harness gate (#63 slice 5) ---------------------------
  ;; The web UI carries an in-page journey harness (#e2e) because glaze
  ;; exposes no JS injection into the webview. These routes are inert
  ;; unless PODLENS_E2E=1 (acceptance jobs / verify.rkt only); the page
  ;; harness additionally requires the #e2e hash AND enabled=true here.
  [(POST "api/host/e2e" #:returns GValue)
   (e2e)
   (host-e2e-state)]
  [(POST "api/host/e2e_report" #:returns GBool)
   (e2eReport [id GString] [ok GBool] [detail GString])
   (host-e2e-report! id ok detail)
   #t]
  [(POST "api/host/e2e_fs" #:returns GValue)
   (e2eFs [op GString] [path GString] [data (goptional GString)])
   (host-e2e-fs op path (or data ""))])

;; ---- media carrier (GET api/audio/:id) ----------------------------------
;; The engine's audio cache (<data-dir>/audio/<id>.<ext>, including
;; preview-<sha> files) streamed to the webview's <audio> element with
;; Range support — sentence seeking and −15/+30 need partial content.
;; Host-side path resolution follows the AGENTS convention (scan audio/
;; by episode-id prefix); the engine contract is untouched. The token
;; bootstrap cookie (HttpOnly glaze_token) authenticates these GETs exactly
;; like RPC calls; the dispatcher guards every matched API route.

(define (audio-file-for id)
  (unless (and (string? id) (regexp-match? #rx"^[A-Za-z0-9_-]+$" id))
    (bad-param (format "audio id: invalid identifier ~v" id)))
  (define dir (podlens-audio-dir))
  (define prefix (string-append id "."))
  (and (directory-exists? dir)
       (for/or ([f (in-list (directory-list dir))])
         (define p (build-path dir f))
         (and (string-prefix? (path->string f) prefix)
              (file-exists? p)
              p))))

(define (audio-mime p)
  (define ext (string-downcase (bytes->string/utf-8 (or (path-get-extension p) #""))))
  (define explicit
    (cond
      [(string=? ext ".mp3") #"audio/mpeg"]
      [(string=? ext ".m4a") #"audio/mp4"]
      [(string=? ext ".mp4") #"audio/mp4"]
      [(string=? ext ".aac") #"audio/aac"]
      [(string=? ext ".ogg") #"audio/ogg"]
      [(string=? ext ".oga") #"audio/ogg"]
      [(string=? ext ".opus") #"audio/ogg"]
      [(string=? ext ".wav") #"audio/wav"]
      [(string=? ext ".flac") #"audio/flac"]
      [else #f]))
  (or explicit (path->mime-type p) #"application/octet-stream"))

;; bytes=N-M | bytes=N- | bytes=-S → (cons start end) inclusive;
;; #f = no Range header (full body); 'invalid = unsatisfiable.
(define (parse-range value size)
  (cond
    [(not value) #f]
    [(regexp-match #rx"^bytes=([0-9]*)-([0-9]*)$" value)
     => (lambda (m)
          (define s (cadr m))
          (define e (caddr m))
          (cond
            [(and (string=? s "") (string=? e "")) 'invalid]
            [(string=? s "")
             (define n (string->number e))
             (if (or (not n) (zero? n) (> n size))
                 (cons 0 (sub1 size))
                 (cons (- size n) (sub1 size)))]
            [else
             (define start (string->number s))
             (define end (if (string=? e "") (sub1 size) (string->number e)))
             (if (or (not start) (not end) (>= start size) (< end start))
                 'invalid
                 (cons start (min end (sub1 size))))]))]
    [else 'invalid]))

(define (stream-file p start end out)
  (call-with-input-file p
    (lambda (in)
      (file-position in start)
      (let loop ([remaining (add1 (- end start))])
        (when (> remaining 0)
          (define chunk (read-bytes (min 65536 remaining) in))
          (unless (eof-object? chunk)
            (write-bytes chunk out)
            (loop (- remaining (bytes-length chunk)))))))))

(define (media-response req id)
  (define p (audio-file-for id))
  (cond
    [(not p)
     (response/full 404 #"Not Found" (current-seconds)
                    #"text/plain; charset=utf-8" '() (list #"Not found"))]
    [else
     (define size (file-size p))
     (define range-h
       (let ([h (headers-assq #"Range" (request-headers/raw req))])
         (and h (bytes->string/latin-1 (header-value h)))))
     (define mime (audio-mime p))
     (define base-headers
       (list (header #"Accept-Ranges" #"bytes")
             (header #"Cache-Control" #"no-store")
             (header #"X-Content-Type-Options" #"nosniff")))
     (define parsed (parse-range range-h size))
     (cond
       [(eq? parsed 'invalid)
        (response/full 416 #"Range Not Satisfiable" (current-seconds)
                       #"text/plain; charset=utf-8"
                       (list (header #"Content-Range"
                                     (string->bytes/latin-1 (format "bytes */~a" size))))
                       (list #"Range not satisfiable"))]
       [(not parsed)
        (response/output (lambda (out) (stream-file p 0 (sub1 size) out))
                         #:code 200 #:message #"OK" #:mime-type mime
                         #:headers (cons (header #"Content-Length"
                                                 (string->bytes/latin-1 (format "~a" size)))
                                         base-headers)
                         #:seconds (current-seconds))]
       [else
        (match-define (cons start end) parsed)
        (response/output (lambda (out) (stream-file p start end out))
                         #:code 206 #:message #"Partial Content" #:mime-type mime
                         #:headers (list* (header #"Content-Range"
                                                  (string->bytes/latin-1
                                                   (format "bytes ~a-~a/~a" start end size)))
                                          (header #"Content-Length"
                                                  (string->bytes/latin-1
                                                   (format "~a" (add1 (- end start)))))
                                          base-headers)
                         #:seconds (current-seconds))])]))

;; Raw GET route (web-server request + captured :id); the dispatcher
;; passes response? objects through untouched on the HTTP carrier.
(define api
  (append api-typed
          (list (GET "api/audio/:id" media-response))))

;; ---- host helpers --------------------------------------------------------

(define (bad-param message)
  (raise (exn:fail:glaze:bad-param message (current-continuation-marks))))

;; Show a folder in the system file manager (settings → data folder).
;; An empty path means the engine data directory (the web UI does not
;; know the absolute path; the host does).
(define (reveal-path path)
  (define target (if (string=? path "") (path->string (podlens-data-dir)) path))
  (define dir
    (if (directory-exists? target)
        target
        (let-values ([(base name dir?) (split-path target)])
          (if (path? base) (path->string base) target))))
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (case (system-type 'os)
      [(windows) (shell-spawn! "explorer.exe" (list dir)) #t]
      [(macosx) (shell-spawn! "open" (list dir)) #t]
      [else (cond
              [(find-executable-path "xdg-open")
               (shell-spawn! "xdg-open" (list dir)) #t]
              [else #f])])))

;; Open an http(s) page in the system browser (engine open-url events,
;; releases page). Only http(s) is accepted — never a local executable.
(define (host-open-external! url)
  (define s (format "~a" url))
  (unless (or (string-prefix? s "https://") (string-prefix? s "http://"))
    (bad-param (format "open_external: refusing non-http URL ~v" s)))
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (case (system-type 'os)
      [(windows) (shell-spawn! "explorer.exe" (list s)) #t]
      [(macosx) (shell-spawn! "open" (list s)) #t]
      [else (cond
              [(find-executable-path "xdg-open")
               (shell-spawn! "xdg-open" (list s)) #t]
              [else #f])])))

;; ---- thin host runtime ---------------------------------------------------
;; Tray residency is the background-playback contract: closing the main
;; window keeps the app (and the webview's audio) alive; Quit lives in the
;; tray menu. Without tray support the last window closing quits normally.
;; Tray labels read the engine i18n single source; language follows the
;; ui-lang setting at install time.

(define main-wv (box #f))
(define base-url (box #f))
(define host-app (box #f))
(define tray-handle (box #f))

(define-runtime-path icon-ico "../assets/branding/app.ico")
(define-runtime-path icon-png "../assets/branding/app.png")

(define (host-ui-lang)
  (with-handlers ([exn:fail? (lambda (_) "zh")])
    (define rows (rpc/json "settings-list" (hasheq)))
    (define row (for/or ([r (in-list rows)])
                  (and (pair? r) (equal? (car r) "ui-lang") r)))
    (if row (format "~a" (cadr row)) "zh")))

(define (installed-exe?)
  ;; Launch-at-login registers the running executable; under `racket
  ;; backend/main.rkt` (or any script, e.g. the verifier) run-file is the
  ;; interpreter or the source file, which must never become a login item.
  (define p (find-system-path 'run-file))
  (define name (string-downcase (path->string (file-name-from-path p))))
  (and (not (or (path-has-extension? p #".rkt") (path-has-extension? p #".rktd")))
       (not (member name '("racket.exe" "racket")))))

(define (with-host-app thunk)
  (parameterize ([current-app (unbox host-app)]) (thunk)))

(define (show-main!)
  (with-host-app
   (lambda ()
     (define wv (unbox main-wv))
     (if (and wv (not (webview-closed? wv)))
         (webview-focus! wv)
         (let ([w (open-app-window (unbox base-url)
                                   #:title "PodLens"
                                   #:width 1200
                                   #:height 800
                                   #:on-close main-close!)])
           (set-box! main-wv w))))))

;; Closing the main window never quits by itself: audio keeps playing in
;; the resident webview (background playback). Quit is the tray action.
(define (main-close!)
  (set-box! main-wv #f))

(define (host-tray-live?) (and (unbox tray-handle) #t))

;; ---- host-owned OS Now Playing (glaze#153) -------------------------------
;; JSON object keys arrive as symbols or strings depending on carrier;
;; accept both so the page sync never depends on codec internals.
(define (np-ref h k d)
  (if (hash? h)
      (hash-ref h k (lambda () (hash-ref h (symbol->string k) d)))
      d))

(define np-post-log-count (box 0))
(define (host-now-playing! info)
  (cond
    [(or (not info) (and (hash? info) (np-ref info 'clear #f)))
     (now-playing-clear!)]
    [(hash? info)
     (now-playing-set!
      (hasheq 'title (np-ref info 'title "")
              'artist (np-ref info 'artist "")
              'album (np-ref info 'album "")
              'duration (np-ref info 'duration 0.0)
              'position (np-ref info 'position 0.0)
              'playing (np-ref info 'playing #f)
              'identifier (np-ref info 'identifier "site.jrtx.podlens")))]
    [else (void)])
  ;; Carrier evidence: the first few syncs log the backend diagnostics so a
  ;; silently failed publish (bus connect / registration / name ownership)
  ;; is visible in the verify log instead of inferred from host=inert.
  (when (< (unbox np-post-log-count) 3)
    (set-box! np-post-log-count (add1 (unbox np-post-log-count)))
    (with-handlers ([exn:fail? (lambda (_) (void))])
      (define d
        (dynamic-require (case (system-type 'os)
                           [(macosx) 'glaze/now-playing/now-playing-macos]
                           [(unix) 'glaze/now-playing/now-playing-linux]
                           [else 'glaze/now-playing/now-playing-stub])
                         'diagnostics
                         (lambda () #f)))
      (when (procedure? d) (log-warning "now-playing post-publish diag: ~s" (d))))))

(define (autostart-enabled-value)
  (define v (auto-launch-enabled? "PodLens"))
  (if (symbol? v) (symbol->string v) v))

(define (host-autostart-state)
  (hasheq 'enabled (autostart-enabled-value) 'installed (installed-exe?)))

(define (host-autostart-set! enabled)
  (unless (installed-exe?)
    (bad-param "autostart needs an installed build (raco glaze build), not the dev interpreter"))
  (with-handlers ([exn:fail? (lambda (e) (bad-param (exn-message e)))])
    (auto-launch-set! "PodLens" enabled))
  (host-autostart-state))

;; ---- acceptance harness gate (#63 slice 5) -------------------------------
(define (e2e-enabled?) (equal? (getenv "PODLENS_E2E") "1"))
(define e2e-reports (box '()))

(define (require-e2e!)
  (unless (e2e-enabled?) (bad-param "e2e harness disabled (set PODLENS_E2E=1)")))

(define (host-e2e-state)
  (require-e2e!)
  (hasheq 'enabled #t
          'home (path->string (podlens-data-dir))
          'reports (reverse (unbox e2e-reports))))

(define (host-e2e-report! id ok detail)
  (require-e2e!)
  (set-box! e2e-reports (cons (hasheq 'id id 'ok ok 'detail detail) (unbox e2e-reports))))

(define (host-e2e-fs op path data)
  (require-e2e!)
  (cond
    [(string=? op "exists") (hasheq 'exists (file-exists? path))]
    [(string=? op "unlink")
     (with-handlers ([exn:fail? (lambda (_) (void))]) (delete-file path))
     (hasheq 'exists (file-exists? path))]
    [(string=? op "write")
     (make-directory* (or (path-only path) (current-directory)))
     (call-with-output-file path (lambda (out) (display data out)) #:exists 'truncate)
     (hasheq 'exists #t)]
    [(string=? op "copy")
     (copy-file path data #t)
     (hasheq 'exists (file-exists? data))]
    [else (bad-param (format "e2e_fs: unknown op ~v" op))]))

;; Called from #:on-ready (app entry and verifier): remember the window
;; and install the tray. Callbacks run on foreign threads (tray worker),
;; so they re-bind current-app explicitly.
(define (install-host! wv url)
  (set-box! main-wv wv)
  (set-box! base-url url)
  (set-box! host-app (current-app))
  (define lang (host-ui-lang))
  (when (tray-supported?)
    (with-handlers ([exn:fail? (lambda (_) (void))]) ; tray loss never blocks startup
      (set-box! tray-handle
                (make-tray
                 #:icon (if (eq? (system-type 'os) 'windows) icon-ico icon-png)
                 #:tooltip "PodLens"
                 #:menu (list
                         (make-menu-item (tr lang 'tray-show) #:action show-main!)
                         (menu-separator)
                         (make-menu-item (tr lang 'tray-quit)
                                         #:action (lambda ()
                                                    (with-host-app
                                                     (lambda () (app-quit! (unbox host-app)))))))
                 #:on-event (lambda (e)
                              (when (memq e '(click left-click)) (show-main!)))))))
  ;; OS transport commands (MPRIS / MPRemoteCommandCenter) reach the page
  ;; over the SSE engine-event channel; capability loss never blocks startup.
  (with-handlers ([exn:fail? (lambda (_) (void))])
    (now-playing-set-command-handler!
     (lambda (cmd arg)
       (bus-broadcast! bus 'now-playing-command
                       (hasheq 'cmd (symbol->string cmd) 'arg arg)))))
  ;; Carrier diagnostics: a silently degraded backend must be visible in
  ;; the verify log, never inferred from a missing probe surface.
  (log-warning "now-playing supported?=~s" (now-playing-supported?))
  (define np-backend-module
    (case (system-type 'os)
      [(macosx) 'glaze/now-playing/now-playing-macos]
      [(unix) 'glaze/now-playing/now-playing-linux]
      [else 'glaze/now-playing/now-playing-stub]))
  (define np-diag
    (with-handlers ([exn:fail? (lambda (_) #f)])
      (dynamic-require np-backend-module 'diagnostics (lambda () #f))))
  (when (procedure? np-diag)
    (with-handlers ([exn:fail? (lambda (_) (void))])
      (log-warning "now-playing diag: ~s" (np-diag))))
  (unless (now-playing-supported?)
    (with-handlers ([exn:fail? (lambda (e)
                                 (log-warning "now-playing backend load error: ~a"
                                              (exn-message e)))])
      (dynamic-require np-backend-module 'supported?))))

(define (host-teardown!)
  (define t (unbox tray-handle))
  (when t (with-handlers ([exn:fail? (lambda (_) (void))]) (tray-close t)))
  (set-box! tray-handle #f)
  (with-handlers ([exn:fail? (lambda (_) (void))]) (now-playing-clear!))
  ;; Post-journey carrier state: the bus connection is established lazily
  ;; at first publish, so the install-time diagnostics cannot show it.
  (with-handlers ([exn:fail? (lambda (_) (void))])
    (define d (dynamic-require (case (system-type 'os)
                                 [(macosx) 'glaze/now-playing/now-playing-macos]
                                 [(unix) 'glaze/now-playing/now-playing-linux]
                                 [else 'glaze/now-playing/now-playing-stub])
                               'diagnostics (lambda () #f)))
    (when (procedure? d) (log-warning "now-playing teardown diag: ~s" (d)))))

(define engine-started? #f)

(define (start-engine!)
  (unless engine-started?
    (set-rvt1-call! rvt1-call)
    (start-rvt1! engine:start/ports)
    (set! engine-started? #t)))

(module+ main
  (start-engine!)

  ;; Production carrier: loopback HTTP + per-launch token (media needs an
  ;; HTTP origin; see the carrier decision at the top). PODLENS_TRANSPORT
  ;; =native switches to the GLZ1 carrier for development (no media).
  (define transport
    (or (let ([v (getenv "PODLENS_TRANSPORT")])
          (and (member v '("native" "http")) (string->symbol v)))
        'http))
  (define-values (_kind stop)
    (run-app
     #:public-dir frontend-dist
     #:api api
     #:transport transport
     #:api-token (or (getenv "GLAZE_API_TOKEN") #t)
     #:events bus
     #:title "PodLens"
     #:width 1200
     #:height 800
     #:app-id "podlens"
     #:window-state #t
     ;; Tray-resident background playback: closing the last window does
     ;; not quit while the tray can bring it back; without tray support
     ;; the normal last-window quit applies.
     #:quit-on-last-window? (not (tray-supported?))
     #:on-close main-close!
     #:on-ready (lambda (wv url) (install-host! wv url))
     #:current-version app-version))
  (stop)
  (host-teardown!))
