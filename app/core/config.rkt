#lang racket/base

;; User settings. JSON on disk so a user (or an agent driving the CLI) can
;; inspect and edit it directly; every key has a validated default so a
;; half-written file never breaks startup.
;;
;; The API key is BYOK and therefore there is exactly one credential in the
;; schema. It never lives in config.json in the clear:
;;
;;   config.json   api-key-ref = "key-…", api-key-store = "keychain"
;;   vault         the secret, addressed by that opaque ref
;;   legacy        a plaintext api-key from ≤0.5.x is migrated on first open
;;
;; `api-key` stays a readable/writable setting: reads resolve the vault,
;; writes migrate into it. Hosts only ever receive the mask, and the CLI
;; masks its echo as well, so diagnostics and shell history never carry the
;; credential.

(require json
         racket/file
         racket/format
         racket/list
         racket/string
         "paths.rkt"
         "secrets.rkt"
         "util.rkt")

(provide config-manager?
         make-config-manager
         config-get
         config-set!
         config-reset!
         config-keys
         config-user-keys
         config-descriptions
         config-description
         config-api-configured?
         config-secret-backend
         config-secret-storage-label
         config-bool
         config-number)

;; key -> (list default kind description)
;; kind is one of string secret boolean number enum-lang internal;
;; internal keys are managed by the app (update throttling, secret plumbing)
;; and never surface through the settings RPC surface
(define schema
  (list
   (list 'api-base "https://api.openai.com/v1" 'string
         "OpenAI-compatible API base URL (…/v1)")
   (list 'api-key "" 'secret
         "API key (BYOK; stored in the OS vault, never synced)")
   (list 'chat-model "gpt-4o-mini" 'string
         "Chat model for translation and summary")
   (list 'asr-model "whisper-1" 'string
         "Speech-to-text model (provider must expose /audio/transcriptions)")
   (list 'target-lang "zh" 'enum-lang
         "Translation target language (zh / en)")
   (list 'ui-lang "zh" 'enum-lang
         "Interface language for CLI output (zh / en)")
   (list 'asr-chunk-seconds 600 'number
         "Audio chunk length in seconds when ffmpeg splitting is needed")
   (list 'max-transcript-chars 40000 'number
         "Transcript characters sent to the summarizer")
   (list 'check-updates-enabled "true" 'boolean
         "Automatically check for updates (silent, throttled)")
   (list 'last-update-check 0 'internal
         "Unix seconds of the last automatic update check (internal)")
   (list 'search-limit 25 'number
         "Max results per discovery search (iTunes Search API)")
   (list 'api-key-ref "" 'internal
         "Opaque handle for the vault-stored API key (internal)")
   (list 'api-key-store "" 'internal
         "Secret backend that owns api-key-ref (internal)")))

(define known-keys (map car schema))

(define (schema-entry key)
  (findf (lambda (e) (eq? (car e) key)) schema))

(define (default-value key)
  (cadr (schema-entry key)))

(define (config-descriptions)
  (for/list ([e (in-list schema)])
    (list (symbol->string (car e)) (list-ref e 3))))

(define (config-description key)
  (define k (if (symbol? key) key (string->symbol key)))
  (define entry (schema-entry k))
  (and entry (list-ref entry 3)))

(struct config-manager (path sem))

(define (make-config-manager [path (config-path)])
  (define mgr (config-manager path (make-semaphore 1)))
  (migrate-legacy-secret! mgr)
  mgr)

(define (config-keys) (map symbol->string known-keys))

