;;;; Time you only partly know: bounds, extents, the Allen relations over
;;;; them, and the vocabulary for how you came to know them.

(in-package #:cl-user)

(defpackage #:temporal-extent
  (:use #:cl)
  (:export
   ;; conditions
   ;; ⚠ SPACETIME-ERROR is named for the subsystem this library was
   ;; extracted from (vivace-graph #159).  Kept so consumers catching it
   ;; keep working; renaming it would silently narrow every HANDLER-CASE
   ;; already written against it.
   #:spacetime-error #:invalid-standing #:invalid-bound #:invalid-extent
   ;; standing
   #:standing #:standingp #:standing-absence-p #:standing-present-p
   #:check-standing #:+standings+ #:+absence-standings+
   ;; bound
   #:bound #:bound-p #:make-bound #:exact-bound #:unknown-bound
   #:bound-earliest #:bound-latest #:bound-exact-p #:bound-unknown-p
   #:bound-compare
   ;; extent
   #:temporal-extent #:temporal-extent-p #:+precisions+
   #:make-interval #:make-instant
   #:make-granule-interval #:make-granule-instant #:granule-bounds
   #:extent-kind #:extent-start #:extent-end #:extent-precision
   #:extent-semantics #:extent-standing #:extent-instant-p
   #:extent->sexp #:sexp->extent
   ;; allen
   #:temporal-relation #:temporal-relation-p
   #:temporal-relation-relations #:temporal-relation-standings
   #:temporal-relation-semantics
   #:+allen-relations+ #:+allen-inverses+ #:allen-inverse
   #:allen-relations #:allen-relation #:allen-definite-p
   #:extents-disjoint-p #:extents-intersect-p
   #:extent-before-p #:extent-meets-p #:extent-overlaps-p
   #:extent-finished-by-p #:extent-contains-p #:extent-starts-p
   #:extent-equals-p #:extent-started-by-p #:extent-during-p
   #:extent-finishes-p #:extent-overlapped-by-p #:extent-met-by-p
   #:extent-after-p))
