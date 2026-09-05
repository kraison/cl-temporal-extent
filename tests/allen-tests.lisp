;;;; The Allen algebra over interval extents (design §4).

(in-package #:temporal-extent/test)

(in-suite temporal-extent-suite)

(defun exact-interval (s e)
  "An interval extent with exact endpoints, for the exactness tests."
  (make-interval (exact-bound s) (exact-bound e)))

(test the-vocabulary-is-thirteen-and-inversion-is-an-involution
  (is (= 13 (length +allen-relations+)))
  (is (= 13 (length (remove-duplicates +allen-relations+))))
  (is (eq :equals (allen-inverse :equals)))
  (dolist (r +allen-relations+)
    (is (eq r (allen-inverse (allen-inverse r)))
        "~S must invert back to itself" r)))

(test exact-intervals-give-a-singleton-matching-classical-allen
  (let ((cases
          ;; a-start a-end b-start b-end  expected
          '((1 2 3 4 :before)   (1 2 2 3 :meets)
            (1 3 2 4 :overlaps) (1 4 2 4 :finished-by)
            (1 5 2 4 :contains) (1 2 1 3 :starts)
            (1 2 1 2 :equals)   (1 3 1 2 :started-by)
            (2 3 1 4 :during)   (2 4 1 4 :finishes)
            (2 4 1 3 :overlapped-by)
            (2 3 1 2 :met-by)   (3 4 1 2 :after))))
    (dolist (c cases)
      (destructuring-bind (as ae bs be expected) c
        (let ((a (exact-interval (ts 2026 1 as) (ts 2026 1 ae)))
              (b (exact-interval (ts 2026 1 bs) (ts 2026 1 be))))
          (is (eq expected (allen-relation a b))
              "[~D,~D] vs [~D,~D] should be ~S, got ~S"
              as ae bs be expected (allen-relation a b))
          (is-true (allen-definite-p a b)))))))

(test every-relation-is-reachable-and-they-are-disjoint
  "Jointly exhaustive and pairwise disjoint for exact intervals (§7.3)."
  (let ((seen '()))
    (loop for as from 1 to 4 do
      (loop for ae from (1+ as) to 5 do
        (loop for bs from 1 to 4 do
          (loop for be from (1+ bs) to 5 do
            (let ((r (allen-relation (exact-interval (ts 2026 1 as)
                                                     (ts 2026 1 ae))
                                     (exact-interval (ts 2026 1 bs)
                                                     (ts 2026 1 be)))))
              (is-true r "exact intervals must give a singleton")
              (pushnew r seen))))))
    (is (null (set-difference +allen-relations+ seen))
        "unreached relations: ~S" (set-difference +allen-relations+ seen))))

(test inversion-holds-for-exact-intervals
  (loop for as from 1 to 3 do
    (loop for ae from (1+ as) to 4 do
      (loop for bs from 1 to 3 do
        (loop for be from (1+ bs) to 4 do
          (let ((a (exact-interval (ts 2026 1 as) (ts 2026 1 ae)))
                (b (exact-interval (ts 2026 1 bs) (ts 2026 1 be))))
            (is (eq (allen-relation a b)
                    (allen-inverse (allen-relation b a))))))))))

(test an-imprecise-interval-yields-a-set-not-a-wrong-answer
  "Two extents recorded as \"January 2026\" as INTERVALS are genuinely
EQUALS -- their endpoints are exact.  The uncertainty case is the instant,
which Task 5 covers."
  (let ((jan (make-granule-interval (ts 2026 1 15) :month)))
    (is (eq :equals (allen-relation jan jan)))))

(test a-wholly-unknown-interval-relates-to-everything
  "Design §3.1: total ignorance comes back as all thirteen, in the
algebra's own terms, not as NIL."
  (let ((unknown (make-interval (unknown-bound) (unknown-bound)
                                :standing :indeterminate))
        (known (exact-interval (ts 2026 1 1) (ts 2026 1 2))))
    (is (= 13 (length (temporal-relation-relations
                       (allen-relations unknown known)))))
    (is-false (allen-relation unknown known))
    (is-false (allen-definite-p unknown known))))

(test the-relation-set-is-never-empty
  (let ((a (exact-interval (ts 2026 1 1) (ts 2026 1 2)))
        (b (exact-interval (ts 2026 6 1) (ts 2026 6 2))))
    (is-true (temporal-relation-relations (allen-relations a b)))))

(test a-relation-carries-both-standings-and-both-semantics
  "Design §4.4: the set, not a collapsed weakest value."
  (let* ((a (exact-interval (ts 2026 1 1) (ts 2026 1 2)))
         (b (make-interval (exact-bound (ts 2026 6 1))
                           (exact-bound (ts 2026 6 2))
                           :standing :inferred :semantics :validity))
         (r (allen-relations a b)))
    (is (null (set-difference '(:observed :inferred)
                              (temporal-relation-standings r))))
    (is (null (set-difference '(:event :validity)
                              (temporal-relation-semantics r))))))

(test predicates-are-set-membership
  (let ((a (exact-interval (ts 2026 1 1) (ts 2026 1 2)))
        (b (exact-interval (ts 2026 1 3) (ts 2026 1 4))))
    (is-true (extent-before-p a b))
    (is-false (extent-after-p a b))
    (is-true (extent-after-p b a))))

;;; GH #2: an interval's endpoints are not independent -- its end is never
;;; before its start -- so an unknown end must not admit relations that
;;; place the end before a point the start is already known to follow.

(test an-open-ended-interval-is-after-a-point-before-its-start
  "[s, unknown) vs a point p < s: only :BEFORE is possible from p's side.
Without the clamp, the unknown end compares :AMBIGUOUS against p and
:FINISHES / :AFTER leak in, so p reads as possibly inside the interval."
  (let ((open (make-interval (exact-bound (ts 2026 9 3)) (unknown-bound)))
        (p (make-instant (exact-bound (ts 2026 9 2)))))
    (is (equal '(:before) (temporal-relation-relations
                           (allen-relations p open))))
    (is (equal '(:after) (temporal-relation-relations
                          (allen-relations open p))))
    (is (eq :before (allen-relation p open)))))