;; Keys the settings surface shows and saves. Internal keys (update
;; bookkeeping and the secret ref/store pair) are excluded: hosts echo every
;; listed row back on save, and echoing a value like last-update-check=0
;; through validation used to surface a spurious contract error right after
;; a successful save.
(define (config-user-keys)
  (for/list ([e (in-list schema)] #:unless (eq? (list-ref e 2) 'internal))
    (symbol->string (car e))))

;; ---- validation ----------------------------------------------------------

(define (validate key value)
  (define entry (schema-entry key))
  (unless entry
    (raise-argument-error 'config-set! (format "one of ~a" (string-join (map symbol->string known-keys) ", ")) key))
  (define kind (list-ref entry 2))
  (case kind
    [(string secret)
     (unless (string? value)
       (raise-argument-error 'config-set! "string?" value))
     value]
    [(enum-lang)
     (define v (string-trim (if (string? value) value (format "~a" value))))
     (unless (member v '("zh" "en"))
       (raise-argument-error 'config-set! "\"zh\" or \"en\"" value))
     v]
    [(boolean)
     (define v (string-trim (if (string? value) value (format "~a" value))))
     (cond
       [(member v '("true" "1" "yes")) "true"]
       [(member v '("false" "0" "no")) "false"]
       [else (raise-argument-error 'config-set! "boolean string" value)])]
    [(number)
     (define n (string->number (string-trim (format "~a" value))))
     ;; nonnegative: a declared default of 0 must satisfy its own contract
     (unless (and n (exact-nonnegative-integer? n))
       (raise-argument-error 'config-set! "nonnegative integer" value))
     n]
    ;; internal keys are written by the app itself (epoch stamps); host
    ;; settings loops may also echo them back, which is a no-op
    [(internal)
     (string-trim (format "~a" value))]))

;; ---- storage ---------------------------------------------------------------

;; Callers that already hold the manager lock use the -unlocked variants;
;; the semaphore is not reentrant.
(define (load-hash-unlocked mgr)
  (define v (read-json-file (config-manager-path mgr)))
  (if (hash? v) (make-hash (hash->list v)) (make-hasheq)))

(define (load-hash mgr)
  (with-lock
   (config-manager-sem mgr)
   (lambda () (load-hash-unlocked mgr))))

(define (save-hash-unlocked! mgr h)
  (ensure-data-dir!)
  (write-json-file! (config-manager-path mgr) h))

(define (save-hash! mgr h)
  (with-lock
   (config-manager-sem mgr)
   (lambda () (save-hash-unlocked! mgr h))))

;; ---- API key -----------------------------------------------------------------

(define (plaintext-key h)
  (define v (hash-ref h 'api-key ""))
  (if (string? v) v ""))

(define (vault-ref h)
  (define ref (hash-ref h 'api-key-ref ""))
  (and (string? ref) (non-empty-string? (string-trim ref)) (string-trim ref)))

(define (vault-backend h)
  (define store (hash-ref h 'api-key-store ""))
  (and (string? store)
       (non-empty-string? (string-trim store))
       (string->symbol (string-trim store))))

(define (resolve-api-key h)
  (define ref (vault-ref h))
  (if ref
      (or (secret-load ref (vault-backend h)) "")
      (plaintext-key h)))

;; ≤0.5.x left the key in config.json. Move it once, then rewrite the file
;; without the plaintext; the ref and its backend are the only trace left.
(define (migrate-legacy-secret! mgr)
  (with-lock
   (config-manager-sem mgr)
   (lambda ()
     (define h (load-hash-unlocked mgr))
     (define legacy (string-trim (plaintext-key h)))
     (when (and (non-empty-string? legacy) (not (vault-ref h)))
       (define ref (secret-ref))
       (define backend (secret-store! ref legacy))
       (hash-remove! h 'api-key)
       (hash-set! h 'api-key-ref ref)
       (hash-set! h 'api-key-store (symbol->string backend))
       (save-hash-unlocked! mgr h)))))

(define (set-api-key! mgr value)
  (define v (string-trim (validate 'api-key value)))
  (with-lock
   (config-manager-sem mgr)
   (lambda ()
     (define h (load-hash-unlocked mgr))
     (define old-ref (vault-ref h))
     (define old-backend (vault-backend h))
     (cond
       [(non-empty-string? v)
        (define ref (secret-ref))
        (define backend (secret-store! ref v))
        ;; Only drop the previous secret after the new one is safely stored.
        (when old-ref (secret-delete! old-ref old-backend))
        (hash-remove! h 'api-key)
        (hash-set! h 'api-key-ref ref)
        (hash-set! h 'api-key-store (symbol->string backend))
        (save-hash-unlocked! mgr h)
        secret-value-mask]
       [else
        (when old-ref (secret-delete! old-ref old-backend))
        (hash-remove! h 'api-key)
        (hash-remove! h 'api-key-ref)
        (hash-remove! h 'api-key-store)
        (save-hash-unlocked! mgr h)
        ""]))))

(define (config-secret-backend mgr)
  (define h (load-hash mgr))
  (or (vault-backend h) (secret-backend)))

(define (config-secret-storage-label mgr)
  (secret-backend-label (config-secret-backend mgr)))

;; ---- public get/set ----------------------------------------------------------

(define (config-get mgr key [default-unset #f])
  (define k (if (symbol? key) key (string->symbol key)))
  (define h (load-hash mgr))
  (cond
    [(eq? k 'api-key) (resolve-api-key h)]
    ;; hash-ref calls a procedure failure-result with no args, lazily
    [else (hash-ref h k (or default-unset (lambda () (default-value k))))]))

;; Reads with defaults applied — the only shape pipeline code may rely on.
(define (config-bool mgr key)
  (equal? (config-get mgr key) "true"))

(define (config-number mgr key)
  (define v (config-get mgr key))
  (if (number? v) v (string->number (format "~a" v))))

(define (config-set! mgr key value)
  (define k (if (symbol? key) key (string->symbol key)))
  (cond
    [(eq? k 'api-key) (set-api-key! mgr value)]
    [else
     (define v (validate k value))
     (define h (load-hash mgr))
     (hash-set! h k v)
     (save-hash! mgr h)
     v]))

(define (config-reset! mgr key)
  (define k (if (symbol? key) key (string->symbol key)))
  (cond
    [(eq? k 'api-key) (set-api-key! mgr "")]
    [else
     (define h (load-hash mgr))
     (hash-remove! h k)
     (save-hash! mgr h)
     (default-value k)]))

(define (config-api-configured? mgr)
  (define key (config-get mgr 'api-key))
  (and (string? key) (non-empty-string? (string-trim key))))
