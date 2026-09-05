;;;; cl-temporal-extent -- time you only partly know.

(defsystem "cl-temporal-extent"
  :description "Bounds, temporal extents, the Allen relations over imprecise
time, and a vocabulary for how a fact came to be known."
  :author "Kevin Thomas Raison"
  :license "MIT"
  :version "0.3.0"
  :depends-on ("local-time")
  :serial t
  :pathname "src/"
  :components ((:file "package")
               (:file "conditions")
               (:file "standing")
               (:file "bound")
               (:file "extent")
               (:file "allen"))
  :in-order-to ((test-op (test-op "cl-temporal-extent/tests"))))

(defsystem "cl-temporal-extent/tests"
  :description "Test suite for cl-temporal-extent."
  :license "MIT"
  :depends-on ("cl-temporal-extent" "fiveam")
  :serial t
  :pathname "tests/"
  :components ((:file "package")
               (:file "suite")
               (:file "standing-tests")
               (:file "bound-tests")
               (:file "extent-tests")
               (:file "allen-tests")
               (:file "instant-tests")
               (:file "property-tests"))
  :perform (test-op (op c)
             (unless (uiop:symbol-call :temporal-extent/test :run-tests)
               (error "cl-temporal-extent tests failed."))))
