#lang racket/base

;; Schema-driven JSON <-> RVT1 wire codec (#63).
;;
;; rivet-schema.json stays the single source of the RPC contract: record
;; field order, optional void-encoding and list element types all come
;; from that file at load time — nothing here hardcodes a DTO shape. The
;; web side speaks camelCase JSON objects; RVT1 speaks field-ordered
;; lists with (void) for absent optionals. This module is the only place
;; the two representations meet.
;;
;; The engine itself (racket/podlens) is untouched: the adapter drives the
;; production backend module over real RVT1 frames (backend/rvt1.rkt),
;; exactly the path racket/tests/backend-wire-test.rkt exercises.

(require glaze/api      ; exn:fail:glaze:bad-param — message passes both carriers
         json
         racket/file
         racket/match
         racket/runtime-path
         racket/string)

(provide rpc-spec
         rpc-names
         json->wire
         wire->json
         rpc/json)

(define-runtime-path schema-path "../rivet-schema.json")

(define schema
  (call-with-input-file schema-path read-json))

(define record-table
  (for/hash ([r (in-list (hash-ref schema 'records))])
    (values (hash-ref r 'name) r)))

(define rpc-table
  (for/hash ([r (in-list (hash-ref schema 'rpcs))])
    (values (hash-ref r 'name) r)))

(define (rpc-names)
  (sort (hash-keys rpc-table) string<?))

(define (rpc-spec name)
  (hash-ref rpc-table name
            (lambda () (error 'rpc/json "unknown RPC: ~a" name))))

;; ---- identifier mapping -------------------------------------------------
;; Schema names are kebab-case (list-id, show-completed); the web DTOs are
;; camelCase (listId, showCompleted). The mapping is mechanical and total.

(define (kebab->camel s)
  (define parts (string-split s "-"))
  (string-append*
   (cons (car parts)
         (for/list ([p (in-list (cdr parts))])
           (if (zero? (string-length p))
               ""
               (string-append (string-upcase (substring p 0 1))
                              (substring p 1)))))))

(define (camel->kebab s)
  (regexp-replace* #rx"([A-Z])" s
                   (lambda (m) (string-append "-" (string-downcase m)))))

(module+ test
  (require rackunit)
  (check-equal? (kebab->camel "list-id") "listId")
  (check-equal? (kebab->camel "show-completed") "showCompleted")
  (check-equal? (kebab->camel "id") "id")
  (check-equal? (camel->kebab "listId") "list-id")
  (check-equal? (camel->kebab "showCompleted") "show-completed")
  (for ([r (in-list (hash-ref schema 'rpcs))])
    (for ([a (in-list (hash-ref r 'arguments))])
      (check-equal? (camel->kebab (kebab->camel (hash-ref a 'name)))
                    (hash-ref a 'name)))))

;; ---- JSON -> wire --------------------------------------------------------

(define (json->wire v t)
  (match (hash-ref t 'kind)
    ["scalar"
     (match (hash-ref t 'name)
       ["Void" (void)]
       ["Any" v]
       ["Int64"
        (unless (exact-integer? v)
          (error 'rpc/json "expected integer, got: ~e" v))
        v]
       ["Bool"
        (unless (boolean? v)
          (error 'rpc/json "expected boolean, got: ~e" v))
        v]
       ["String"
        (unless (string? v)
          (error 'rpc/json "expected string, got: ~e" v))
        v]
       [other (error 'rpc/json "unsupported scalar type: ~a" other)])]
    ["optional"
     ;; Only JSON null means absent — #f and 0 are real values.
     (if (eq? v 'null)
         (void)
         (json->wire v (hash-ref t 'element)))]
    ["list"
     (unless (list? v)
       (error 'rpc/json "expected array, got: ~e" v))
     (for/list ([x (in-list v)])
       (json->wire x (hash-ref t 'element)))]
    ["record"
     (unless (hash? v)
       (error 'rpc/json "expected object for record ~a, got: ~e"
              (hash-ref t 'name) v))
     (define rec (hash-ref record-table (hash-ref t 'name)))
     (for/list ([f (in-list (hash-ref rec 'fields))])
       (define key (string->symbol (kebab->camel (hash-ref f 'name))))
       (json->wire (hash-ref v key 'null) (hash-ref f 'type)))]
    [kind (error 'rpc/json "unsupported type kind: ~a" kind)]))

;; ---- wire -> JSON --------------------------------------------------------

(define (wire->json v t)
  (match (hash-ref t 'kind)
    ["scalar"
     (match (hash-ref t 'name)
       ["Void" 'null]
       ["Any" (if (void? v) 'null v)]
       [else (if (void? v) 'null v)])]
    ["optional"
     (if (void? v) 'null (wire->json v (hash-ref t 'element)))]
    ["list"
     (for/list ([x (in-list v)])
       (wire->json x (hash-ref t 'element)))]
    ["record"
     (define rec (hash-ref record-table (hash-ref t 'name)))
     (define fields (hash-ref rec 'fields))
     (unless (= (length fields) (length v))
       (error 'rpc/json "record ~a: wire arity ~a != schema arity ~a"
              (hash-ref t 'name) (length v) (length fields)))
     (for/hash ([f (in-list fields)] [x (in-list v)])
       (values (string->symbol (kebab->camel (hash-ref f 'name)))
               (wire->json x (hash-ref f 'type))))]
    [kind (error 'rpc/json "unsupported type kind: ~a" kind)]))

;; ---- one RPC call, JSON in / JSON out ------------------------------------
;; rvt1-call is injected by backend/main.rkt (avoids a module cycle: the
;; codec must stay loadable without starting the serve thread).

(define rvt1-call-box (box #f))

(define (set-rvt1-call! proc)
  (set-box! rvt1-call-box proc))

(provide set-rvt1-call!)

(define (rpc/json name args)
  (define spec (rpc-spec name))
  (define wire-args
    (for/list ([a (in-list (hash-ref spec 'arguments))])
      (define key (string->symbol (kebab->camel (hash-ref a 'name))))
      (json->wire (hash-ref args key 'null) (hash-ref a 'type))))
  (define call (unbox rvt1-call-box))
  (unless call
    (error 'rpc/json "RVT1 transport not started"))
  (define-values (result err) (apply call name wire-args))
  (when err
    ;; The engine's message is the user-facing message (save-lifecycle
    ;; contract: the backend's message at the form, never a generic one).
    ;; glaze answers plain exns with a generic "internal error" on both
    ;; carriers; bad-param is the framework's typed channel whose message
    ;; reaches the page (HTTP 400 / native invalid-args), as glaze's own
    ;; dialog routes use it. The transport code classifies, the engine
    ;; message informs.
    (raise (exn:fail:glaze:bad-param (format "~a" err) (current-continuation-marks))))
  (wire->json result (hash-ref spec 'result)))