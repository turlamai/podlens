#lang racket/base

;; Single source of the application version for the backend State, the CLI
;; output and update checks. The root VERSION file must carry the same
;; version; scripts/check-release-version.sh enforces the alignment on
;; every release. The glaze carrier takes its installer identity from the
;; release workflow's --version flag, which reads that same VERSION file.

(provide app-version)

(define app-version "0.1.0")
