# Initial offset observations

> Current status (2026-10-18): projection fixes are committed as `dacdb370` and
> `090f8e63`; the original collection wording below is historical. See
> [RESUMED-TRIAGE.md](RESUMED-TRIAGE.md) and `triage-dispositions.json` for the
> latest dispositions. Raw baseline counts and results are preserved. Audit open; F# deferred.

All observations below are on Gleam JavaScript at `75970a6`, with default
construction/trimming and the adapter described in README.md. No production
code was changed. Original fixture names are stable references; no line links.

| ID | Upstream fixture | Observation | Current disposition |
| --- | --- | --- | --- |
| CC001 | `circle_collapsed_into_point` | Radius 1 offset inward by 1 returns `DegenerateTangent(0)`; upstream expects empty. All four variants agree. | Existing native degeneracy policy: `segment_rejects_collapsed_circular_arc_offset_test` explicitly expects this error at exact radius. Whether the higher-level trimmed subpath should discard it is an API-policy question; not yet a confirmed bug. |
| CC002 | `circle_collapsed` | Radius 1 offset inward by 2 returns a radius-1 circle; upstream expects empty. All four variants agree. | Unresolved trimming/offset contract discrepancy; investigate beyond-collapse handling before calling it a bug. |
| CC003 | `square_collapsed` | Square `[-1,1]²` offset inward by 2 returns two contours; upstream expects empty. All eight variants agree. | Unresolved trimming/offset contract discrepancy; investigate join and winding policy. |

For CC003, the original orientation produces signed areas -4 and approximately
1.2605869745, lengths 8 and approximately 4.1887902048. Raw results include
bounds and all reversed/cycled observations.

The other twelve nonempty fixtures match the compared properties (64 variant
observations), including exact square collapse, the collapsed rectangle that
retains a doubled line, ordinary open/closed rectangles and diamonds, and
inward/outward circles. The empty-polyline fixture has two scope observations.

No confirmed native correctness bug is claimed at this stage. The aggregate
comparisons omit vertex count, user data, repeated-position assertions and full
boundary equality; these omissions must not be reported as passing assertions.

## Broad collection follow-up

The initial collapse cases above remain part of the larger unresolved inventory.
See `DISCREPANCIES.md` and `discrepancy-queue.json` for every flagged representative,
not just these three. The broad pass also records:

- Boolean/offset arrangement and construction errors, including one multi-contour
  shape-offset case.
- Boolean contour-property differences, particularly XOR. Some can represent
  equivalent filled regions with different contour decomposition; not established
  as geometry bugs by aggregate comparisons.
- Projection/distance iteration-limit errors on circular arc inputs. Repeated
  distance thresholds reuse the same geometric queries, so counts overstate the
  number of independent inputs.
- Near-semicircle conversion/center/bounds differences and closest-point witnesses.
- Endpoint tolerance, tangent multiplicity, winding-boundary and negative-distance
  policy differences.

All remain inventory findings rather than approved fixes. Our explicit errors
are higher-priority investigation candidates; an error can still reflect an
input, adapter or documented numerical-policy difference. No conclusion of
native correctness failure follows from upstream success alone.

## First triage result

See [SIMPLE-TRIAGE.md](SIMPLE-TRIAGE.md). Five simple flags have non-bug
dispositions. A shallow-arc projection convergence defect is confirmed on both
Erlang and JavaScript, with a reduced native reproduction and an independent
analytic answer. Investigation stopped there; no fix has been implemented.
