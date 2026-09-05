;;;; The Allen interval algebra over extents whose endpoints are ranges.
;;;;
;;;; The thirteen relations are determined by the signs of four endpoint
;;;; comparisons; an :AMBIGUOUS comparison is a wildcard, so an imprecise
;;;; extent yields a SET (GH #130, design §4.1).

(in-package #:temporal-extent)

(defparameter +allen-relations+
  '(:before :meets :overlaps :finished-by :contains :starts :equals
    :started-by :during :finishes :overlapped-by :met-by :after)
  "The closed relation vocabulary.  Thirteen, not fourteen: :EQUALS is its
own inverse.")

(defparameter +allen-inverses+
  '((:before . :after) (:meets . :met-by) (:overlaps . :overlapped-by)
    (:finished-by . :finishes) (:contains . :during) (:starts . :started-by)
    (:equals . :equals) (:started-by . :starts) (:during . :contains)
    (:finishes . :finished-by) (:overlapped-by . :overlaps)
    (:met-by . :meets) (:after . :before)))

(defun allen-inverse (relation)
  "The relation R such that (R b a) holds exactly when (RELATION a b) does."
  (or (cdr (assoc relation +allen-inverses+))
      (error 'invalid-extent
             :reason (format nil "~S is not an Allen relation" relation))))

(defparameter +allen-signatures+
  ;; (relation s1?s2 s1?e2 e1?s2 e1?e2), read off canonical NON-degenerate
  ;; examples.  Degenerate extents do not obey this table -- see the instant
  ;; path (design §3.3.1).
  '((:before        :< :< :< :<)
    (:meets         :< :< := :<)
    (:overlaps      :< :< :> :<)
    (:finished-by   :< :< :> :=)
    (:contains      :< :< :> :>)
    (:starts        := :< :> :<)
    (:equals        := :< :> :=)
    (:started-by    := :< :> :>)
    (:during        :> :< :> :<)
    (:finishes      :> :< :> :=)
    (:overlapped-by :> :< :> :>)
    (:met-by        :> := :> :>)
    (:after         :> :> :> :>)))

(defstruct (temporal-relation (:copier nil))
  "RELATIONS is never empty: two extents always stand in at least one Allen
relation, and total ignorance is all thirteen rather than none.  STANDINGS
and SEMANTICS carry both endpoints' values -- not a collapse (design §4.4)."
  (relations nil :read-only t)
  (standings nil :read-only t)
  (semantics nil :read-only t))

(defun %compatible-p (computed expected)
  "An :AMBIGUOUS comparison constrains nothing, so it matches any sign."
  (or (eq computed :ambiguous) (eq computed expected)))

