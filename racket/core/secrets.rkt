#lang racket/base

;; Platform secret storage for BYOK credentials.
;;
;; config.json never carries the API key in the clear after migration: it
;; keeps an opaque `api-key-ref` plus the backend that owns the secret.
;; The secret itself lives in the OS vault when one is available:
;;
;;   macOS    Keychain (security(1), hex-encoded so argv carries no secret)
;;   Windows  DPAPI CurrentUser scope (encrypted blob under secrets/)
;;   Linux    Secret Service via secret-tool(1) when a session bus is present
;;   fallback a 0600 file under secrets/ — reported honestly as `file`, never
;;            presented as "secure storage"
;;
;; Every function degrades instead of raising: a locked vault must not take
;; the whole app (or a CLI command) down. The caller decides how to explain
;; an unavailable secret.

(require racket/file
         racket/port
         racket/string
         racket/system
         "paths.rkt"
         "util.rkt")

(provide secret-backend
         secret-backend-override
         secret-backend-label
         secret-backend-secure?
         secret-ref
         secret-store!
         secret-load
         secret-delete!
         secret-value-mask
         secret-count)

;; Tests and headless automation pin a backend instead of touching a real
;; keychain. PODLENS_SECRET_BACKEND does the same for shipped builds.
(define secret-backend-override (make-parameter #f))

(define secret-value-mask "••••••••")

(define (secret-backend)
  (or (secret-backend-override)
      (let ([env (getenv "PODLENS_SECRET_BACKEND")])
        (and env
             (non-empty-string? (string-trim env))
             (string->symbol (string-downcase (string-trim env)))))
      (platform-default-backend)))

(define (platform-default-backend)
  (case (system-type 'os)
    [(macosx) (if (find-executable-path "security") 'keychain 'file)]
    [(windows) (if (find-executable-path "powershell.exe") 'dpapi 'file)]
    [else (if (find-executable-path "secret-tool") 'secret-service 'file)]))

(define (secret-backend-secure? backend)
  (memq backend '(keychain dpapi secret-service)))

(define (secret-backend-label backend)
  (case backend
    [(keychain) "macOS Keychain"]
    [(dpapi) "Windows DPAPI"]
    [(secret-service) "Secret Service"]
    [else "a local 0600 file"]))

;; An opaque handle, not a credential. Collisions are practically impossible
;; and a collision would only orphan one stored secret.
(define (secret-ref)
  (string-append "key-" (stable-id (format "~a-~a-~a"
                                           (current-inexact-milliseconds)
                                           (random 1000000000)
                                           (current-process-milliseconds)))))

;; ---- process helpers -------------------------------------------------------

;; Run a command with optional stdin and return (values exit-code stdout stderr).
;; The output buffers stay small (vault tools answer in bytes), so reading
;; after the process exits cannot deadlock on a full pipe.
(define (run-command exe args [stdin-text #f])
  (define out (open-output-string))
  (define err (open-output-string))
  (define code
    (parameterize ([current-output-port out]
                   [current-error-port err]
                   ;; always hand the child a closed stdin unless we feed it:
                   ;; secret-tool and security(1) otherwise wait for EOF
                   [current-input-port (open-input-string (or stdin-text ""))])
      (apply system* exe args)))
  (values code (get-output-string out) (get-output-string err)))

(define (ok-code? code) (or (eq? code #t) (and (number? code) (zero? code))))

(define (secret-debug msg)
  (when (getenv "PODLENS_SECRET_DEBUG")
    (eprintf "podlens-secret: ~a\n" msg)))

(define (first-line s)
  (string-trim (car (string-split (or s "") "\n"))))

;; ---- file fallback ---------------------------------------------------------

(define (secret-file-path ref suffix)
  (build-path (secrets-dir) (format "~a.~a" ref suffix)))

(define (restrict-permissions! path)
  (with-handlers ([exn:fail? void])
    (file-or-directory-permissions path #o600)))

(define (write-private-file! path text)
  (make-directory* (secrets-dir))
  (with-handlers ([exn:fail? void])
    (file-or-directory-permissions (secrets-dir) #o700))
  (define tmp (string-append (path->string path) ".tmp"))
  (call-with-output-file tmp
    (lambda (out) (write-string text out))
    #:exists 'truncate)
  (restrict-permissions! tmp)
  (rename-file-or-directory tmp path #t)
  #t)

(define (file-store! ref value)
  (write-private-file! (secret-file-path ref "secret") value))

(define (file-load ref)
  (define path (secret-file-path ref "secret"))
  (and (file-exists? path)
       (let ([v (with-handlers ([exn:fail? (lambda (_) #f)])
                  (file->string path))])
         (and (string? v) (non-empty-string? v) v))))

(define (file-delete! ref)
  (define path (secret-file-path ref "secret"))
  (when (file-exists? path)
    (with-handlers ([exn:fail? void]) (delete-file path)))
  (void))

;; ---- macOS Keychain --------------------------------------------------------

;; `security -w` expects and returns the password as text. Hex keeps spaces,
;; quotes and newlines out of argv and out of the tool's own parsing.
(define (keychain-store! ref value)
  (define security (find-executable-path "security"))
  (and security
       ;; `security -i` reads the command from stdin, so the encoded secret
       ;; never appears in the process argument list.
       (let* ([command (format "add-generic-password -U -s \"PodLens\" -a \"~a\" -w \"~a\"\n"
                               ref
                               (bytes->hex (string->bytes/utf-8 value)))])
         (let-values ([(code out err) (run-command security (list "-i") command)])
           (secret-debug (format "keychain store code=~a out=~a err=~a" code out err))
           (ok-code? code)))))

(define (keychain-load ref)
  (define security (find-executable-path "security"))
  (and security
       (let-values ([(code out _err)
                     (run-command security
                                  (list "find-generic-password"
                                        "-s" "PodLens" "-a" ref "-w"))])
         (and (ok-code? code)
              (let ([hex (first-line out)])
                (and (non-empty-string? hex)
                     (let ([bytes (hex->bytes hex)])
                       (and bytes (bytes->string/utf-8 bytes)))))))))

(define (keychain-delete! ref)
  (define security (find-executable-path "security"))
  (when security
    (run-command security (list "-i")
                 (format "delete-generic-password -s \"PodLens\" -a \"~a\"\n" ref)))
  (void))

;; ---- Windows DPAPI ---------------------------------------------------------

(define protect-script
  (string-append
   "$ErrorActionPreference='Stop';"
   "Add-Type -AssemblyName System.Security;"
   "$s=[Console]::In.ReadToEnd();"
   "$b=[Text.Encoding]::UTF8.GetBytes($s);"
   "$e=[Security.Cryptography.ProtectedData]::Protect($b,$null,'CurrentUser');"
   "[Console]::Out.Write([Convert]::ToBase64String($e))"))

(define unprotect-script
  (string-append
   "$ErrorActionPreference='Stop';"
   "Add-Type -AssemblyName System.Security;"
   "$s=[Console]::In.ReadToEnd();"
   "$b=[Convert]::FromBase64String($s);"
   "$p=[Security.Cryptography.ProtectedData]::Unprotect($b,$null,'CurrentUser');"
   "[Console]::Out.Write([Text.Encoding]::UTF8.GetString($p))"))

(define (powershell args stdin-text)
  (define exe (find-executable-path "powershell.exe"))
  (unless exe
    (error 'powershell "powershell.exe is not available"))
  (run-command exe
               (append (list "-NoProfile" "-NonInteractive" "-ExecutionPolicy" "Bypass")
                       args)
               stdin-text))

(define (dpapi-store! ref value)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (define-values (code out _err)
      (powershell (list "-Command" protect-script) value))
    (define blob (string-trim out))
    (and (ok-code? code)
         (non-empty-string? blob)
         (write-private-file! (secret-file-path ref "dpapi") blob))))

(define (dpapi-load ref)
  (define path (secret-file-path ref "dpapi"))
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (define blob (string-trim (file->string path)))
         (and (non-empty-string? blob)
              (let-values ([(code out _err)
                            (powershell (list "-Command" unprotect-script) blob)])
                (and (ok-code? code)
                     (non-empty-string? out)
                     out))))))

(define (dpapi-delete! ref)
  (define path (secret-file-path ref "dpapi"))
  (when (file-exists? path)
    (with-handlers ([exn:fail? void]) (delete-file path)))
  (void))

;; ---- Linux Secret Service --------------------------------------------------

(define (secret-service-store! ref value)
  (define tool (find-executable-path "secret-tool"))
  (and tool
       (let-values ([(code _out _err)
                     (run-command tool
                                  (list "store" "--label=PodLens API key"
                                        "service" "podlens" "account" ref)
                                  value)])
         (ok-code? code))))

(define (secret-service-load ref)
  (define tool (find-executable-path "secret-tool"))
  (and tool
       (let-values ([(code out _err)
                     (run-command tool
                                  (list "lookup" "service" "podlens" "account" ref))])
         (and (ok-code? code)
              (let ([v (string-trim out)])
                (and (non-empty-string? v) v))))))

(define (secret-service-delete! ref)
  (define tool (find-executable-path "secret-tool"))
  (when tool
    (run-command tool (list "clear" "service" "podlens" "account" ref)))
  (void))

;; ---- public surface --------------------------------------------------------

;; Returns the backend that actually holds the value. A vault failure falls
;; back to the 0600 file so a user is never silently locked out; the return
;; value lets the UI say which one is in force.
(define (secret-store! ref value)
  (define preferred (secret-backend))
  (secret-debug (format "preferred backend=~a security=~a" preferred (find-executable-path "security")))
  (define stored?
    (case preferred
      [(keychain) (keychain-store! ref value)]
      [(dpapi) (dpapi-store! ref value)]
      [(secret-service) (secret-service-store! ref value)]
      [else #f]))
  (if stored?
      preferred
      (begin
        (file-store! ref value)
        'file)))

(define (secret-load ref [backend #f])
  (define candidates
    (if backend
        (list backend 'file)
        (list (secret-backend) 'file)))
  (for/first ([b (in-list candidates)]
              #:when (memq b '(keychain dpapi secret-service file))
              #:do [(define value
                      (with-handlers ([exn:fail? (lambda (_) #f)])
                        (case b
                          [(keychain) (keychain-load ref)]
                          [(dpapi) (dpapi-load ref)]
                          [(secret-service) (secret-service-load ref)]
                          [else (file-load ref)])))]
              #:when (and value (non-empty-string? value)))
    value))

(define (secret-delete! ref [backend #f])
  (with-handlers ([exn:fail? void])
    (case (or backend (secret-backend))
      [(keychain) (keychain-delete! ref)]
      [(dpapi) (dpapi-delete! ref)]
      [(secret-service) (secret-service-delete! ref)]
      [else (void)]))
  ;; A migration may have left a fallback file even when the preferred
  ;; backend is a vault; remove both so "remove key" really removes it.
  (file-delete! ref)
  (void))

;; How many secret files exist — used by doctor/diagnostics without ever
;; reading a value.
(define (secret-count)
  (define dir (secrets-dir))
  (if (directory-exists? dir)
      (length (directory-list dir))
      0))
