;;;; Test package for cl-temporal-extent.

(in-package #:cl-user)

(defpackage #:temporal-extent/test
  (:use #:cl #:fiveam #:temporal-extent)
  (:import-from #:local-time
                #:encode-timestamp #:timestamp< #:timestamp= #:timestamp+
                #:timestamp- #:now #:nsec-of #:+utc-zone+
                #:*default-timezone*)
  (:export #:run-tests #:temporal-extent-suite))
