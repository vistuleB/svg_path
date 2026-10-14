# Further path minification suggestions

2026-10-14. Discussion following the SVGO 4.1.0 audit and serializer commits
`f36b5df` and `9a8db05`. The recommendation is to retain the current public API.
Several further experiments can use existing options, but mixed coordinate
commands and geometric approximation should remain deferred.

## Current position

Levels 1 and 2 improved separators, initial axis-command selection, and compact
scientific notation. Across the 180 valid audited path cases, output fell from
6,369 to 6,223 bytes. SVGO produced 5,277 bytes, but that gap includes changes to
structure, approximation, and decisions informed by SVG styling. Closing the
entire gap is not a suitable correctness or release requirement.

The original fixture findings remain in [REMAINING_FIXTURES.md](REMAINING_FIXTURES.md).
The current comparison is recorded in [level2-check.json](level2-check.json).
These are uncompressed path-data sizes on this corpus, not representative
compression benchmarks.

## Decisions at a glance

| Suggestion | Fit with current API | Recommendation |
| --- | --- | --- |
| Compare whole-path absolute and relative outputs | Already possible by calling the serializer twice | Document a caller recipe |
| Improve command-run selection within the requested coordinate mode | Can respect existing shorthand and repetition options | Candidate internal experiment |
| Mixed absolute and relative commands within one path | Conflicts with the meaning of the `relative` Boolean | Defer |
| Exact cubic-to-quadratic reduction | No signature change necessary, but adds a structural policy | Investigate separately before adopting |
| Existing SVG arc normalization | Already explicit public functionality | Document composition |
| Extra arc digits or an error-bounded serializer | Changes precision expectations or needs another budget | Defer |
| Arc fitting, straightening, merging, or removing segments | Changes approximation, parameterization, or structure | Keep explicit and defer new behavior |
| Style-dependent removal or closure changes | Requires SVG document context | Keep outside the serializer |

## Opportunities without changing the API

### Compare two existing whole-path outputs

A caller interested only in output size can serialize once with absolute
commands and once with relative commands, then select the shorter string. Use
the same decimal, shorthand, whitespace, and repetition settings for both.
The caller chooses the coordinate policy explicitly; the serializer continues
to honor its Boolean option.

This is less powerful than switching coordinate modes per segment, but requires
no new function or option. It also avoids silently changing the relative mode
of `minifying_options`. A future documented recipe should state that decimal
rounding and relative accumulation can produce different last-bit results, so
shorter output is not automatically the more accurate output. The follow-up experiment saved 34 bytes across 21 of 180 paths; see
[POLICY_EXPERIMENTS.md](POLICY_EXPERIMENTS.md).

### Compare command runs within one coordinate mode

The current initial-line choice compares only the move-plus-first-line prefix.
A future internal experiment could compare legal alternatives over a short run,
including the cost of command letters, omitted repetitions, and separators.
It must still honor `use_h_v`, `use_s_t`, `repeat_commands`, explicit initial
lineto settings, and the selected absolute or relative mode.

This is a plausible extension of the current compact-formatting policy. It
needs no new public option if restricted to existing permitted spellings. Use
strictly shorter output as the acceptance criterion and keep current output on
ties. Candidate states must describe what the emitted text makes the parser
remember, particularly after rounding and reflected-control shorthand. A fixed
lookahead is preferable to an unbounded search unless measured savings justify
more complexity.

### Compose existing normalization explicitly

`svg_path.path_normalize_svg_arcs` already converts zero-radius arcs to lines
and omits coincident-endpoint arcs according to SVG semantics. Fixture 26 can
use this operation before transformation or serialization; no additional API
is needed. Keep this an explicit caller choice because parse/serialize can also
serve callers who want to preserve their segment representation.

## Mixed coordinate selection should wait

Fixtures such as 01:6, 04:3, and 05:3 expose savings from mixing absolute and
relative commands. The implementation would choose among command candidates
while tracking the current point, subpath start, and previous controls as a
parser sees them. Rounding compensation is part of that calculation, not an
independent final formatting step.