(test an-open-ended-interval-is-after-an-interval-that-ends-before-it
  (let ((open (make-interval (exact-bound (ts 2026 9 3)) (unknown-bound)))
        (earlier (make-interval (exact-bound (ts 2026 9 1))
                                (exact-bound (ts 2026 9 2)))))
    (is (equal '(:after) (temporal-relation-relations
                          (allen-relations open earlier))))
    (is (equal '(:before) (temporal-relation-relations
                           (allen-relations earlier open))))))

(test an-unknown-start-is-before-a-point-after-its-end
  "The mirror: (unknown, e] vs a point p > e admits only :AFTER from p."
  (let ((open (make-interval (unknown-bound) (exact-bound (ts 2026 9 1))))
        (p (make-instant (exact-bound (ts 2026 9 2)))))
    (is (equal '(:after) (temporal-relation-relations
                          (allen-relations p open))))))

(test a-point-inside-an-open-ended-interval-is-still-ambiguous
  "Control: the clamp removes only incoherent relations.  A point after
the start of [s, unknown) may still be inside it or after it."
  (let ((open (make-interval (exact-bound (ts 2026 9 1)) (unknown-bound)))
        (p (make-instant (exact-bound (ts 2026 9 2)))))
    (is (null (set-exclusive-or
               '(:during :finishes :after)
               (temporal-relation-relations (allen-relations p open)))))))

;;; GH #1: "certainly share no instant" / "possibly share an instant" are
;;; properties of the algebra, moved here from graph-db/spacetime.

(test disjointness-is-certain-and-meeting-is-not-disjoint
  "Closed intervals that meet share their boundary instant (design §3.2)."
  (let ((a (exact-interval (ts 2026 1 1) (ts 2026 1 2)))
        (b (exact-interval (ts 2026 1 2) (ts 2026 1 3)))
        (c (exact-interval (ts 2026 1 3) (ts 2026 1 4))))
    (is-true (extents-disjoint-p a c))
    (is-true (extents-disjoint-p c a) "symmetric")
    (is-false (extents-disjoint-p a b) ":meets is not disjoint")
    (is-false (extents-intersect-p a c))
    (is-true (extents-intersect-p a b))))

