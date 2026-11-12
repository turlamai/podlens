#lang racket/base

;; Deterministic, offline showcase library for design review snapshots.
;; Covers are local PNGs (ArtworkStore reads file:// URLs); transcripts and
;; summaries are synthetic. No network, no API key, no real feed.

(require json
         racket/file
         racket/list
         racket/path
         (file "../../racket/core/library.rkt")
         (file "../../racket/core/paths.rkt"))

(define script-dir
  (or (current-load-relative-directory) (current-directory)))
(define cover-dir
  (or (getenv "PODLENS_SHOWCASE_COVERS")
      (path->string (build-path script-dir "assets" "showcase"))))

(define (cover n)
  (path->string (build-path cover-dir (format "cover~a.png" n))))

(define (file-url path)
  (string-append "file://" (url-unquote path)))

(define (url-unquote s)
  (regexp-replace* #rx" " s "%20"))

(define (episode guid title date duration description)
  (hasheq 'guid guid
          'title title
          'pub-date-epoch 1
          'pub-date-display date
          'enclosure-url (format "https://fixtures.invalid/~a.mp3" guid)
          'enclosure-length 2048
          'enclosure-type "audio/mpeg"
          'duration-sec duration
          'chapters-url ""
          'description description))

(define (parsed-feed title author description art items)
  (hasheq 'title title
          'author author
          'description description
          'artwork-url (file-url art)
          'items items))

(library-load!)

(define feeds
  (list
   (cons "https://fixtures.invalid/design.xml"
         (parsed-feed "The Design Details" "Studio North"
                      "Interfaces, type and the craft of quiet software."
                      (cover 1)
                      (list
                       (episode "design-1" "Why the best interfaces disappear"
                                "2026-11-02" 3240
                                "A conversation about restraint: the decisions you never notice because they simply work.")
                       (episode "design-2" "Typography is the interface"
                                "2026-10-26" 2880
                                "Weight, rhythm and the space between letters.")
                       (episode "design-3" "The quiet craft of default states"
                                "2026-10-19" 2610
                                "Empty screens, loading states and error messages deserve the same care as the hero."))))
   (cons "https://fixtures.invalid/machine.xml"
         (parsed-feed "Machine, Carefully" "Ada Park"
                      "How intelligent systems are built, measured and trusted."
                      (cover 2)
                      (list
                       (episode "machine-1" "What evaluation actually measures"
                                "2026-11-01" 3600
                                "Benchmarks, incentives and the gap between a demo and a product.")
                       (episode "machine-2" "Small models, sharp tools"
                                "2026-10-24" 3000
                                "Why narrow, well-instrumented systems often beat a bigger model."))))
   (cons "https://fixtures.invalid/sky.xml"
         (parsed-feed "Deep Sky Notes" "Orbit Lab"
                      "A slow tour of the universe, one object at a time."
                      (cover 3)
                      (list
                       (episode "sky-1" "The light that left before us"
                                "2026-10-30" 3420
                                "Distance, time and what a photograph of a galaxy really shows.")
                       (episode "sky-2" "Listening to gravitational waves"
                                "2026-10-16" 3180
                                "A billion-year collision, measured as a whisper."))))
   (cons "https://fixtures.invalid/longgame.xml"
         (parsed-feed "The Long Game" "Nora Fields"
                      "Decisions that compound over years, not quarters."
                      (cover 4)
                      (list
                       (episode "long-1" "Boring advantages"
                                "2026-10-28" 2760
                                "Distribution, trust and the unglamorous assets that survive."))))))

(define feed-ids
  (for/list ([entry (in-list feeds)])
    (feed-add! (car entry) (cdr entry))))

(define design-feed-id (first feed-ids))
(define design-episodes (episodes-for-feed design-feed-id))
(define target (first design-episodes))
(define target-id (hash-ref target 'id))

;; A silent 90-second WAV so playback/seek behave without external media.
(define (le value size) (integer->integer-bytes value size #f #f))
(define (silent-wav seconds)
  (define rate 8000)
  (define data-size (* seconds rate 2))
  (bytes-append
   #"RIFF" (le (+ 36 data-size) 4) #"WAVE"
   #"fmt " (le 16 4) (le 1 2) (le 1 2) (le rate 4)
   (le (* rate 2) 4) (le 2 2) (le 16 2)
   #"data" (le data-size 4) (make-bytes data-size 0)))

(define audio-dir (build-path (data-dir) "audio"))
(make-directory* audio-dir)
(define audio-path (build-path audio-dir (string-append target-id ".wav")))
(call-with-output-file audio-path
  (lambda (out) (void (write-bytes (silent-wav 90) out)))
  #:exists 'truncate/replace
  #:mode 'binary)

(define segments
  (list
   (hasheq 'start 0 'end 6 'text "Good design is mostly subtraction.")
   (hasheq 'start 6 'end 13 'text "Every control you add asks the listener for attention.")
   (hasheq 'start 13 'end 21 'text "The interface should hold the episode, not compete with it.")
   (hasheq 'start 21 'end 29 'text "Typography does the quiet work that color cannot.")
   (hasheq 'start 29 'end 37 'text "A transcript is a reading surface, so set it like one.")
   (hasheq 'start 37 'end 45 'text "Line height and measure decide whether people stay.")
   (hasheq 'start 45 'end 53 'text "Then the player can be small, because the words are large.")
   (hasheq 'start 53 'end 61 'text "Defaults are the most honest part of a product.")
   (hasheq 'start 61 'end 70 'text "An empty state should explain the next action, not apologize.")
   (hasheq 'start 70 'end 80 'text "And when something fails, say what happened and what to do next.")))

(define translations
  (list "好的设计大多是做减法。"
        "每多一个控件，就多向听众索取一次注意力。"
        "界面应该托住这一集内容，而不是与它竞争。"
        "字体在默默完成颜色做不到的工作。"
        "逐句稿是阅读界面，就该按阅读来排版。"
        "行高与栏宽决定了人是否愿意留下来。"
        "播放器可以很小，因为文字足够大。"
        "默认状态是一个产品最诚实的部分。"
        "空状态应该说明下一步，而不是道歉。"
        "失败时，告诉用户发生了什么、接下来做什么。"))

(transcript-save!
 target-id
 (hasheq
  'episode-id target-id
  'language "en"
  'segments segments
  'translation translations
  'target-lang "zh"
  'summary
  (hasheq
   'tldr "好的界面靠克制：把注意力留给内容，让排版承担阅读，让默认状态和错误信息同样被认真设计。"
   'key-points
   (list "每增加一个控件，都是在向听众索取注意力。"
         "逐句稿属于阅读界面，行高、栏宽和字号比装饰更重要。"
         "播放器可以退后，因为文字是主角。"
         "空状态与失败状态要说明下一步，而不是道歉。")
   'quotes
   (list (hasheq 'text "Good design is mostly subtraction."
                 'translation "好的设计大多是做减法。")
         (hasheq 'text "Defaults are the most honest part of a product."
                 'translation "默认状态是一个产品最诚实的部分。"))
   'topics (list "设计" "排版" "产品"))
  'asr-model "fixture"
  'chat-model "fixture"
  'updated-epoch 1))

(void (episode-set-download! target-id (path->string audio-path) (file-size audio-path)))
(void (episode-set-status! target-id 'transcript-status "done"))
(void (episode-set-position! target-id 38))
(void (episode-set-done! (hash-ref (second design-episodes) 'id) #t))
(void (episode-set-status! (hash-ref (second design-episodes) 'id) 'transcript-status "done"))


(call-with-output-file (build-path (data-dir) "showcase-fixture.json")
  (lambda (out)
    (write-json (hasheq 'feed-id design-feed-id 'episode-id target-id) out))
  #:exists 'truncate/replace)
