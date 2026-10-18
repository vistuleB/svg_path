# Cavalier Contours core-suite inventory

Pinned revision and provenance: `README.md`. Per-test detail: `TEST-COVERAGE.md`.
All core files are inventoried; selected-operation capture is not full assertion coverage.

| Source | Upstream tests | With selected captured operations | Without selected captures |
| --- | ---: | ---: | ---: |
| `src/core/math/base_math.rs` | 2 | 0 | 2 |
| `src/core/math/vector2.rs` | 1 | 0 | 1 |
| `src/polyline/internal/pline_intersects.rs` | 27 | 22 | 5 |
| `src/polyline/internal/pline_offset.rs` | 23 | 11 | 12 |
| `src/polyline/internal/raw_pline_offset.rs` | 14 | 10 | 4 |
| `src/polyline/pline_seg.rs` | 12 | 12 | 0 |
| `tests/test_circle_circle_intersect.rs` | 6 | 6 | 0 |
| `tests/test_line_circle_intersect.rs` | 13 | 13 | 0 |
| `tests/test_line_line_intersect.rs` | 14 | 14 | 0 |
| `tests/test_pline_basics.rs` | 13 | 7 | 6 |
| `tests/test_pline_boolean.rs` | 35 | 35 | 0 |
| `tests/test_pline_contains.rs` | 6 | 6 | 0 |
| `tests/test_pline_parallel_offset.rs` | 82 | 82 | 0 |
| `tests/test_pline_seg_intersect.rs` | 22 | 22 | 0 |
| `tests/test_pline_view.rs` | 5 | 4 | 1 |
| `tests/test_pline_winding_number.rs` | 6 | 6 | 0 |
| `tests/test_shape_parallel_offset.rs` | 6 | 6 | 0 |

The 31 uncaptured tests and assertion-level gaps are explicitly discussed in `REVIEW.md`. FFI, UI, examples and doctests are outside this collection.