(test an-ambiguous-pair-is-not-disjoint
  "Definite only when no choice within either range gives another answer:
a pair that MIGHT overlap is not certainly disjoint, and not certainly
intersecting either -- INTERSECT-P is the possibility, DISJOINT-P the
certainty, so both can be NIL/T respectively for one pair."
  (let ((fuzzy (make-interval (make-bound (ts 2026 1 1) (ts 2026 1 3))
                              (make-bound (ts 2026 1 2) (ts 2026 1 4))))
        (b (exact-interval (ts 2026 1 3) (ts 2026 1 5))))
    (is-false (extents-disjoint-p fuzzy b))
    (is-true (extents-intersect-p fuzzy b))))

(test a-point-is-disjoint-from-an-interval-only-when-outside-it
  (let ((i (exact-interval (ts 2026 1 2) (ts 2026 1 4))))
    (is-true (extents-disjoint-p (make-instant (exact-bound (ts 2026 1 1)))
                                 i))
    (is-false (extents-disjoint-p (make-instant (exact-bound (ts 2026 1 2)))
                                  i)
              "the closed start is inside")
    (is-false (extents-disjoint-p (make-instant (exact-bound (ts 2026 1 3)))
                                  i))
    (is-true (extents-disjoint-p (make-instant (exact-bound (ts 2026 1 5)))
                                 i))))

(test an-open-ended-interval-is-disjoint-from-what-precedes-its-start
  "The #2 case, through the predicate consumers actually call."
  (let ((open (make-interval (exact-bound (ts 2026 9 3)) (unknown-bound)))
        (p (make-instant (exact-bound (ts 2026 9 2)))))
    (is-true (extents-disjoint-p open p))
    (is-true (extents-disjoint-p p open))))

(test disjointness-takes-two-extents-and-refuses-nil
  "NIL-overlaps-everything is a consumer convention, not the algebra's."
  (let ((i (exact-interval (ts 2026 1 2) (ts 2026 1 4))))
    (signals type-error (extents-disjoint-p nil i))
    (signals type-error (extents-intersect-p i nil))))

