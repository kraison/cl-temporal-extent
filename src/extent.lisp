;;;; TEMPORAL-EXTENT: an interval or an instant, each endpoint a range, with
;;;; the precision that produced those ranges and the standing that says how
;;;; we came to know them (GH #130, design §3).

(in-package #:temporal-extent)

(defparameter +precisions+
  '(:year :month :day :hour :minute :second :nsec)
  "Granularities a record may be stated at.  PRECISION never enters
comparison -- the bound width already encodes it (design §3.2).")

(defstruct (temporal-extent
            (:conc-name extent-)
            (:constructor %make-extent
                (kind start end precision semantics standing))
            (:copier nil))
  "KIND is :INSTANT or :INTERVAL.  For an :INSTANT, START and END are the
SAME bound object -- that identity is the endpoint coupling (design §3.3)."
  (kind nil :read-only t)
  (start nil :read-only t)
  (end nil :read-only t)
  (precision nil :read-only t)
  (semantics nil :read-only t)
  (standing nil :read-only t))

(defun extent-instant-p (e)
  "True when E is a degenerate extent -- one timestamp, not a span."
  (eq (extent-kind e) :instant))

(defun %check-precision (p)
  (unless (member p +precisions+)
    (error 'invalid-extent
           :reason (format nil "~S is not a precision" p)))
  p)

(defun make-interval (start end &key (precision :nsec) (semantics :event)
                                     (standing :observed))
  "An extent spanning [START, END], both BOUNDs, whose endpoints move
independently.  Intervals are closed (design §3.2).  Signals INVALID-EXTENT
when START and END compare := -- that is a point in time; use MAKE-INSTANT
-- or :> -- END precedes START, a reversed and incoherent extent."
  (ecase (bound-compare start end)
    (:=
     (error 'invalid-extent
            :reason
            "START = END exactly -- a point in time; use MAKE-INSTANT"))
    (:>
     (error 'invalid-extent :reason "END precedes START"))
    ((:< :ambiguous) nil))
  (%make-extent :interval start end
                (%check-precision precision) semantics
                (check-standing standing)))

(defun make-instant (bound &key (precision :nsec) (semantics :event)
                                (standing :observed))
  "A degenerate extent: one timestamp, positioned somewhere in BOUND.  START
and END share the bound, so the two endpoints cannot move apart."
  (%make-extent :instant bound bound
                (%check-precision precision) semantics
                (check-standing standing)))

(defun %next-granule-start (precision year month day hour minute sec z)
  "The instant one PRECISION granule after the one starting at YEAR/MONTH/
DAY/HOUR/MINUTE/SEC, computed entirely in timezone Z.  Never
LOCAL-TIME:TIMESTAMP+ on a calendar unit -- it takes no :TIMEZONE argument
and does :YEAR/:MONTH/:DAY arithmetic in *DEFAULT-TIMEZONE*, so on a
DST-observing host a month/day granule's end could land up to an hour off,
and two adjacent month granules could overlap instead of meet (design
§3.5, GH #134).  :YEAR and :MONTH carry through an explicit next-calendar-
field ENCODE-TIMESTAMP call, since their length varies.  :DAY/:HOUR/
:MINUTE/:SECOND are each a fixed UTC duration, so adding that duration in
seconds to this granule's own start is exact and needs no calendar carry."
  (ecase precision
    (:year (local-time:encode-timestamp 0 0 0 0 1 1 (1+ year) :timezone z))
    (:month (multiple-value-bind (next-month next-year)
                (if (= month 12)
                    (values 1 (1+ year))
                    (values (1+ month) year))
              (local-time:encode-timestamp 0 0 0 0 1 next-month next-year
                                           :timezone z)))
    (:day (local-time:timestamp+
           (local-time:encode-timestamp 0 0 0 0 day month year :timezone z)
           86400 :sec))
    (:hour (local-time:timestamp+
            (local-time:encode-timestamp 0 0 0 hour day month year
                                         :timezone z)
            3600 :sec))
    (:minute (local-time:timestamp+
              (local-time:encode-timestamp 0 0 minute hour day month year
                                           :timezone z)
              60 :sec))
    (:second (local-time:timestamp+
              (local-time:encode-timestamp 0 sec minute hour day month year
                                           :timezone z)
              1 :sec))))

(defun granule-bounds (timestamp precision)
  "The first and last instants of the PRECISION granule containing
TIMESTAMP, as two values, computed in UTC (design §3.5)."
  (%check-precision precision)
  (let ((z local-time:+utc-zone+))
    (multiple-value-bind (nsec sec minute hour day month year)
        (local-time:decode-timestamp timestamp :timezone z)
      (let ((start (ecase precision
                     (:year (local-time:encode-timestamp
                             0 0 0 0 1 1 year :timezone z))
                     (:month (local-time:encode-timestamp
                              0 0 0 0 1 month year :timezone z))
                     (:day (local-time:encode-timestamp
                            0 0 0 0 day month year :timezone z))
                     (:hour (local-time:encode-timestamp
                             0 0 0 hour day month year :timezone z))
                     (:minute (local-time:encode-timestamp
                               0 0 minute hour day month year :timezone z))
                     (:second (local-time:encode-timestamp
                               0 sec minute hour day month year :timezone z))
                     (:nsec (local-time:encode-timestamp
                             nsec sec minute hour day month year
                             :timezone z)))))
        (values start
                (if (eq precision :nsec)
                    start
                    (local-time:timestamp-
                     (%next-granule-start precision year month day hour
                                          minute sec z)
                     1 :nsec)))))))

(defun make-granule-interval (timestamp precision &rest args)
  "The granule itself, as an interval with EXACT endpoints -- \"January
2026\".  Contrast MAKE-GRANULE-INSTANT (design §3.3).  At :NSEC the granule
is a single instant, so START = END and this signals INVALID-EXTENT; use
MAKE-GRANULE-INSTANT instead."
  (%check-precision precision)
  (multiple-value-bind (start end) (granule-bounds timestamp precision)
    (apply #'make-interval (exact-bound start) (exact-bound end)
           :precision precision args)))

(defun make-granule-instant (timestamp precision &rest args)
  "One timestamp known only to PRECISION -- \"sometime in January 2026\"."
  (%check-precision precision)
  (multiple-value-bind (start end) (granule-bounds timestamp precision)
    (apply #'make-instant (make-bound start end)
           :precision precision args)))

(defun %bound->sexp (b)
  (list (bound-earliest b) (bound-latest b)))

(defun %bound-sexp-shape-p (s)
  "T if S is a proper list of exactly 2 elements -- what %BOUND->SEXP
writes.  Same reason as %EXTENT-SEXP-SHAPE-P: (FIRST S) on a non-list is a
raw TYPE-ERROR, which is the leak SEXP->EXTENT exists to close."
  (and (consp s) (consp (cdr s)) (null (cddr s))))

(defun %sexp->bound (s)
  (unless (%bound-sexp-shape-p s)
    (error 'invalid-extent
           :reason (format nil "not a bound sexp: ~S" s)))
  (make-bound (first s) (second s)))

(defun extent->sexp (e)
  "A tree of values GRAPH-DB:SERIALIZE already handles -- keywords,
integers and LOCAL-TIME:TIMESTAMPs.  No core type byte is reserved
(design §6).  An :INSTANT writes ONE bound, so the codec cannot lose the
endpoint coupling."
  (list :temporal-extent 1
        (extent-kind e)
        (%bound->sexp (extent-start e))
        (if (extent-instant-p e) nil (%bound->sexp (extent-end e)))
        (extent-precision e)
        (extent-semantics e)
        (extent-standing e)))

(defun %extent-sexp-shape-p (s)
  "T if S is a proper list of exactly 8 elements.  Deliberately not
LENGTH: on an improper list LENGTH signals a raw TYPE-ERROR, which is
exactly the leak SEXP->EXTENT's shape check exists to close."
  (loop for tail = s then (cdr tail)
        for i from 0
        do (cond ((= i 8) (return (null tail)))
                 ((not (consp tail)) (return nil)))))

(defun sexp->extent (s)
  "Inverse of EXTENT->SEXP.  Every rejection is a SPACETIME-ERROR and never
a raw DESTRUCTURING-BIND, ECASE or TYPE-ERROR, so this is safe over
untrusted data: INVALID-EXTENT for a bad shape, tag, version, kind or
precision, INVALID-BOUND for a bad endpoint, INVALID-STANDING for a bad
standing.  ⚠ Handle SPACETIME-ERROR, not INVALID-EXTENT alone -- the
subconditions keep diagnostics that flattening them into one would lose."
  (unless (and (%extent-sexp-shape-p s)
               (eq (first s) :temporal-extent) (eql (second s) 1))
    (error 'invalid-extent
           :reason (format nil "not a version-1 extent sexp: ~S" s)))
  (destructuring-bind (tag version kind start end precision semantics
                       standing)
      s
    (declare (ignore tag version))
    (case kind
      (:instant (make-instant (%sexp->bound start) :precision precision
                              :semantics semantics :standing standing))
      (:interval (make-interval (%sexp->bound start) (%sexp->bound end)
                                :precision precision :semantics semantics
                                :standing standing))
      (t (error 'invalid-extent
                :reason (format nil "~S is not an extent kind" kind))))))
