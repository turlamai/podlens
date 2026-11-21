#lang racket/base

;; Packaged entry point. `raco glaze build` derives the project directory
;; from the entry file's parent, and stages public/ from there — so the
;; release entry lives at the repository root (where the workflow stages
;; the built web UI) while the real carrier main stays in backend/.
;; Requiring the main submodule runs it exactly once.
(require (submod "backend/main.rkt" main))