(defun %effective-end (e)
  "E's END with its EARLIEST raised to the START's EARLIEST.  An end is
never before its start, so an unknown or wide end bound must not be
compared as if it could precede the start (GH #2).  MAKE-INTERVAL already
guarantees START's earliest <= END's latest, so the result is a bound."
  (let* ((end (extent-end e))
         (se (bound-earliest (extent-start e)))
         (ee (bound-earliest end)))
    (if (or (eq se :unbounded)
            (and (not (eq ee :unbounded)) (local-time:timestamp<= se ee)))
        end
        (%make-bound se (bound-latest end)))))

(defun %effective-start (e)
  "The mirror of %EFFECTIVE-END: START with its LATEST lowered to END's
LATEST."
  (let* ((start (extent-start e))
         (sl (bound-latest start))
         (el (bound-latest (extent-end e))))
    (if (or (eq el :unbounded)
            (and (not (eq sl :unbounded)) (local-time:timestamp<= sl el)))
        start
        (%make-bound (bound-earliest start) el))))

(defun %interval-relations (a b)
  "The relations consistent with A and B's four endpoint comparisons,
taken on their EFFECTIVE bounds (GH #2).  Correct only when NEITHER
extent is an instant."
  (let* ((as (%effective-start a)) (ae (%effective-end a))
         (bs (%effective-start b)) (be (%effective-end b))
         (c1 (bound-compare as bs))
         (c2 (bound-compare as be))
         (c3 (bound-compare ae bs))
         (c4 (bound-compare ae be)))
    (loop for (rel s1 s2 s3 s4) in +allen-signatures+
          when (and (%compatible-p c1 s1) (%compatible-p c2 s2)
                    (%compatible-p c3 s3) (%compatible-p c4 s4))
            collect rel)))

(defun %instant-vs-instant (a b)
  "Two points relate only three ways.  :AMBIGUOUS admits all three."
  (let ((c (bound-compare (extent-start a) (extent-start b))))
    (ecase c
      (:< '(:before))
      (:= '(:equals))
      (:> '(:after))
      (:ambiguous '(:before :equals :after)))))

(defun %instant-vs-interval (p i)
  "Point P against interval I, per the design §3.3.1 table.  :MEETS and the
other eight are unreachable: under closed intervals a point at I's start is
INSIDE I, so :STARTS states strictly more than :MEETS."
  (let ((cs (bound-compare (extent-start p) (%effective-start i)))
        (ce (bound-compare (extent-start p) (%effective-end i)))
        (rels '()))
    (flet ((maybe (comparison &rest admissible)
             (member comparison admissible)))
      (when (maybe cs :< :ambiguous) (push :before rels))
      (when (maybe cs := :ambiguous) (push :starts rels))
      (when (and (maybe cs :> :ambiguous) (maybe ce :< :ambiguous))
        (push :during rels))
      (when (maybe ce := :ambiguous) (push :finishes rels))
      (when (maybe ce :> :ambiguous) (push :after rels)))
    (nreverse rels)))

(defun %relations-between (a b)
  "Dispatch on degeneracy: the signature table is read off non-degenerate
examples and does not describe instants (design §3.3.1)."
  (let ((ai (extent-instant-p a))
        (bi (extent-instant-p b)))
    (cond ((and ai bi) (%instant-vs-instant a b))
          (ai (%instant-vs-interval a b))
          (bi (mapcar #'allen-inverse (%instant-vs-interval b a)))
          (t (%interval-relations a b)))))

(defun allen-relations (a b)
  "The TEMPORAL-RELATION between extents A and B: every Allen relation
consistent with their endpoint ranges, plus both standings and semantics."
  (let ((rels (%relations-between a b)))
    (assert rels ()
            "empty relation set for ~S vs ~S -- a signature table bug" a b)
    (make-temporal-relation
     :relations rels
     :standings (remove-duplicates
                 (list (extent-standing a) (extent-standing b)))
     :semantics (remove-duplicates
                 (list (extent-semantics a) (extent-semantics b))))))

(defun allen-relation (a b)
  "The single relation between A and B when the answer is definite, else
NIL.  NIL means \"more than one relation is possible\", never \"unrelated\"."
  (let ((rels (temporal-relation-relations (allen-relations a b))))
    (when (null (cdr rels))
      (car rels))))

(defun allen-definite-p (a b)
  "True when exactly one relation is possible between A and B."
  (null (cdr (temporal-relation-relations (allen-relations a b)))))

(defmacro %define-relation-predicate (name relation)
  `(defun ,name (a b)
     ,(format nil "True when ~S is possible between extents A and B."
              relation)
     (and (member ,relation (temporal-relation-relations
                             (allen-relations a b)))
          t)))

(%define-relation-predicate extent-before-p :before)
(%define-relation-predicate extent-meets-p :meets)
(%define-relation-predicate extent-overlaps-p :overlaps)
(%define-relation-predicate extent-finished-by-p :finished-by)
(%define-relation-predicate extent-contains-p :contains)
(%define-relation-predicate extent-starts-p :starts)
(%define-relation-predicate extent-equals-p :equals)
(%define-relation-predicate extent-started-by-p :started-by)
(%define-relation-predicate extent-during-p :during)
(%define-relation-predicate extent-finishes-p :finishes)
(%define-relation-predicate extent-overlapped-by-p :overlapped-by)
(%define-relation-predicate extent-met-by-p :met-by)
(%define-relation-predicate extent-after-p :after)

;;; Disjointness and intersection -- properties of the algebra, not of any
;;; consumer (GH #1; previously a copy in graph-db/spacetime).

(defun extents-disjoint-p (a b)
  "True when extents A and B CERTAINLY share no instant: every relation
possible between them is :BEFORE or :AFTER.  :MEETS is not disjoint --
intervals are closed, so meeting extents share their boundary instant --
and an ambiguous pair is not disjoint either.  Both arguments must be
extents; a caller's NIL convention is the caller's."
  (check-type a temporal-extent)
  (check-type b temporal-extent)
  (and (every (lambda (r) (member r '(:before :after)))
              (temporal-relation-relations (allen-relations a b)))
       t))

(defun extents-intersect-p (a b)
  "True when extents A and B POSSIBLY share an instant -- the negation of
EXTENTS-DISJOINT-P over two extents.  A pair that might overlap
intersects here and is not disjoint there: the one is a possibility, the
other a certainty."
  (not (extents-disjoint-p a b)))

;;; Intersection -- the extent two extents share (#5).

(defun %later-start (a b)
  "The later of two START bounds, coordinate-wise: the later earliest,
the later latest.  :UNBOUNDED is -inf in an earliest and +inf in a
latest."
  (flet ((later-earliest (x y)
           (cond ((eq x :unbounded) y)
                 ((eq y :unbounded) x)
                 ((local-time:timestamp< x y) y)
                 (t x)))
         (later-latest (x y)
           (cond ((or (eq x :unbounded) (eq y :unbounded)) :unbounded)
                 ((local-time:timestamp< x y) y)
                 (t x))))
    (%make-bound (later-earliest (bound-earliest a) (bound-earliest b))
                 (later-latest (bound-latest a) (bound-latest b)))))

(defun %earlier-end (a b)
  "The mirror of %LATER-START for END bounds."
  (flet ((earlier-earliest (x y)
           (cond ((or (eq x :unbounded) (eq y :unbounded)) :unbounded)
                 ((local-time:timestamp< x y) x)
                 (t y)))
         (earlier-latest (x y)
           (cond ((eq x :unbounded) y)
                 ((eq y :unbounded) x)
                 ((local-time:timestamp< x y) x)
                 (t y))))
    (%make-bound (earlier-earliest (bound-earliest a) (bound-earliest b))
                 (earlier-latest (bound-latest a) (bound-latest b)))))

(defun %coarser-precision (a b)
  "The coarser of two precisions; +PRECISIONS+ runs coarse to fine."
  (if (<= (position a +precisions+) (position b +precisions+)) a b))

(defun extent-intersection (a b &key precision semantics standing)
  "The extent A and B share, or NIL when they certainly share no instant
(EXTENTS-DISJOINT-P).  Closed-interval semantics: meeting intervals
share their boundary instant, which comes back as an instant.  An
instant on either side gives an instant, narrowed to where it can lie
inside the other extent.  Fuzzy bounds combine coordinate-wise -- the
later start, the earlier end -- on the EFFECTIVE bounds (#2).
PRECISION defaults to the coarser of the two, SEMANTICS and STANDING
to A's; the library does not decide what an intersection means to a
caller.  Signals TYPE-ERROR on a non-extent, as EXTENTS-DISJOINT-P
does.  The result's bounds are normalised: an end's earliest is never
before the start's earliest, a start's latest never after the end's
latest."
  (check-type a temporal-extent)
  (check-type b temporal-extent)
  (when (extents-disjoint-p a b)
    (return-from extent-intersection nil))
  (let ((start (%later-start (%effective-start a) (%effective-start b)))
        (end (%earlier-end (%effective-end a) (%effective-end b)))
        (precision (or precision
                       (%coarser-precision (extent-precision a)
                                           (extent-precision b))))
        (semantics (or semantics (extent-semantics a)))
        (standing (or standing (extent-standing a))))
    (cond ((or (extent-instant-p a) (extent-instant-p b))
           ;; A point somewhere in START's earliest .. END's latest;
           ;; MAKE-BOUND's reversed check is the guard that the
           ;; disjointness test above was right.
           (make-instant (make-bound (bound-earliest start)
                                     (bound-latest end))
                         :precision precision :semantics semantics
                         :standing standing))
          (t
           (ecase (bound-compare start end)
             (:= (make-instant start :precision precision
                                     :semantics semantics
                                     :standing standing))
             ((:< :ambiguous)
              (let ((interval (make-interval start end
                                              :precision precision
                                              :semantics semantics
                                              :standing standing)))
                ;; Normalise: an end never before its start (#2), read
                ;; back off the interval we just built.
                (make-interval (%effective-start interval)
                                (%effective-end interval)
                                :precision precision :semantics semantics
                                :standing standing)))
             ;; Unreachable past the disjointness test; ECASE keeps
             ;; that claim honest rather than returning junk.
             (:> nil))))))
