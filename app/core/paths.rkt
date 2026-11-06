#lang racket/base

;; PodLens data layout. Everything lives in one directory so backups,
;; multi-instance tests (PODLENS_DATA_DIR) and uninstall are trivial.
;;
;;   ~/.podlens/
;;   ├── config.json        user settings (by reference, never the API key)
;;   ├── library.json       subscriptions + episodes + playback positions
;;   ├── audio/<id>.<ext>   downloaded episode audio
;;   ├── chapters/<id>.json downloaded chapter marks (podcast:chapters)
;;   ├── secrets/           fallback secret files (0600; see secrets.rkt)
;;   └── transcripts/<id>.json  ASR segments, translation, summary

(require racket/file racket/path racket/string)

(provide data-dir
         config-path
         library-path
         audio-dir
         secrets-dir
         transcript-path
         chapters-path
         audio-path
         ensure-data-dir!
         ensure-audio-dir!)

(define (data-dir)
  (define env (getenv "PODLENS_DATA_DIR"))
  (if (and env (non-empty-string? (string-trim env)))
      (simple-form-path (string-trim env))
      (build-path (find-system-path 'home-dir) ".podlens")))

(define (config-path) (build-path (data-dir) "config.json"))
(define (library-path) (build-path (data-dir) "library.json"))
(define (audio-dir) (build-path (data-dir) "audio"))
(define (secrets-dir) (build-path (data-dir) "secrets"))

;; transcripts/<id>.json — one file per episode.
(define (transcript-path episode-id)
  (build-path (data-dir) "transcripts" (format "~a.json" episode-id)))

;; chapters/<id>.json — cached podcast:chapters payload for an episode.
(define (chapters-path episode-id)
  (build-path (data-dir) "chapters" (format "~a.json" episode-id)))

;; audio/<id><ext> — ext keeps the container suffix so players/ASR trust it.
(define (audio-path episode-id ext)
  (build-path (audio-dir) (format "~a~a" episode-id ext)))

(define (ensure-data-dir!)
  (make-directory* (data-dir)))

(define (ensure-audio-dir!)
  (make-directory* (audio-dir)))
