;;;; The suite every test file enters, and the one fixture they share.

(in-package #:temporal-extent/test)

(def-suite temporal-extent-suite
  :description "Bounds, extents, the Allen relations, and standings.")

(in-suite temporal-extent-suite)

(defun run-tests ()
  "Run the whole suite; return true when every check passed."
  (results-status (run 'temporal-extent-suite)))

(defun ts (year month day &optional (hour 0) (minute 0) (sec 0) (nsec 0))
  "A UTC timestamp.  Every test builds times through this, so none of them
can accidentally depend on the host timezone."
  (encode-timestamp nsec sec minute hour day month year
                    :timezone +utc-zone+))