;;; extent-intersection (#5): the extent two extents share, or NIL.

(test intersection-of-overlapping-exact-intervals-is-the-overlap
  (let* ((a (exact-interval (ts 2026 1 1) (ts 2026 3 31)))
         (b (exact-interval (ts 2026 2 1) (ts 2026 6 30)))
         (r (extent-intersection a b)))
    (is-true r)
    (is (eq :interval (extent-kind r)))
    (is (timestamp= (ts 2026 2 1) (bound-earliest (extent-start r))))
    (is (timestamp= (ts 2026 3 31) (bound-latest (extent-end r))))
    (is-true (bound-exact-p (extent-start r)))
    (is-true (bound-exact-p (extent-end r)))
    ;; Commutative in the bounds.
    (let ((s (extent-intersection b a)))
      (is (timestamp= (bound-earliest (extent-start r))
                      (bound-earliest (extent-start s))))
      (is (timestamp= (bound-latest (extent-end r))
                      (bound-latest (extent-end s)))))))

(test intersection-of-disjoint-extents-is-nil
  (let ((a (exact-interval (ts 2026 1 1) (ts 2026 1 31)))
        (b (exact-interval (ts 2026 3 1) (ts 2026 3 31))))
    (is (null (extent-intersection a b)))
    (is (null (extent-intersection b a)))
    ;; Control: the same A against something it does touch is not NIL.
    (is-true (extent-intersection a (exact-interval (ts 2026 1 15)
                                                    (ts 2026 2 15))))))

(test meeting-intervals-intersect-in-their-boundary-instant
  "Intervals are closed, so [1,2] and [2,3] share the instant 2."
  (let ((r (extent-intersection (exact-interval (ts 2026 1 1) (ts 2026 1 2))
                                (exact-interval (ts 2026 1 2) (ts 2026 1 3)))))
    (is-true r)
    (is-true (extent-instant-p r))
    (is (timestamp= (ts 2026 1 2) (bound-earliest (extent-start r))))))

(test containment-intersects-to-the-inner-extent
  (let* ((outer (exact-interval (ts 2026 1 1) (ts 2026 12 31)))
         (inner (exact-interval (ts 2026 3 1) (ts 2026 3 31)))
         (r (extent-intersection outer inner)))
    (is (timestamp= (ts 2026 3 1) (bound-earliest (extent-start r))))
    (is (timestamp= (ts 2026 3 31) (bound-latest (extent-end r))))))

(test an-instant-intersects-an-interval-as-itself-or-not-at-all
  (let ((i (exact-interval (ts 2026 1 1) (ts 2026 1 31)))
        (inside (make-instant (exact-bound (ts 2026 1 10))))
        (outside (make-instant (exact-bound (ts 2026 2 10)))))
    (let ((r (extent-intersection inside i)))
      (is-true (extent-instant-p r))
      (is (timestamp= (ts 2026 1 10) (bound-earliest (extent-start r)))))
    (is (null (extent-intersection outside i)))
    ;; Both orders.
    (is-true (extent-instant-p (extent-intersection i inside)))))

(test a-fuzzy-instant-is-narrowed-to-the-interval
  "A point known only to lie in [Jan 1, Jan 20], intersected with
[Jan 10, Jan 31], is a point in [Jan 10, Jan 20]."
  (let* ((p (make-instant (make-bound (ts 2026 1 1) (ts 2026 1 20))))
         (i (exact-interval (ts 2026 1 10) (ts 2026 1 31)))
         (r (extent-intersection p i)))
    (is-true (extent-instant-p r))
    (is (timestamp= (ts 2026 1 10) (bound-earliest (extent-start r))))
    (is (timestamp= (ts 2026 1 20) (bound-latest (extent-start r))))))

(test an-open-end-becomes-a-range-bounded-by-the-other-extents-end
  "An unknown end is unknown, not infinite: the intersection's end lies
somewhere in [start, Mar 1]."
  (let* ((open (make-interval (exact-bound (ts 2026 1 1)) (unknown-bound)))
         (closed (exact-interval (ts 2026 2 1) (ts 2026 3 1)))
         (r (extent-intersection open closed)))
    (is (timestamp= (ts 2026 2 1) (bound-earliest (extent-start r))))
    (is-true (bound-exact-p (extent-start r)))
    (is (timestamp= (ts 2026 2 1) (bound-earliest (extent-end r))))
    (is (timestamp= (ts 2026 3 1) (bound-latest (extent-end r))))
    (is-false (bound-exact-p (extent-end r)))))

(test fuzzy-bounds-combine-coordinate-wise
  "Starts take the later of each coordinate, ends the earlier."
  (let* ((a (make-interval (make-bound (ts 2026 1 1) (ts 2026 1 10))
                           (make-bound (ts 2026 3 1) (ts 2026 3 10))))
         (b (make-interval (make-bound (ts 2026 1 5) (ts 2026 1 20))
                           (make-bound (ts 2026 2 20) (ts 2026 3 5))))
         (r (extent-intersection a b)))
    (is (timestamp= (ts 2026 1 5) (bound-earliest (extent-start r))))
    (is (timestamp= (ts 2026 1 20) (bound-latest (extent-start r))))
    (is (timestamp= (ts 2026 2 20) (bound-earliest (extent-end r))))
    (is (timestamp= (ts 2026 3 5) (bound-latest (extent-end r))))))

(test a-fuzzy-pair-that-normalises-to-a-point-gives-an-instant
  "A pair whose raw combined bounds are only :AMBIGUOUS can still
normalise to a single exact instant; EXTENT-INTERSECTION must dispatch
on the NORMALISED pair, not the raw one, or the interval branch's
MAKE-INTERVAL signals INVALID-EXTENT on a legitimate intersection."
  (let* ((a (make-interval (make-bound (ts 2026 1 16) (ts 2026 1 21))
                           (exact-bound (ts 2026 4 16))))
         (b (make-interval (exact-bound (ts 2026 1 1))
                           (make-bound (ts 2026 1 11) (ts 2026 1 16))))
         (r (extent-intersection a b)))
    (is-true (extent-instant-p r))
    (is (timestamp= (ts 2026 1 16) (bound-earliest (extent-start r))))
    (is-true (bound-exact-p (extent-start r)))))

(test intersection-metadata-defaults-and-keywords
  (let* ((a (make-interval (exact-bound (ts 2026 1 1))
                           (exact-bound (ts 2026 3 1))
                           :precision :day :semantics :validity
                           :standing :observed))
         (b (make-interval (exact-bound (ts 2026 2 1))
                           (exact-bound (ts 2026 4 1))
                           :precision :month :semantics :event
                           :standing :asserted))
         (r (extent-intersection a b))
         (k (extent-intersection a b :semantics :transaction
                                     :standing :inferred
                                     :precision :second)))
    ;; Defaults: A's semantics and standing, the coarser precision.
    (is (eq :validity (extent-semantics r)))
    (is (eq :observed (extent-standing r)))
    (is (eq :month (extent-precision r)))
    (is (eq :transaction (extent-semantics k)))
    (is (eq :inferred (extent-standing k)))
    (is (eq :second (extent-precision k)))))

(test intersection-is-nil-exactly-when-disjoint-over-exact-intervals
  "Property over every pair of small exact intervals: NIL iff
EXTENTS-DISJOINT-P, and a non-NIL result touches both inputs and is
[max start, min end]. A second pass repeats the NIL-iff-disjoint half
over the same positions with FUZZY bounds, without the positional
check (which assumes exactness) -- just that EXTENT-INTERSECTION
never signals and stays consistent with EXTENTS-DISJOINT-P."
  (loop for as from 1 to 4 do
    (loop for ae from (1+ as) to 5 do
      (loop for bs from 1 to 4 do
        (loop for be from (1+ bs) to 5 do
          (let* ((a (exact-interval (ts 2026 1 as) (ts 2026 1 ae)))
                 (b (exact-interval (ts 2026 1 bs) (ts 2026 1 be)))
                 (r (extent-intersection a b)))
            (is (eq (null r) (extents-disjoint-p a b))
                "[~D,~D] vs [~D,~D]" as ae bs be)
            (when r
              (is-false (extents-disjoint-p r a))
              (is-false (extents-disjoint-p r b))
              (is (timestamp= (ts 2026 1 (max as bs))
                              (bound-earliest (extent-start r))))
              (is (timestamp= (ts 2026 1 (min ae be))
                              (bound-latest (extent-end r))))))))))
  ;; Endpoints each independently exact or fuzzy [d, d+2], at the same
  ;; ordered positions as above so every constructed pair is a sane
  ;; interval (start strictly before end, per MAKE-INTERVAL). None of
  ;; these trip the pre-existing "empty relation set" signature-table
  ;; gap in ALLEN-RELATIONS (used by EXTENTS-DISJOINT-P) -- verified by
  ;; running this exact loop before committing it; if a future change
  ;; makes one signal, that is the pre-existing bug, not this function.
  (flet ((fuzzy-bound (kind d)
           (ecase kind
             (:exact (exact-bound (ts 2026 1 d)))
             (:fuzzy (make-bound (ts 2026 1 d) (ts 2026 1 (+ d 2)))))))
    (loop for as from 1 to 4 do
      (loop for ae from (1+ as) to 5 do
        (loop for bs from 1 to 4 do
          (loop for be from (1+ bs) to 5 do
            (dolist (ask '(:exact :fuzzy))
              (dolist (aek '(:exact :fuzzy))
                (dolist (bsk '(:exact :fuzzy))
                  (dolist (bek '(:exact :fuzzy))
                    (let* ((a (make-interval (fuzzy-bound ask as)
                                             (fuzzy-bound aek ae)))
                           (b (make-interval (fuzzy-bound bsk bs)
                                             (fuzzy-bound bek be)))
                           (r (extent-intersection a b)))
                      (is (eq (null r) (extents-disjoint-p a b))
                          "fuzzy [~D ~A,~D ~A] vs [~D ~A,~D ~A]"
                          as ask ae aek bs bsk be bek)
                      (when r
                        (is-false (extents-disjoint-p r a))
                        (is-false (extents-disjoint-p r b))))))))))))))

(test intersection-rejects-a-non-extent
  (let ((i (exact-interval (ts 2026 1 1) (ts 2026 1 2))))
    (signals type-error (extent-intersection nil i))
    (signals type-error (extent-intersection i nil))))
