#lang racket/base

;; Update-channel regression tests — all offline. The trust chain signs a
;; throwaway Ed25519 keypair in-process through the pure Racket ed25519
;; package (the same verifier glaze/update ships, so installed apps need no
;; developer toolchain); the signed wrapper is assembled by hand in the
;; schema-1 format glaze reads. Download coverage runs against a loopback
;; HTTPS server (Racket TLS + an openssl-generated self-signed certificate
;; trusted via SSL_CERT_FILE) standing in for the release CDN; it skips with
;; a reason when no openssl exists to mint the certificate. The live check
;; path is pointed at a closed loopback port so a call-shape regression (an
;; illegal keyword, as shipped in payback v1.4.1–v1.6.2) fails the suite
;; instead of every user's check-for-update.

(require crypto
         crypto/libcrypto
         (prefix-in pure: ed25519)
         glaze/signing
         glaze/update
         json
         rackunit
         net/base64
         openssl
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         racket/tcp
         (file "../racket/update.rkt"))

;; Pin the libcrypto factory: datum->pk-key's SPKI reader lives there, and
;; merely requiring the module does not register it in crypto-factories.
(crypto-factories (list libcrypto-factory))

(define (file-sha256-hex path) (sha256-file path))

(define (base64-text b) (bytes->string/utf-8 (base64-encode b #"")))

(define spki-prefix
  (bytes-append (bytes #x30 #x2a #x30 #x05 #x06 #x03 #x2b #x65 #x70)
                (bytes #x03 #x21 #x00)))

;; glaze's verifier reads the key from a path (PEM or 44-byte DER file).
(define (pem-of raw)
  (string-append "-----BEGIN PUBLIC KEY-----\n"
                 (bytes->string/utf-8
                  (base64-encode (bytes-append spki-prefix raw) #"\n"))
                 "-----END PUBLIC KEY-----\n"))

;; ---- configuration and identity -------------------------------------------

(test-case "update-configured? accepts the embedded key"
  (check-true (update-configured?)))


(define-runtime-path repository-root "..")

(test-case "canonical update endpoints and fail-closed release contract"
  (define canonical "https://github.com/turlamai/podlens")
  (check-equal? default-update-base-url
                (string-append canonical "/releases/latest/download"))
  (check-equal? releases-page
                (string-append canonical "/releases/latest"))
  (check-equal? (manifest-url)
                (string-append canonical "/releases/latest/download/update-manifest.json"))
  (define workflow
    (file->string (build-path repository-root ".github" "workflows" "release.yml")))
  (define signer
    (file->string (build-path repository-root "scripts" "make-update-manifest.sh")))
  (check-true (string-contains? workflow "Require Ed25519 update signing key"))
  (check-true (string-contains? workflow "test -s dist/update-manifest.json"))
  (check-false (string-contains? workflow "HAS_UPDATE_KEY"))
  (check-true (string-contains? signer
                                "https://github.com/turlamai/podlens/releases/download/"))
  (check-false (string-contains? signer "turinglambdaai/podlens")))


(test-case "identity symbols match release manifests"
  (check-equal? (platform-symbol)
                (case (system-type 'os)
                  [(macosx) 'macos] [(windows) 'windows] [else 'linux]))
  (check-not-false (memq (architecture-symbol) '(arm64 x64))))

(test-case "linux aarch64 maps to the arm64 feed symbol"
  ;; Racket's (system-type 'arch) is 'aarch64 on Linux arm64 and 'arm64 on
  ;; macOS arm64; the feed only carries arm64/x64, so both must select arm64
  ;; (regression: qualification run 44943194176 arm64 downloaded x64).
  (check-equal? (arch-symbol 'aarch64) 'arm64)
  (check-equal? (arch-symbol 'arm64) 'arm64)
  (check-equal? (arch-symbol 'x86_64) 'x64)
  (check-equal? (arch-symbol 'i386) 'x64))

(test-case "embedded public key decodes as SPKI DER"
  ;; update-public-key-b64 is the raw 32 bytes; the SPKI prefix turns it
  ;; into the DER blob release-side tooling parses (the same construction
  ;; glaze's ed25519-public reader applies).
  (define raw (base64-decode (string->bytes/utf-8 update-public-key-b64)))
  (check-equal? (bytes-length raw) 32)
  (check-true
   (pk-key?
    (datum->pk-key (bytes-append spki-prefix raw)
                   'SubjectPublicKeyInfo))))

;; ---- signed-wrapper trust chain (in-process Ed25519) -----------------------

(test-case "signed manifest verifies and selects updates"
  ;; throwaway keypair; the wrapper is the schema-1 format glaze reads:
  ;; base64 payload + ed25519 signature object with key_id.
  (define kp (pure:generate-keypair))
  (define pub (pure:keypair-public kp))
  (define pub-pem (pem-of pub))
  (define secret (pure:keypair-secret kp))

  (define tmp (make-temporary-file "podlens-updater-~a" 'directory))
  (define pub-path (build-path tmp "pub.pem"))
  (display-to-file pub-pem pub-path #:exists 'truncate/replace)
  (define manifest-path (build-path tmp "update-manifest.json"))
  ;; the artifact must match the RUNNING platform/architecture — select-update
  ;; filters on the host identity, so a hardcoded macos/arm64 entry fails the
  ;; check on every other platform (the all-three-CI red)
  (define artifact
    (update-artifact (platform-symbol) (architecture-symbol)
                     "https://example.invalid/podlens-1.4.0-macos-arm64.zip"
                     "0000000000000000000000000000000000000000000000000000000000000000"
                     123456789 'zip '() #f))
  (define manifest
    (update-manifest app-identifier "1.4.0" 9 'stable
                     "2026-10-09T00:00:00Z" "0.0.0" #f #t 100
                     (list artifact)))
  (define payload (update-manifest->payload-bytes manifest))
  (define wrapper
    (hasheq 'schema 1
            'payload (base64-text payload)
            'signature (hasheq 'algorithm "ed25519"
                               'key_id update-key-id
                               'value (base64-text (pure:sign payload secret)))))
  (call-with-output-file manifest-path
    (lambda (o) (write-json wrapper o))
    #:exists 'truncate/replace)

  ;; tamper check first: a modified payload must fail verification
  (define signed-bytes (file->bytes manifest-path))
  (define tampered
    (bytes-append (subbytes signed-bytes 0 40)
                  #"9"
                  (subbytes signed-bytes 41)))
  (check-exn exn:fail?
             (lambda ()
               (verify-signed-update-manifest (open-input-bytes tampered)
                                              pub-path
                                              #:key-id update-key-id)))

  (define verified
    (verify-signed-update-manifest (open-input-bytes signed-bytes)
                                   pub-path
                                   #:key-id update-key-id))
  (check-equal? (update-manifest-version verified) "1.4.0")

  ;; selection policy: newer version for this app/channel/platform wins
  (define config
    (updater-config app-identifier app-version 'stable
                    (platform-symbol) (architecture-symbol)
                    pub-path
                    update-key-id 42 (* 800 1024 1024)))
  (define (selectable manifest)
    (update-candidate? (select-update config manifest)))
  (check-true (selectable verified))
  (check-false (selectable (struct-copy update-manifest verified
                                        [version app-version]))
               "same version: nothing to do")
  (check-false (selectable (struct-copy update-manifest verified
                                        [channel 'beta]))
               "other channel is invisible")
  (check-false (selectable (struct-copy update-manifest verified
                                        [rollout 42]))
               "bucket 42 is excluded when rollout is 42")
  (check-true (selectable (struct-copy update-manifest verified
                                       [rollout 43])))
  (check-exn exn:fail?
             (lambda ()
               (select-update
                config
                (struct-copy update-manifest verified
                             [application-id "com.other.app"])))
             "other application identity must fail loudly")
  (with-handlers ([exn:fail? void])
    (delete-directory/files tmp)))

;; ---- live check path fails on network grounds, never on call shape --------

(test-case "perform-check! against a closed port reports a network error"
  (define result
    (parameterize ([current-update-base-url "https://127.0.0.1:1"])
      (perform-check!)))
  (check-equal? (hash-ref result 'status) "error")
  (check-false
   (string-contains? (hash-ref result 'message "")
                     "given keyword")
   "check must not fail on its own call shape (illegal keyword regression)")
  (check-equal? (hash-ref (update-state-snapshot) 'phase) "error")
  (reset-update-state!))

;; ---- state machine ----------------------------------------------------------

(test-case "update state starts idle and resets cleanly"
  (reset-update-state!)
  (define s (update-state-snapshot))
  (check-equal? (hash-ref s 'phase) "idle")
  (check-equal? (hash-ref s 'percent) 0)
  (check-false (hash-ref s 'message))
  (check-false (hash-ref s 'downloadedPath)))

(test-case "set-update-error! surfaces through the snapshot"
  (reset-update-state!)
  (set-update-error! "boom")
  (check-equal? (hash-ref (update-state-snapshot) 'phase) "error")
  (check-equal? (hash-ref (update-state-snapshot) 'message) "boom")
  (reset-update-state!))

(test-case "start-download! refuses to run without a candidate"
  (reset-update-state!)
  (set-candidate! #f)
  (check-exn exn:fail?
             (lambda ()
               (start-download! (make-temporary-file "podlens-dl~a" 'directory)))))

(test-case "destination-path lands in <data-dir>/updates/ with a self-describing name"
  (define tmp (make-temporary-file "podlens-dl~a" 'directory))
  (define candidate
    (update-candidate
     (update-manifest app-identifier "9.9.9" 99 'stable
                      "2026-10-13T00:00:00Z" "0.0.0" #f #t 100
                      (list (update-artifact 'macos 'arm64
                                             "https://example.invalid/x.zip"
                                             "00" 1 'zip '() #f)))
     (update-artifact 'macos 'arm64
                      "https://example.invalid/x.zip"
                      "00" 1 'zip '() #f)))
  (check-equal?
   (path->string (destination-path tmp candidate))
   (path->string
    (build-path tmp "updates" (string-append app-display-name "-9.9.9"
                                             (payload-extension))))))

;; ---- download against a loopback HTTPS CDN ---------------------------------
;; glaze's downloader refuses non-HTTPS artifact URLs, so the stand-in CDN
;; speaks TLS: a self-signed localhost certificate (openssl CLI, any vendor)
;; trusted process-wide via SSL_CERT_FILE, served by Racket's own TLS
;; listener (binary-safe on every platform, unlike openssl s_server -WWW).

(define artifact-payload (make-bytes 3000 7))

(define cdn-work-dir (make-temporary-file "podlens-cdn~a" 'directory))
(define cdn-cert (build-path cdn-work-dir "cdn.pem"))
(define cdn-key (build-path cdn-work-dir "cdn.key"))
(define cdn-cnf (build-path cdn-work-dir "san.cnf"))

(define openssl-bin (find-executable-path "openssl"))
(define cdn-ready?
  (and openssl-bin
       (begin
         (call-with-output-file cdn-cnf
           (lambda (o)
             (display "[req]\ndistinguished_name=dn\nx509_extensions=v3\n[dn]\nCN=localhost\n[v3]\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n" o))
           #:exists 'truncate/replace)
         (zero? (system*/exit-code openssl-bin
                                   "req" "-x509" "-newkey" "rsa:2048" "-nodes"
                                   "-keyout" (path->string cdn-key)
                                   "-out" (path->string cdn-cert)
                                   "-days" "1"
                                   "-subj" "/CN=localhost"
                                   "-config" (path->string cdn-cnf))))))

(define-values (artifact-port artifact-listener artifact-server-thread)
  (if cdn-ready?
      (let loop ([port 18900])
        (with-handlers ([exn:fail:network? (lambda (_) (loop (add1 port)))])
          ;; 'tls maps to a pre-1.2-only range that OpenSSL 3 refuses
          ;; ("no protocols available"); 'secure negotiates TLS 1.2/1.3.
          (define cdn-ctx (ssl-make-server-context 'secure))
          (ssl-load-certificate-chain! cdn-ctx cdn-cert)
          (ssl-load-private-key! cdn-ctx cdn-key)
          (define listener (ssl-listen port 4 #f "127.0.0.1" cdn-ctx))
          (define server
            (thread
             (lambda ()
               (with-handlers ([exn:fail? void])
                 (let accept-loop ()
                   (with-handlers ([exn:fail? void])
                     (define-values (in out) (ssl-accept listener))
                     (thread
                      (lambda ()
                        (with-handlers ([exn:fail? void])
                          (read-line in 'any)
                          (let drain ()
                            (define line (read-line in 'any))
                            (unless (or (eof-object? line) (equal? line "")) (drain)))
                          (fprintf out
                                   "HTTP/1.1 200 OK\r\nContent-Length: ~a\r\n"
                                   (bytes-length artifact-payload))
                          (fprintf out "Connection: close\r\nContent-Type: application/zip\r\n\r\n")
                          (write-bytes artifact-payload out)
                          (flush-output out)
                          (close-output-port out)
                          (close-input-port in)))))
                   (accept-loop))))))
          (values port listener server)))
      (values #f #f #f)))

(when cdn-ready?
  ;; Trust only the test certificate for this process.
  (putenv "SSL_CERT_FILE" (path->string cdn-cert))
  (putenv "SSL_CERT_DIR" (path->string cdn-work-dir)))

(define artifact-work-dir (make-temporary-file "podlens-dl~a" 'directory))
(define artifact-url
  (and artifact-port
       (format "https://localhost:~a/podlens-9.9.9-windows-x64.zip" artifact-port)))
(define artifact-sha
  (let ([probe (build-path artifact-work-dir "probe.bin")])
    (display-to-file artifact-payload probe #:exists 'replace #:mode 'binary)
    (file-sha256-hex probe)))

(define (wait-for-terminal-state!)
  ;; phase and message are written as two separate state updates, so an
  ;; error landing means the message may still be one write behind — wait
  ;; for the pair, not just the phase.
  (let wait ([n 400])
    (define s (update-state-snapshot))
    (define phase (hash-ref s 'phase))
    (define settled?
      (or (equal? phase "downloaded")
          (and (equal? phase "error") (hash-ref s 'message #f))))
    (unless settled?
      (when (> n 0)
        (sleep 0.05)
        (wait (sub1 n))))))

(if (not cdn-ready?)
    (displayln "HTTPS download flow skipped: no openssl to mint a localhost certificate")
    (begin
      (test-case "artifact download verifies and lands at the destination"
        (reset-update-state!)
        (set-candidate!
         (update-candidate
          (update-manifest app-identifier "9.9.9" 99 'stable
                           "2026-10-13T00:00:00Z" "0.0.0" #f #t 100
                           (list (update-artifact 'macos 'arm64 artifact-url
                                                  artifact-sha
                                                  (bytes-length artifact-payload)
                                                  'zip '() #f)))
          (update-artifact 'macos 'arm64 artifact-url
                           artifact-sha
                           (bytes-length artifact-payload)
                           'zip '() #f)))
        ;; Windows' default TLS trust source is the win32 ROOT store, which
        ;; ignores SSL_CERT_FILE; trust the test CA explicitly for the
        ;; download thread (threads inherit the parameterization).
        (parameterize ([ssl-default-verify-sources (list cdn-cert)])
          (start-download! artifact-work-dir))
        (wait-for-terminal-state!)
        (define s (update-state-snapshot))
        (check-equal? (hash-ref s 'phase) "downloaded"
                      (format "state message: ~a" (hash-ref s 'message "")))
        (check-equal? (hash-ref s 'percent) 100)
        (define path (hash-ref s 'downloadedPath))
        (check-true (and path (file-exists? path)))
        (check-equal? (file->bytes path) artifact-payload)
        (check-equal? (file-sha256-hex path) artifact-sha))

      (test-case "checksum mismatch fails the download and leaves no artifact"
        (define destination
          (build-path artifact-work-dir "updates" "podlens-9.9.9-windows-x64.zip"))
        (when (file-exists? destination) (delete-file destination))
        (reset-update-state!)
        (set-candidate!
         (update-candidate
          (update-manifest app-identifier "9.9.9" 99 'stable
                           "2026-10-13T00:00:00Z" "0.0.0" #f #t 100
                           (list (update-artifact 'macos 'arm64 artifact-url
                                                  (string-append artifact-sha "0000")
                                                  (bytes-length artifact-payload)
                                                  'zip '() #f)))
          (update-artifact 'macos 'arm64 artifact-url
                           (string-append artifact-sha "0000")
                           (bytes-length artifact-payload)
                           'zip '() #f)))
        ;; Windows' default TLS trust source is the win32 ROOT store, which
        ;; ignores SSL_CERT_FILE; trust the test CA explicitly for the
        ;; download thread (threads inherit the parameterization).
        (parameterize ([ssl-default-verify-sources (list cdn-cert)])
          (start-download! artifact-work-dir))
        (wait-for-terminal-state!)
        (define s (update-state-snapshot))
        (check-equal? (hash-ref s 'phase) "error")
        (check-true
         (string-contains? (string-downcase (hash-ref s 'message "")) "sha")
         "the digest failure must surface by name (glaze: SHA-256 mismatch)")
        (check-false (file-exists? destination))
        (check-false
         (file-exists?
          (path-add-extension destination #".partial"))))

      (test-case "size mismatch fails the download"
        (reset-update-state!)
        (set-candidate!
         (update-candidate
          (update-manifest app-identifier "9.9.9" 99 'stable
                           "2026-10-13T00:00:00Z" "0.0.0" #f #t 100
                           (list (update-artifact 'macos 'arm64 artifact-url
                                                  artifact-sha
                                                  (add1 (bytes-length artifact-payload))
                                                  'zip '() #f)))
          (update-artifact 'macos 'arm64 artifact-url
                           artifact-sha
                           (add1 (bytes-length artifact-payload))
                           'zip '() #f)))
        ;; Windows' default TLS trust source is the win32 ROOT store, which
        ;; ignores SSL_CERT_FILE; trust the test CA explicitly for the
        ;; download thread (threads inherit the parameterization).
        (parameterize ([ssl-default-verify-sources (list cdn-cert)])
          (start-download! artifact-work-dir))
        (wait-for-terminal-state!)
        (check-equal? (hash-ref (update-state-snapshot) 'phase) "error")
        (check-true (string-contains? (hash-ref (update-state-snapshot) 'message "") "size")))))

(when artifact-server-thread (kill-thread artifact-server-thread))
(when artifact-listener (ssl-close artifact-listener))
(reset-update-state!)
(set-candidate! #f)