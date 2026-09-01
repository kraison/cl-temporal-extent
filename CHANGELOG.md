# Changelog

Notable changes to `cl-temporal-extent`. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this library
follows [semantic versioning](https://semver.org/spec/v2.0.0.html) and has
not cut a release yet.

## [Unreleased]

### Added

- **`extents-disjoint-p` and `extents-intersect-p`** (#1), moved in from
  graph-db/spacetime: "certainly share no instant" (every possible
  relation is `:before` or `:after` -- so `:meets` is not disjoint, and an
  ambiguous pair is not disjoint) and its possibility counterpart. Both
  take two extents; a NIL-overlaps-everything convention stays with the
  caller. System version bumped to 0.2.0 so a consumer can declare the
  floor.

### Fixed

- **An interval's endpoints are compared as a pair, not independently
  (#2).** The Allen computation now takes each interval's *effective*
  bounds -- an end no earlier than its start, a start no later than its
  end -- so `[s, unknown)` against a point before `s` yields `(:before)`
  from the point's side instead of `(:before :finishes :after)`, and an
  open-ended interval no longer reads as possibly overlapping anything
  that precedes its start. Stored bounds are untouched: `unknown-bound`
  still means unknown, and `extent->sexp` is unchanged. Every consumer
  that asks "what held at t" through the algebra (`extents-disjoint-p`,
  `claims-touching :at` in graph-db/spacetime) gets the corrected answer.

### Changed

- **`sexp->extent` rejects more malformed input than it used to.** It now
  validates the sexp's shape before destructuring it, and every rejection
  is a `spacetime-error`. Three inputs that previously got through, or got
  through differently, now signal `invalid-extent`:
  - a bound position that is not a proper two-element list — previously a
    non-list raised a raw `type-error` from `(first s)`, and a wrong-arity
    list reached `make-bound` and came back as `invalid-bound`;
  - a bound sexp of **more** than two elements, previously accepted with
    its tail silently ignored;
  - an unknown `kind`, previously a raw `case-failure` from `ecase`.

  Valid input is unaffected: everything `extent->sexp` writes round-trips
  exactly as before.

- **Catch `spacetime-error`, not `invalid-extent` alone.** The guarantee
  `sexp->extent` now makes is that no *raw* error escapes it — not that
  every rejection is one condition. A bad endpoint stays an
  `invalid-bound` and a bad standing an `invalid-standing`, each keeping
  the diagnostics that flattening them into `invalid-extent` would lose.
  Callers narrowed to `invalid-extent` will miss those two.

### Fixed

- `sexp->extent` leaked raw errors on malformed input, so a caller reading
  untrusted data could see a `program-error` from `destructuring-bind` (a
  too-short sexp), a `type-error` from `length` (a dotted list), a
  `case-failure` from `ecase` (a bad kind), or a `type-error` from
  `(first s)` (a non-list bound) — none of them the documented condition.
  The shape checks walk the list with a hard element cap rather than
  calling `length`, so they terminate on a circular list too.
  Found by cl-llm#13 unit 2, whose facet reader decodes extents straight
  out of chunk metadata.

## 0.1.0

Extracted from vivace-graph (vivace-graph#159): bounds, temporal extents,
the Allen relations over imprecise time, and the standing vocabulary.
