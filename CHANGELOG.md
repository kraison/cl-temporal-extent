# Changelog

Notable changes to `cl-temporal-extent`. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this library
follows [semantic versioning](https://semver.org/spec/v2.0.0.html) and has
not cut a release yet.

## [Unreleased]

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
