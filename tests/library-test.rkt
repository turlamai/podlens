#lang racket/base

;; Library store: feed/episode upserts, positions, transcripts — all against
;; a temp PODLENS_DATA_DIR.

(require rackunit
         racket/file
         racket/list
         racket/path
         (file "../racket/core/library.rkt"))

(putenv "PODLENS_DATA_DIR" (path->string (make-temporary-file "podlens-test~a" 'directory)))
(library-load!)

(define parsed
  (hasheq 'title "Test Podcast"
          'author "Tester"
          'description "d"
          'artwork-url "https://example.com/art.jpg"
          'items
          (list
           (hasheq 'guid "ep-1" 'title "First"
                   'pub-date-epoch 100 'pub-date-display "x"
                   'enclosure-url "https://example.com/1.mp3"
                   'enclosure-length 1000 'enclosure-type "audio/mpeg"
                   'duration-sec 60 'description "")
           (hasheq 'guid "ep-2" 'title "Second"
                   'pub-date-epoch 200 'pub-date-display "y"
                   'enclosure-url "https://example.com/2.mp3"
                   'enclosure-length 2000 'enclosure-type "audio/mpeg"
                   'duration-sec 90 'description ""))))

(test-case "feed add + episode seeding"
  (define fid (feed-add! "https://example.com/feed.xml" parsed))
  (check-true (string? fid))
  (define eps (episodes-for-feed fid))
  (check-equal? (length eps) 2)
  (check-equal? (hash-ref (car eps) 'title) "Second") ; sorted newest first
  (define fid2 (feed-add! "https://example.com/feed.xml" parsed))
  (check-equal? fid fid2) ; idempotent
  (check-equal? (length (episodes-for-feed fid)) 2))

(test-case "positions and done survive re-add"
  (define fid (feed-add! "https://example.com/feed.xml" parsed))
  (define e (car (episodes-for-feed fid)))
  (define eid (hash-ref e 'id))
  (episode-set-position! eid 42)
  (episode-set-done! eid #t)
  (feed-add! "https://example.com/feed.xml" parsed)
  (check-equal? (hash-ref (episode-get eid) 'position-sec) 42)
  (check-true (hash-ref (episode-get eid) 'done)))

(test-case "transcript files"
  (define fid (feed-add! "https://example.com/feed.xml" parsed))
  (define eid (hash-ref (car (episodes-for-feed fid)) 'id))
  (transcript-save! eid (hasheq 'segments (list (hasheq 'start 0 'end 2 'text "hi"))
                                'translation (list "嗨")
                                'summary #f))
  (define t (transcript-load eid))
  (check-equal? (hash-ref t 'translation) (list "嗨")))

(test-case "feed remove drops episodes"
  (define fid (feed-add! "https://example.com/feed.xml" parsed))
  (check-true (feed-remove! fid))
  (check-false (feed-get fid))
  (check-equal? (length (episodes-for-feed fid)) 0))

(test-case "recent-episodes merges feeds newest first"
  (define fid-a (feed-add! "https://example.com/feed.xml" parsed))
  (define newer
    (hasheq 'title "Newer Show" 'author "T" 'description "d"
            'artwork-url "https://example.com/newer.jpg"
            'items
            (list (hasheq 'guid "ep-n1" 'title "Fresh"
                          'pub-date-epoch 300 'pub-date-display "z"
                          'enclosure-url "https://example.com/n1.mp3"
                          'enclosure-length 1 'enclosure-type "audio/mpeg"
                          'duration-sec 30 'description ""))))
  (define fid-b (feed-add! "https://example.com/newer.xml" newer))
  (define merged (recent-episodes))
  (check-true (>= (length merged) 3))
  (check-equal? (hash-ref (car merged) 'title) "Fresh") ; newest across feeds
  (check-equal? (hash-ref (car merged) 'feed-id) fid-b)
  (check-equal? (hash-ref (cadr merged) 'pub-date-epoch) 200)
  ;; the cap is respected
  (check-equal? (length (recent-episodes 1)) 1))

(test-case "summary-normalize anchors points and degrades legacy strings"
  ;; legacy summaries stored points/quotes as plain strings
  (define legacy
    (hasheq 'tldr "一句总结。"
            'key-points (list "要点一" (hasheq 'text "要点二" 'start 12))
            'quotes (list (hasheq 'text "quote" 'translation "引用"))
            'topics (list "测试")))
  (define s (summary-normalize legacy))
  (check-equal? (hash-ref s 'tldr) "一句总结。")
  (check-equal? (hash-ref (first (hash-ref s 'key-points)) 'text) "要点一")
  (check-false (hash-ref (first (hash-ref s 'key-points)) 'start #f))
  (check-equal? (hash-ref (second (hash-ref s 'key-points)) 'start) 12)
  (check-equal? (hash-ref (first (hash-ref s 'quotes)) 'translation) "引用")
  (check-false (hash-ref (first (hash-ref s 'quotes)) 'start #f))
  ;; a start that is not a usable sentence time has no anchor; 0 is the
  ;; first sentence and stays a valid anchor
  (define bad (summary-normalize
               (hasheq 'tldr "x"
                       'key-points (list (hasheq 'text "p" 'start 0)
                                         (hasheq 'text "q" 'start "nope"))
                       'quotes '()
                       'topics '())))
  (check-equal? (hash-ref (first (hash-ref bad 'key-points)) 'start #f) 0)
  (check-false (hash-ref (second (hash-ref bad 'key-points)) 'start #f))
  (check-false (summary-normalize #f)))
