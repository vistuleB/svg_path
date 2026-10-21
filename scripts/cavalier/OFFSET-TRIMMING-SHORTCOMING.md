# Known shortcoming: open offsets can disappear after trimming

Recorded 2026-10-20 following the Cavalier Contours audit and discussion of
CC01301. Accepted as a current-policy shortcoming, not a pending localized bug
fix. No replacement contract or API design has been selected.

## Observable behavior

CC01301 constructs an extra left-hand arc that passes winding classification,
but forced parity cleanup removes it after an attached arc fails winding
classification. Cavalier retains a separate open fragment instead. See
[the stage investigation](CC01301-FRAGMENT-POLICY.md).

A simplified follow-up makes the outcome more apparent: an open source with
three straight segments has two round joins sweeping approximately 140° and
180°, leaving a 40° gap in the near-circular excursion. With offset distance
81, the untrimmed result contains that excursion and a straight offset run.
Default trimming returns an empty Path (zero subpaths).

The source vertices are:

```text
(-0.000766044443118978, 0.0006427876096865392)
(0, 0)
(-0.001, 0)
(62.6, 0)
```

The native call uses signed offset -81, Round joins, Butt caps, default fitting
options, and `SingleOffsetTrimming(True, InBandTrimming)`. The untrimmed control
uses `SingleOffsetTrimming(False, NoTrimming)`. This is a derived audit example,
not an original upstream fixture. Both calls succeed; an empty result is not an
exception or a construction failure.

## Interpretation and disposition

This behavior is not intuitive as a geometric offset. The present winding and
parity policy was designed to accommodate joins beyond Round; preserving any
plausible-looking partial run is not its current contract. Permitting selected
new endpoints or changing how rejected edges affect connected runs would need
a deliberate trimming-contract design and checks across join styles.

Retain the existing behavior for now. Do not introduce a special case for this
fixture, silently alter default trimming, or treat this record as an approved
API proposal. The user explicitly accepted documenting the limitation and
has not selected a replacement contract. Any future proposal should explain
which fragments survive, where new open ends are permitted, and how this works
for non-round joins. No version or release commitment is made here.

## Evidence and reproduction

- `probe-offset-turn-gap.mjs`: actual public API calls for both modes.
- `offset-turn-gap.json`: saved source and outputs; trimmed result is `[]`.
- `draw-offset-turn-gap.py`: renders the saved results, with a magnified source.
- [Preview](../../examples/debug/offset-turn-gap.svg).
- [Original CC01301 comparison](../../examples/debug/cc01301-fragment-policy.svg).

```sh
node scripts/cavalier/probe-offset-turn-gap.mjs > scripts/cavalier/offset-turn-gap.json
python3 scripts/cavalier/draw-offset-turn-gap.py
```

The probe uses the existing portable JavaScript build. No production edits,
full-suite rerun, or F# changes were made for this documentation.
