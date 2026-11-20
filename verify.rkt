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
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         "backend/main.rkt")

(define-runtime-path frontend-dist "apps/desktop/dist")
(define-runtime-path evidence-dir ".glaze/verify")
(define-runtime-path seed-script "scripts/e2e/seed-listening-fixture.rkt")

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
     ;; Wait for the page (its <title> starts with PodLens).
     (define deadline (+ (current-inexact-milliseconds) 20000))
     (define loaded?
       (let loop ()
         (cond
           [(and (string? (webview-title wv))
                 (string-prefix? (webview-title wv) "PodLens")) #t]
           [(>= (current-inexact-milliseconds) deadline) #f]
           [else (sleep 0.1) (loop)])))
     (sleep 1.5)
     (define url-ok? (equal? (webview-url wv) url))
     (define shot (and loaded? (webview-capture! wv)))
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
     (define journey-deadline (+ (current-inexact-milliseconds) 30000))
     (define reports
       (let loop ()
         (define st (post-json url "api/host/e2e" (hasheq)))
         (define rs (if (hash? st) (hash-ref st 'reports '()) '()))
         (cond
           [(for/or ([r (in-list (if (list? rs) rs '()))])
              (and (hash? r) (equal? (hash-ref r 'id #f) "journey-complete")))
            rs]
           [(>= (current-inexact-milliseconds) journey-deadline) rs]
           [else (sleep 0.25) (loop)])))
     (set-box! journey-reports reports)
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
           (list (cons 'page-loaded loaded?)
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
                 (cons 'e2e-capture (and saved-e2e-shot (> (file-size saved-e2e-shot) 0)))))
     (webview-close wv))))

(stop)
(host-teardown!)
(for ([verdict (in-list verdicts)])
  (printf "[verify] ~a = ~a\n" (car verdict) (cdr verdict)))
(unless (and (pair? verdicts) (andmap cdr verdicts))
  (eprintf "[verify] native UI verification failed\n")
  (for ([r (in-list (if (list? (unbox journey-reports)) (unbox journey-reports) '()))])
    (when (and (hash? r) (not (eq? #t (hash-ref r 'ok #f))))
      (eprintf "[verify] harness ~a failed: ~a\n"
               (hash-ref r 'id "?") (hash-ref r 'detail ""))))
  (exit 1))
(displayln "[verify] ALL PASS")