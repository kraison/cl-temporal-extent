# cl-temporal-extent

Time you only partly know.

Most temporal libraries assume you know when something happened. This one is
for the common case where you do not: a document dated only to a month, a
survey whose end date was never recorded, a fact nobody has looked for yet.
It models the imprecision directly rather than forcing a false exactness, and
it keeps the *reasons* for absence apart.

Extracted from [vivace-graph](https://github.com/kraison/vivace-graph)'s
spatiotemporal substrate, where it had no dependency on the database it lived
in. It depends on `local-time` and nothing else.

## The three ideas

**A bound is a range within which one timestamp lies.** Making the endpoint a
range rather than a value is what lets imprecision, open-endedness and total
ignorance share one mechanism.

```lisp
(exact-bound (encode-timestamp 0 0 0 0 15 1 2026))  ; known to the nanosecond
(make-bound jan-1 jan-31)                           ; sometime in January
(unknown-bound)                                     ; no idea
```

Either endpoint may be `:unbounded` — negative infinity in `earliest`,
positive infinity in `latest` — so "since 2019, still going" is expressible
without a sentinel date.

**An extent is an instant or an interval over bounds**, carrying a precision
and a free-form `semantics` label so a validity time and a transaction time
can be told apart.

```lisp
(make-granule-instant timestamp :month)          ; "January 2026", honestly
(make-interval (exact-bound start) (unknown-bound)
               :semantics :transaction)          ; "recorded then, still true"
```

**A standing says how you came to know** — and, crucially, includes four
distinct ways of *not* knowing:

| standing | meaning |
|---|---|
| `:observed` `:inferred` `:asserted` | how the value was arrived at |
| `:searched-empty` | we looked at a named population and found nothing |
| `:determined-empty` | emptiness follows from the subject itself |
| `:uncovered` | nothing exists that could have been searched |
| `:indeterminate` | we do not know whether there is anything |

"Nobody looked" and "we looked and found nothing" are different facts, and
collapsing them into `NIL` loses the difference permanently. The vocabulary
is deliberately **unordered**: `:asserted` and `:inferred` cannot be ranked,
so no comparison operator over standings exists.

## Allen relations that admit uncertainty

The thirteen Allen interval relations, generalised: when bounds are
imprecise, `allen-relations` returns the *set* of relations still possible
rather than guessing one.

```lisp
(allen-relations a b)     ; => (:overlaps :during) -- both remain possible
(allen-definite-p r)      ; => NIL, so do not treat it as settled
(extent-before-p a b)     ; the individual predicates, when you want one
```

A caller that needs a definite answer can ask whether it has one, instead of
receiving a confident wrong answer.

## Serialization

`extent->sexp` produces a tree of keywords, integers and timestamps — plain
data any ordinary serializer already handles, so an extent crosses a storage
or wire boundary without reserving a type of its own. `sexp->extent` is its
inverse and rejects an unknown tag or version.

## Installation

Not yet in Quicklisp. Clone into `~/quicklisp/local-projects/` (or any
directory ASDF searches):

```lisp
(ql:quickload :cl-temporal-extent)
```

Tests:

```lisp
(asdf:test-system :cl-temporal-extent)
```

## Status

Version 0.1.0. The code is not new — it has been in production use inside
vivace-graph, and arrives here with its 922-check suite intact. What is new
is that it no longer requires a graph database to use.

One name is historical and deliberately kept: the root condition is
`spacetime-error`, named for the subsystem this came from. Renaming it would
silently narrow every `handler-case` already written against it.

## License

MIT. Copyright (c) 2026 Kevin Thomas Raison.