The obstruction is contractual: `relative: True` currently asks for relative
commands, and `False` asks for absolute commands. Neither value means automatic
selection. Reinterpreting compact mode or a special combination of existing
fields as an undocumented third coordinate mode would be a behavior break,
even without changing the record type.

If this is revisited, first decide whether automatic selection belongs in a
separate optimizer or an explicit coordinate policy. No API shape needs to be
selected now. The whole-path comparison recipe above is the available interim
approach.

## Exact degree reduction deserves a separate decision

Fixture 35 is a particularly concrete candidate: the cubic with controls
P0=(0,12), P1=(4,4), P2=(8,4), P3=(12,12) is the same polynomial as the quadratic
with control Q=(6,0). The two formulas

- Q1 = (3 P1 - P0) / 2
- Q2 = (3 P2 - P3) / 2

agree. In exact arithmetic this reduction preserves position at every parameter,
not just the traced shape. It is different from replacing a merely collinear
cubic with a line, which can change speed or remove backtracking.

An internal compact serializer could theoretically emit Q without adding an
option. However, that would introduce a new expectation: a cubic may parse back
as a quadratic. The present options authorize H/V and S/T shorthand, but do not
explicitly authorize polynomial degree changes. My recommendation is to retain
C for now and treat this as a potential documented policy, not an automatic
consequence of compact whitespace.

Before adoption, an experiment would need conservative numerical eligibility,
checks of the rounded emitted polynomial, and correct handling of subsequent
S/T commands. Equality of two computed floating-point controls alone is not a
proof of exact reduction: rounding can hide a difference. An arbitrary epsilon
would make this approximate reduction and would need an error policy. A caller
recipe constructing a quadratic for an independently known reducible cubic can
already use the existing segment types.

## Arc accuracy is a different objective from byte count

Fixtures 11:19 and 11:24 expose sensitive endpoint-form arcs near a semicircle
or radius-correction threshold. In 11:24, the sampled displacement at precision
3 was about 0.28672 coordinate units. Higher decimal precision did not yield
monotonically smaller measured error in every probe. See the numerical
investigation in [REMAINING_FIXTURES.md](REMAINING_FIXTURES.md).

The immediate API-preserving improvement is documentation: decimal places are
not a geometric error bound. Callers can already request more digits, but that
is not a certified accuracy policy.

Silently emitting extra digits would violate an `AtMost` or `Fixed` request.
Splitting an arc changes segment structure and marker locations. Smart radius
rounding (fixture 33) and flat-arc replacement (fixture 32) deliberately trade
geometry for fewer bytes. These should not be attached to whitespace
minimization. A future geometry-bounded mode would need units, treatment of
transforms, a validation method, and defined failure behavior when its budget
cannot be met. Finite point sampling alone cannot certify such a bound.

## Structural and styling changes remain outside compact formatting

Zero-length segments, empty subpaths, semantic closure, and intermediate
vertices can matter to callers even when their fill geometry looks unchanged.
They can also affect stroke caps, joins, dashes, and markers. Fixtures 03,
22–23, 27–30, and 37–39 illustrate why a path-only serializer cannot copy every
SVGO deletion or closepath substitution.

Likewise, cubic-to-arc fitting in fixtures 14–15, straight-curve reduction in
08 and 40, and collinear merging in 30 need explicit structural or approximation
policies. A shape-preserving result does not necessarily preserve segment
indices or parameterization. Existing explicit normalization functions are a
better model than introducing these operations silently during serialization.

## Suggested next steps

1. Keep the completed level 1/2 changes and the current API.
2. Add caller guidance for whole-path coordinate comparison, explicit arc
   normalization, and the limits of decimal precision.
3. Retain the command-run experiment as evidence. Its restricted H/V-to-L
   search found no savings; do not add that search to production.
4. Keep exact degree reduction as a separate policy discussion. Defer mixed
   coordinates, geometric error budgets, and structural simplification.

For any future experiment, retain the baseline output, independently parse the
candidate, test both targets, and compare size and runtime. Verification should
match the claimed preservation: command spelling, polynomial parameterization,
and approximate geometry require different checks. No implementation or API
change is proposed as a prerequisite for the next release.
