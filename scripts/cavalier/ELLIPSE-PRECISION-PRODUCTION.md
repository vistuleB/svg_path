# Selective ellipse precision in production — 2026-10-20

The unequal-radius endpoint converter now applies the conditioning-weighted
cutoff from `ELLIPSE-PRECISION-THRESHOLD.md` before correcting radii. Selected
cases use `src/svg_path/internal/ellipse_precision.gleam`; ordinary cases retain
the existing calculation. Circular arcs retain their separate rotation-independent
conversion. No public options, result types or tolerance semantics change.

## Numerical scope

The fallback uses double-double arithmetic for trigonometry, rotated coordinates,
radius correction and center construction. Start and swept angles are reconstructed
from the resulting normalized vectors; the swept angle uses their compensated
cross product and dot product. Final coordinates and angles are ordinary floats.

An exact power-of-two scale bounds the intermediate magnitudes. The fallback
requires maximum endpoint/radius magnitude between 1e-150 and 1e150, and each
radius at least 1e-30 times that magnitude. Inputs outside this implementation
range retain the previous conversion. This is a precision improvement, not exact
arithmetic or a guaranteed error bound. The empirical threshold derivation and
its limitations remain documented in `ELLIPSE-PRECISION-THRESHOLD.md`.

The ordinary path reuses its existing rotated half-chord and trigonometry when
checking the cutoff. Only selected cases pay for normalization and the
higher-precision kernel.

## Permanent regressions

`test/svg_path_ellipse_precision_test.gleam` contains four portable tests:
64 independent expected-center fixtures (16 inputs and all four arc flag pairs),
endpoint reconstruction and flag checks, 16 cutoff-boundary cases, and range
guards. The module is selected in `test_portable/modules.txt`.

## Validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
passed: 2,092 ordinary, 31 slow, 838 portable Erlang and 838 portable JavaScript
tests. See `ellipse-precision-test-release.log`.

`check-production-ellipse-precision.mjs` replays 3,274 grid inputs against the
compiled production JavaScript. All dispatch decisions match the experiment.
Maximum relative endpoint reconstruction error is 1.82e-15. On the 383-input
independent oracle subset, maximum center error against the oracle rounded to
binary64 is 4.59e-13 relative to the larger radius. These are diagnostic targets,
not new public guarantees. See `ellipse-precision-production.json`.

The same script times complete conversions against the pre-change compiled
JavaScript, with 3,000 warmups and seven alternating-order 10,000-call samples.
Median ordinary conversion time changed from 500 ns to 570 ns (~14% overhead).
The 16 difficult audit inputs changed from 619 ns to 6,840 ns (~11x).
These are local microbenchmarks, not end-to-end library timings. The 72 ordinary
controls do not enter the precision fallback. Their overhead is the cutoff check.
The earlier implementation duplicated common calculations and measured ~50%
ordinary overhead; reusing the half-chord removed most of that cost.
F# remains deferred until the Gleam audit is complete.

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/generate-published-figures`
completed successfully, including another 2,092-test ordinary run. All 47
published SVGs (13 README and 34 Gallery) are byte-for-byte identical to the
pre-change hashes. See `ellipse-precision-figures.log` and
`ellipse-precision-figure-comparison.json`.

Formatting and `git diff --check` passed. `python3 scripts/cavalier/validate-records.py`
verified the pinned archive, 2,866 case/results pairs and 287 test records.
This closes the identified unequal-radius conversion accuracy repair for the
audited inputs; broader catalogue and coverage closure remain separate work.
