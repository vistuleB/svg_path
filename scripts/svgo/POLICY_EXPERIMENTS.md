# Serializer policy experiments

2026-10-14, following `9a8db05`. The result supports a caller recipe for choosing
one coordinate mode for a whole path. The tested command-run search does not
justify a production change. The serializer implementation and public API are
unchanged by this follow-up.

## Whole path coordinate comparison

For each of the 180 valid paths in the pinned SVGO fixture corpus, serialize
with `minifying_options` at its existing precision, then serialize again with
only `relative` set to false. Compare lengths and keep relative output on ties.
All transformed inputs use the same explicit normalization and transformation
as the original audit.

Absolute output wins for 21 paths, saving 34 bytes across the corpus. Choosing
between the two gives 6,189 bytes, compared with 6,223 for relative output alone.
This is an optional caller policy, not the new output of `minifying_options`.
Both forms are independently parsed; the experiment does not assert that their
rounding errors are identical or that shorter output is geometrically closer.
The corpus is not a representative compression benchmark.

The tested `smaller_path_data` recipe in `test/readme_recipes.gleam`, reproduced
in the README, implements this policy without a new library function. Its test
covers absolute and relative wins and retaining relative on a tie. All emitted
characters are ASCII, so string length is also the UTF-8 byte count. The recipe
requires two serialization calls; it is intended for callers who prefer the
size saving to the additional work.

## Restricted command run search

The probe starts from the current relative output, independently tokenized by
SVGO. For each h/v command it considers retaining that command or writing the
same displacement as l with one zero component. A dynamic program retains the
shortest prefix for each preceding command letter, accounting for omitted
repetitions and the implicit lineto after moveto. Curves, arcs, coordinate mode,
segment order, and numeric values remain unchanged.

The original and candidate command sequences use the same conservative encoder.
It does not reproduce every production numeric spelling or packed arc flag;
the comparison isolates command choice under that encoder. Both sequences are
parsed by our library, and the candidate is also independently expanded through
SVGO's parser. Numerical comparisons allow 1e-12 relative/absolute floating-point
parsing differences. The encoded original is checked against the production
output as well.

Across 180 paths, the search saves zero bytes. H/V already avoid a coordinate;
replacing them with L adds a zero and possibly a separator, offsetting the
opportunity to omit a command letter. This is evidence against this particular
search, not proof that every possible command optimization is exhausted. No
search is being added to the library, and no runtime benefit is claimed.

## Documentation retained

The README now explains the two-call recipe, explicit composition with
`path_normalize_svg_arcs`, and why decimal places do not bound geometric error.
The `decimal_options` API documentation also notes arc sensitivity. No implicit
normalization, extra precision, degree reduction, approximation, or mixed
coordinate selection was introduced.

## Reproduction

Use the JavaScript build from `scripts/test-portable javascript fast`, then run:

```sh
node scripts/svgo/policy-experiments.mjs
```

The locked SVGO dependency must already be installed as described in the audit
README. Results are written separately to `policy-experiments.json`; the earlier
baseline reports are preserved. The script checks all 180 valid cases and
records per-case size differences. It is an audit probe, not a new CI suite.
