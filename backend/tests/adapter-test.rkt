#lang racket/base

;; Adapter contract test (#63): drive the glaze backend's JSON RPC
;; surface headlessly — the same codec + in-process RVT1 transport the
;; routes use, without a GUI. Runs on every machine (engine acceptance).
;;
;; Isolation mirrors tests/backend-wire-test.rkt: a throwaway PodLens
;; data home via PODLENS_DATA_DIR, so no test touches ~/.podlens or the
;; network. Only offline RPCs are exercised here; provider/network paths
;; stay in the engine's own suite (fake OpenAI server).

(require glaze/api
         rackunit
         racket/file
         racket/path
         racket/string
         json
         "../rvt1.rkt"
         "../wire-codec.rkt"
         "../main.rkt"
         (prefix-in engine: "../../racket/backend.rkt")
         "../../racket/core/i18n.rkt")

(define root (make-temporary-file "podlens-adapter-~a" 'directory))
(putenv "PODLENS_DATA_DIR" (path->string root))

(set-rvt1-call! rvt1-call)
(start-rvt1! engine:start/ports)

(test-case
 "adapter contract surface (#63)"

;; The adapter surface must equal the schema surface (the python gate
;; checks the glaze route list; this checks the codec's runtime table).
(check-equal? (length (rpc-names)) 35 "35 RPCs in rivet-schema.json")

;; health: the engine's one-line status string.
(define h (rpc/json "health" (hasheq)))
(check-true (string? h))
(check-true (string-contains? h "podlens"))

;; Empty library projections.
(check-equal? (rpc/json "feed-list" (hasheq)) '())
(check-equal? (rpc/json "episode-recent" (hasheq)) '())
(check-equal? (rpc/json "resume-last" (hasheq)) '())
(check-equal? (rpc/json "episode-list" (hasheq 'feedId "nope")) '())
(check-equal? (rpc/json "episode-transcript" (hasheq 'id "nope")) '())
(check-equal? (rpc/json "episode-summary" (hasheq 'id "nope")) "")
(check-equal? (rpc/json "episode-estimate" (hasheq 'id "nope")) "")
(check-equal? (rpc/json "episode-chapters" (hasheq 'id "nope")) '())

;; Bool scalars round-trip; unknown ids are #f, not errors.
(check-equal? (rpc/json "feed-remove" (hasheq 'id "nope")) #f)
(check-equal? (rpc/json "episode-set-done" (hasheq 'id "nope" 'done "1")) #f)
(check-equal? (rpc/json "position-save"
                       (hasheq 'id "nope" 'seconds "12" 'done "0")) #f)
(check-equal? (rpc/json "episode-remove-audio" (hasheq 'id "nope")) #f)
(check-equal? (rpc/json "job-status" (hasheq 'jobId "nope")) "")
(check-equal? (rpc/json "job-cancel" (hasheq 'jobId "nope")) #f)

;; The curated catalog is offline data.
(define catalog (rpc/json "catalog-list" (hasheq)))
(check-true (list? catalog))
(check-true (>= (length catalog) 1))
(check-equal? (length (car catalog)) 8 "catalog row arity")

;; Settings rows: api-key is masked/empty, never a credential.
(define settings (rpc/json "settings-list" (hasheq)))
(check-true (list? settings))
(define ui-lang-row
  (for/or ([r (in-list settings)]) (and (equal? (car r) "ui-lang") r)))
(check-not-false ui-lang-row)
(check-equal? (cadr ui-lang-row) "zh")
(define api-key-row
  (for/or ([r (in-list settings)]) (and (equal? (car r) "api-key") r)))
(check-not-false api-key-row)
(check-not-false (member (cadr api-key-row) '("" "••••••••")) "api-key never in the clear")

;; settings-set round-trips an enum; internal keys are swallowed; unknown
;; keys surface the engine's message through glaze's bad-param channel.
(check-equal? (rpc/json "settings-set" (hasheq 'key "appearance" 'value "dark")) #t)
(define settings2 (rpc/json "settings-list" (hasheq)))
(define appearance-row
  (for/or ([r (in-list settings2)]) (and (equal? (car r) "appearance") r)))
(check-equal? (cadr appearance-row) "dark")
(check-equal? (rpc/json "settings-set"
                       (hasheq 'key "last-update-check" 'value "0")) #t)
(check-exn exn:fail:glaze:bad-param?
           (lambda () (rpc/json "settings-set" (hasheq 'key "no-such-key" 'value "x"))))

;; security-status: JSON string DTO describing the secret backend.
(define sec (string->jsexpr (rpc/json "security-status" (hasheq))))
(check-true (hash-has-key? sec 'backend))
(check-true (hash-has-key? sec 'secure))
(check-true (hash-has-key? sec 'configured))

;; update-state: typed record DTO (camelCase keys, void optionals → null).
(define us (rpc/json "update-state" (hasheq)))
(check-true (hash? us))
(check-equal? (hash-ref us 'phase) "idle")
(check-true (hash-has-key? us 'downloadedPath))
(check-equal? (hash-ref us 'downloadedPath) 'null)

;; open-releases: Void result → null; the open-url event path stays live.
(check-equal? (rpc/json "open-releases" (hasheq)) 'null)

;; Media carrier: host-side audio resolution follows the AGENTS convention
;; (scan audio/ by episode-id prefix); traversal-shaped ids are refused.
(define audio-dir-path (build-path root "audio"))
(make-directory* audio-dir-path)
(define fake-id "abcdef0123456789abcdef0123456789abcdef01")
(call-with-output-file (build-path audio-dir-path (string-append fake-id ".mp3"))
  (lambda (out) (write-bytes (make-bytes 2048 7) out)))
(define resolved (audio-file-for fake-id))
(check-true (path? resolved))
(check-equal? (path->string resolved)
              (path->string (build-path audio-dir-path (string-append fake-id ".mp3"))))
(check-false (audio-file-for "no-such-id"))
(check-exn exn:fail:glaze:bad-param?
           (lambda () (audio-file-for "../escape")))
(check-exn exn:fail:glaze:bad-param?
           (lambda () (audio-file-for "a/b")))

;; Tray labels read the i18n single source (additive host keys).
(check-equal? (tr "zh" 'tray-show) "显示 PodLens")
(check-equal? (tr "en" 'tray-quit) "Quit PodLens")
)

(displayln "adapter contract test: all checks passed")