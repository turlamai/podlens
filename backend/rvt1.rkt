#lang racket/base

;; In-process RVT1 transport (#63): the glaze adapter drives the
;; production engine backend over real frames on a pipe pair — the same
;; wire the native hosts used and racket/tests/backend-wire-test.rkt
;; exercises. No engine code is duplicated or modified.
;;
;; One reader thread owns the client input port (a partial frame never
;; trips a timeout); calls serialize on a semaphore and wait on a
;; per-request async channel. Event frames pump into a handler callback
;; (the engine declares `changed` but does not emit it today; the bus
;; wiring keeps the path live for when it does).

(require racket/async-channel
         racket/match
         rivet/backend
         rivet/protocol)

(provide start-rvt1!
         rvt1-call
         set-event-handler!
         rvt1-alive?)

(define server-thread (box #f))
(define reader-thread (box #f))
(define client-out-box (box #f))
(define pending (make-hash))          ; id -> async channel
(define pending-lock (make-semaphore 1))
(define call-lock (make-semaphore 1))
(define next-id 0)
(define event-handler (box void))

(define (set-event-handler! proc)
  (set-box! event-handler proc))

(define (rvt1-alive?)
  (define t (unbox server-thread))
  (and t (not (thread-dead? t))))

;; Start the engine backend on a pipe pair and complete the RVT1 hello
;; handshake. The production backend module must already be loaded by the
;; caller (static require in backend/main.rkt so raco exe embeds it; the
;; wire test dynamic-requires it from the source tree). Registration
;; happens at require time, exactly as in the embedded runtime.
;;
;; start-proc is the engine's lifecycle entry (backend `start`): it
;; initializes the config/job managers and library before serving frames.
;; The raw `serve` default only fits engines that initialize at load time.
(define (start-rvt1! [start-proc serve])
  (when (unbox server-thread)
    (error 'start-rvt1! "already started"))
  (define-values (server-in client-out) (make-pipe))
  (define-values (client-in server-out) (make-pipe))
  (set-box! client-out-box client-out)
  (define srv (thread (lambda () (start-proc server-in server-out))))
  (set-box! server-thread srv)
  ;; Single reader owns the port: hello, responses/errors and events all
  ;; dispatch here — no second reader can race for the hello frame.
  (define hello-ch (make-async-channel))
  (define rdr
    (thread
     (lambda ()
       (let loop ()
         (with-handlers ([exn:fail?
                          (lambda (e)
                            ;; Port closed / serve died: wake every waiter
                            ;; with the failure instead of hanging.
                            (async-channel-put hello-ch (cons 'dead e))
                            (call-with-semaphore
                             pending-lock
                             (lambda ()
                               (for ([ch (in-hash-values pending)])
                                 (async-channel-put ch (cons 'dead e)))))
                            (raise e))])
           (define f (read-frame client-in))
           (match (frame-type f)
             [(== message:hello)
              (async-channel-put hello-ch (cons 'hello f))]
             [(== message:response)
              (define ch
                (call-with-semaphore
                 pending-lock
                 (lambda () (hash-ref pending (frame-id f) #f))))
              (when ch
                (async-channel-put ch (cons 'ok (decode-value (frame-payload f)))))]
             [(== message:error)
              (define ch
                (call-with-semaphore
                 pending-lock
                 (lambda () (hash-ref pending (frame-id f) #f))))
              (when ch
                (async-channel-put ch (cons 'err (decode-value (frame-payload f)))))]
             [(== message:event)
              (with-handlers ([exn:fail? void])
                ((unbox event-handler) (decode-value (frame-payload f))))]
             [_ (void)])
           (loop))))))
  (set-box! reader-thread rdr)
  ;; Handshake: the server opens with the RVT1 hello frame.
  (define hello-result (sync/timeout 30 hello-ch))
  (unless hello-result
    (error 'start-rvt1! "timed out waiting for RVT1 hello (server alive: ~a)"
           (not (thread-dead? srv))))
  (match hello-result
    [(cons 'hello f) (void)]
    [(cons 'dead e) (raise e)])
  (void))

;; One RPC over the wire. Returns (values result #f) or (values #f error).
(define (rvt1-call name . args)
  (unless (rvt1-alive?)
    (error 'rvt1-call "engine backend is not running"))
  (call-with-semaphore
   call-lock
   (lambda ()
     (set! next-id (add1 next-id))
     (define id next-id)
     (define ch (make-async-channel))
     (call-with-semaphore
      pending-lock
      (lambda () (hash-set! pending id ch)))
     (define out (unbox client-out-box))
     (write-frame (frame message:request
                         id
                         (encode-value (list* (if (symbol? name) (symbol->string name) name)
                                              args)))
                  out)
     (flush-output out)
     (define result (sync/timeout 120 ch))
     (call-with-semaphore
      pending-lock
      (lambda () (hash-remove! pending id)))
     (cond
       [(not result)
        (error 'rvt1-call "timed out waiting for ~a (server alive: ~a)"
               name (rvt1-alive?))]
       [(eq? (car result) 'ok) (values (cdr result) #f)]
       [(eq? (car result) 'err) (values #f (cdr result))]
       [(eq? (car result) 'dead) (raise (cdr result))]))))