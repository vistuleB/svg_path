# Changelog

This changelog was reconstructed from published Hex versions, git history,
`gleam.toml` version bumps, commit subjects, public module diffs, and
README/test changes.

Published versions begin at `0.1.0`; repository tags begin at `v0.3.0`. A few
older tags are attached just before the matching `gleam.toml` version bump; in
those cases the entries below follow the published release/version history
rather than only the tag object.

## Unreleased

### Added

- Added `svg_path/arrangement_graph`, a transparent planar arrangement built
  from normalized source paths, atomic non-intersecting edges, endpoint
  clusters, and directional overlap multiplicities.
- Added reusable ArrangementGraph drawing helpers with edge direction,
  multiplicity, vertex, and winding-level annotations.
- Added graph-based Boolean union, intersection, difference, and symmetric
  difference under both SVG fill rules.
- Added `csg.monotone_contours` for reconstructing nested or disjoint contours
  while preserving the complete signed integer winding field.
- Added `svg_path/overlaps` for segment and subpath overlap intervals, including
  interval canonicalization and merging helpers.
- Added deterministic smallest-enclosing-circle endpoint clustering.

### Changed

- Changed CSG operations to return `CsgResult`, containing both the result path
  and the exact `ArrangementGraphBuild` used to derive it.
- Changed CSG construction to normalize line-degenerate segment sequences,
  refine intersections and overlap boundaries, classify atomic edges by their
  winding fields, and trace filled-sector boundary cycles.
- Made segment overlap detection geometric rather than dependent on structural
  equality of segment fields or matching original subdivision points.
- Enforced one shared overlap classification contract across
  `intersections.segment` and `overlaps.segment` at matching tolerances.
- Improved segment projection termination for small parameter windows and
  corrected distance-candidate evaluation near window boundaries.
- Changed endpoint-cluster representatives from insertion-order averaging to
  deterministic smallest-enclosing-circle centers.
- Refined ArrangementGraph and CSG option, validation, and internal-topology
  errors.
- Built offset sections across complete paths and split them at overlap
  endpoints.

### Removed

- Removed the superseded occurrence-ID and legacy CSG implementations.
- Removed `csg.simplify_nonzero_output`; current Boolean operations reconstruct
  only edges separating filled and unfilled output sectors.

### Fixed

- Fixed overlap detection for geometrically equal arcs with different SVG arc
  fields or phase-shifted arc subdivisions.
- Fixed arc subdivision searches that could fail to terminate after the
  parameter interval was already below the requested tolerance.

## 0.25.0 - 2026-07-30

- Added conversion of degenerate segment sequences into equivalent line
  traversals.
- Reported finite endpoint intersections for non-degenerate arcs whose start
  and end points coincide.

## 0.24.0 - 2026-07-30

- Moved point-intersection implementation and options into the public
  `svg_path/intersections` module.
- Added segment, subpath, and path self-intersection APIs and restored their
  slower regression coverage.
- Extended endpoint policies with caller-supplied reconciliation functions.
- Renamed the number-formatting module to `svg_path/format`.
- Stopped ordinary visual tests from writing generated artifacts during the
  test suite.

## 0.23.0 - 2026-07-30

- Renamed low-level Bezier and ellipse point types to `BezierPoint` and
  `EllipsePoint` to avoid suggesting they are the public root `Point` type.
- Added root-module convenience wrappers for common ellipse arc evaluation and
  cubic fitting helpers.
- Renamed graceful transform helpers for clearer segment and subpath behavior.
- Clarified point helper and CSG documentation before the stable release.

## 0.22.0 - 2026-07-30

- Removed the `vec` package dependency.
- Added `svg_path/point` as a small helper library for the root `Point` type.
- Used point helpers internally where they made the code clearer.

## 0.21.1 - 2026-07-29

- Added `coordinates` for destructuring `Point` values through a helper
  function.

## 0.21.0 - 2026-07-28

- Added serializer minifying options.
- Used `H`/`V` and smooth `S`/`T` path commands by default when they shorten
  serialized output.
- Trimmed the recursive dash gallery source and refreshed pre-1.0 notes.

## 0.20.0 - 2026-07-27

- Added `svg_path/marker` helpers for SVG marker poses and marker layout
  transforms, including marker units, `orient`, `refX`/`refY`, and
  viewBox/preserveAspectRatio fitting.
- Added marker gallery figures for pose slots, orientation, reference points,
  marker units, and viewBox fitting.
- Audited stroke cap and join behavior against SVG painting semantics.

## 0.19.0 - 2026-07-25

- Normalized public root-module API prefixes so segment, subpath, and path
  helper families use consistent names.

## 0.18.0 - 2026-07-25

- Added fallible point mapping helpers and segment/subpath/path subdivision by
  maximum arc length.
- Added `offset.subpath_offset_map` for mapping `(distance, offset)` coordinates
  onto an offset of a source subpath.
- Added parametric subpath fitting from sampled functions into cubic Bezier
  sequences.
- Added Khmer coil and decaying-spiral offset-map gallery figures.
- Added crescent hull and cut-radiator gallery figures.

## 0.17.2 - 2026-07-23

- Refactored offset builders and exposed fitting options for stalled offset
  pieces.
- Added stalled-offset gallery figures for circular and cubic quarter-turn
  cases.
- Allowed custom offset connector policies to return multiple connector
  segments.

## 0.17.1 - 2026-07-22

- Fixed split endpoint preservation for segments and arcs.
- Repaired offset boundary healing so band and stroke output share the same
  contour normalization path.
- Added recursive dash gallery fixtures.

## 0.17.0 - 2026-07-21

- Added SVG-style dasharray normalization, dashoffset handling, dash extraction,
  and dashed stroke geometry.
- Added public path cutting helpers and intersection parameter
  canonicalization.
- Added subpath clockwiseness helpers.

## 0.16.0 - 2026-07-20

- Added `svg_path/offset` with segment, subpath, and path offset construction
  for lines, Beziers, and arcs.
- Added trimmed and untrimmed band helpers, including asymmetric offset bands.
- Added `svg_path/stroke` for constructing filled stroke outlines with butt,
  round, and square caps.
- Added absolute winding area helpers.
- Added the public gallery seed file.

## 0.15.1 - 2026-07-19

- Added best-fit congruency helpers for ordered points, segments, subpaths, and
  paths, with `Similar` and `Affine` transform families and RMS error reporting.
- Added cubic Bezier tangent fitting helpers.
- Added early segment and subpath offset construction, plus capless offset band
  helpers.
- Shortened README API detail sections and split large geometry tests.

## 0.15.0 - 2026-07-17

- Added `svg_path/clip` for clipping curve geometry to a filled path region
  without inserting closure or bridge segments from the clipping boundary.
- Added clipping tests for open paths, closed paths, arcs, vertex-boundary
  intersections, and subpath ordering.
- Added Paper-style table-driven CSG operation tests covering union,
  intersection, and both difference directions.
- Documented curve clipping as distinct from filled-path CSG.

## 0.14.2 - 2026-07-17

- Regenerated CSG README figures from the current implementation.
- Preserved natural closed source contours for `union` with `Nonzero` fill
  when input subpaths are closed.

## 0.14.1 - 2026-07-17

- Removed the README difference-asymmetry CSG figure and its generated visual
  fixture.
- Tightened README figure workflow notes for `markdown-assets`.

## 0.14.0 - 2026-07-17

- Added `csg.simplify_nonzero_output` for removing internal contour-depth
  boundaries from CSG results while preserving the `Nonzero` filled set.
- Added rounded-corner path effects and generated fixtures showing raw CSG
  contour output before and after rounding.
- Refined generated CSG README figures and orientation arrows.

## 0.13.2 - 2026-07-16

- Changed Nonzero CSG output to preserve contour-depth level boundaries inside
  results instead of collapsing to a minimal filled outline.
- Added tests that check preserved Nonzero union depth for same-direction and
  reversed internal contours.
- Improved generated CSG documentation figures so rounded contours and
  per-subpath stroke colors make contour-depth boundaries easier to read.

## 0.13.1 - 2026-07-16

### Fixed

- Replaced inline CSG README diagrams with raw SVG image references that render
  consistently on Hex.
- Added generated, scratch-style CSG explanation fixtures so README diagrams
  are produced from actual library output with arrows and labels added as
  annotation.

## 0.13.0 - 2026-07-16

### Added

- Added `svg_path/csg` with path-level `union`, `intersection`, and
  `difference` operations under an explicit SVG fill rule.
- Added generated CSG visual fixtures covering overlaps, containment, tangent
  contacts, nested paths, curves, and self-intersecting input.

### Changed

- Documented CSG fill-rule semantics, returned-path policy, and implementation
  limits in the README.

## 0.12.0 - 2026-07-16

### Added

- Added path-level nearest-point projection and distance helpers, including
  `PathProjection` and configurable `_with` variants.
- Added tolerance-controlled straight-line approximation for segments,
  subpaths, and paths through the `segment_to_lines`, `subpath_to_lines`, and
  `path_to_lines` function families.
- Added grouped segment-to-subpath intersection helpers that retain every
  corresponding `SubpathParameter`.
- Added `Nonzero` and `EvenOdd` point containment for open or closed subpaths
  and complete paths, with explicit `Inside`, `Outside`, and `Boundary`
  results.
- Added `svg_path/area` for exact signed area helpers and SVG fill-rule area
  for subpaths and paths.
- Added subpath-to-subpath intersection helpers that retain every
  corresponding parameter on both subpaths.
- Added path-to-path intersection helpers and `compare_path_parameters`.

## 0.11.0 - 2026-07-16

### Added

- Added nearest-point projection for segments and subpaths, including public
  projection result types and configurable numerical options.
- Added adaptive segment, subpath, and path length measurement through
  `LengthOptions`.
- Added true-distance parameter, point, and derivative lookup for segments,
  subpaths, and paths, including the public `PathParameter` type.
- Added segment and subpath extraction and splitting by traveled distances
  through the `between_lengths` helper family.

### Changed

- Renamed the segment and subpath `sub_*` extraction helpers to the
  `segment_between`, `segments_between`, `subpath_between`, and
  `subpaths_between` families.

### Documentation

- Added a README module map for the library's public modules.

## 0.10.0 - 2026-07-15

### Added

- Added subpath parameter evaluation helpers: `subpath_point`,
  `subpath_derivative`, and `from_end_parameter`.
- Added closed-subpath opening at arbitrary subpath parameters through
  `open_at`.
- Added runnable congruency examples and an examples directory guide.

### Changed

- Updated `open_at` to accept a `SubpathParameter` instead of only a segment
  index.
- Updated closed `sub_subpaths` behavior so a single split point returns one
  open loop.

### Documentation

- Documented subpath interval helper roles and congruency limitations.
- Clarified that `Arc.x_axis_rotation` is in degrees.

## 0.9.0 - 2026-07-07

### Added

- Added `svg_path/congruency` with ordered point, segment, subpath, and path
  congruency checks under translation, rotation, and uniform scale.
- Added `transform.point_pair_map` and `transform.point_triple_map` for
  constructing transforms from point correspondences.
- Added `svg_path/trig` degree-oriented trigonometry helpers.
- Exposed `ellipse.arc_center_data` for endpoint-to-center arc conversion.
- Added fixture tests for transformed path congruency and collapsed target
  point-pair mapping.

### Changed

- Switched public arc-angle semantics toward degrees, including center arc
  data, arc evaluation helpers, transform serialization, and generated
  fixtures.
- Removed duplicated lowercase constructors for public non-opaque data types,
  except where the helper remains useful for a type alias.
- Refactored congruency checks to use ordered point clouds and a sweep-based
  point-pair selection.
- Replaced square-root point tolerance checks with squared-distance
  comparisons and reused `vec/vec2f` for point distance calculations.

### Documentation

- Documented arc representations and the `ellipse` module in the README.
- Added `0.9.0` follow-up notes about library shape and next steps.

## 0.8.1 - 2026-07-07

### Added

- Added bounding box union helpers.
- Added point bounding boxes.
- Added `svg_path/basic_shapes` helpers for SVG primitive shapes such as
  rectangles, circles, ellipses, lines, polylines, and polygons.

### Changed

- Extended transform support for bounding boxes.

## 0.8.0 - 2026-06-28

### Changed

- Updated wiggle-path error reporting to use `Discontinuous` errors with
  previous/next segment indices and measured distance.
- Added coverage for wiggle rejection cases when start, continuation, or close
  gaps exceed tolerance.
- Bumped the package version to `0.8.0`.

## 0.7.6 - 2026-06-26

### Documentation

- Refined README text and image references around zero-length subpaths.
- Clarified notes for zero-length and closepath behavior.
- Annotated the zero-length subpath probe.

## 0.7.5 - 2026-06-25

### Added

- Added subpath splitting helpers: subpath parameters, parameter comparison,
  `split_subpath`, `sub_subpath`, and `sub_subpaths`.
- Added focused tests and debug probes around difficult convex hull tangent
  cases.

### Changed

- Updated README material around the new subpath splitting helpers.

## 0.7.4 - 2026-06-25

### Added

- Added `polyline`, `assert_polyline`, `polygon`, and `assert_polygon`.
- Added point-cloud convex hull APIs and configurable convex hull repair modes.
- Added convex hull diagnostics and expanded convex hull repair/tangent tests.
- Added SVG drawing helpers for richer debug output.

### Changed

- Included move-only subpaths in convex hull handling.
- Reworked convex hull repair, tangent insertion, prefiltering, fallback, and
  seeded search behavior for difficult cases.
- Reorganized README sections and fixed README examples and probe image links.

## 0.7.3 - 2026-06-24

### Added

- Added configurable left padding for serialization and inspection number
  formatting.

### Changed

- Replaced the older path cleanup helpers with the current cleanup API.
- Refined source docs and README organization.
- Adjusted parser, serializer, and number formatting internals around the new
  formatting options.

## 0.7.2 - 2026-06-24

### Changed

- Added explicit coverage for zero-length subpath edge cases.
- Refined README documentation for the zero-length and closepath behavior.

## 0.7.1 - 2026-06-24

### Documentation

- Documented zero-length subpath behavior, including the difference between
  move-only subpaths and closed zero-length subpaths.
- Bumped the package version to `0.7.1`.

## 0.7.0 - 2026-06-24

### Changed

- Changed empty subpaths to carry explicit start points.
- Updated parsing, serialization, transform, inspect, and core path handling to
  account for move-only subpaths.
- Documented closepath edge cases and normalized closepath semantics.
- Updated README material around the revised subpath representation.

## 0.6.2 - 2026-06-24

### Changed

- Removed duplicated lowercase constructor helpers for data types that can be
  constructed directly.
- Updated tests, examples, serialization fixtures, and debug drawings for the
  constructor cleanup.
- Bumped the package version to `0.6.2`.

## 0.6.1 - 2026-06-23

### Changed

- Fixed collapsed convex hull unions.
- Unified convex hull segment support behavior.
- Added fast and all-test helper scripts for working around slower convex hull
  tests.
- Added notes about the slow convex hull test setup.

## 0.6.0 - 2026-06-23

### Added

- Added convex hull support for segments, subpaths, paths, and point clouds.
- Added convex hull debug and experiment harnesses.
- Added `svg_path/svg` helpers for debug SVG drawings.
- Added anchored transform helpers for paths, subpaths, and segments.
- Added path combine helpers.
- Added segment interval helpers.
- Exposed cubic inflection parameters.
- Added comma coordinate serialization options.

### Changed

- Replaced the earlier segment hull prototype with a cubic solver-backed
  implementation.
- Refined number formatting and left-padding behavior.
- Documented segment hull failure modes and polished convex hull docs.

## 0.5.1 - 2026-06-22

### Documentation

- Edited the README introduction.
- Bumped the package version to `0.5.1`.

## 0.5.0 - 2026-06-21

### Added

- Added multiline path serialization options.
- Added `open_at` for closed subpaths.
- Added `clean_path`.
- Added bounding box measurement helpers.
- Added segment minimization and distance helpers.
- Added segment intersection helpers.
- Added custom endpoint policy support.
- Added the `number_format` module to share formatting behavior between
  serializers and inspectors.

### Changed

- Refactored decimal formatting option types.
- Reworked serialization and inspection number formatting.

## 0.4.0 - 2026-06-20

### Added

- Added `svg_path/bezier` and `svg_path/root`.
- Added bounding boxes for Bezier curves, arcs, segments, subpaths, and paths.
- Added arc endpoint/center data helpers and arc data constructors.
- Added segment evaluation, derivatives, splitting, point mapping, and crossing
  detection.
- Added path endpoint helpers.
- Added path and subpath reversal helpers.
- Added path and subpath point mapping helpers.
- Added generated Bezier and arc bounding box fixtures.

### Changed

- Renamed `Join` to `EndpointPolicy`.
- Replaced `concat` with list-based `join`.
- Renamed arc-to-cubic conversion helpers for clarity.
- Expanded README geometry documentation and package metadata.

## 0.3.0 - 2026-06-19

### Added

- Added subpath open and `set_closed` helpers.
- Added subpath join helpers and join policy options.
- Added assertion variants for subpath construction, append, splice, close, and
  closure operations.

### Changed

- Renamed segment append helpers.
- Reworked close/bridge helper naming.
- Prepared package documentation for the `0.3.0` release.

## 0.2.0 - 2026-06-19

### Added

- Added full SVG path parsing for line, quadratic, cubic, smooth curve, and arc
  commands.
- Added transform matrices, transform parsing, transform serialization, matrix
  tuple conversion, matrix multiplication, and convenience transform helpers.
- Added graceful transforms for collapsed arcs.
- Added arc-to-Bezier and segment-to-cubic conversion helpers.
- Added structural path inspection and copy-pasteable code inspection.
- Added assert subpath constructors and subpath splice helpers.
- Added repeat-command and compact-command serialization options.
- Added README examples and HexDocs comments.

### Changed

- Removed the `matrix_gleam` dependency after replacing it with local transform
  handling.
- Decoupled ellipse math from the core path types.
- Dropped redundant closing lines in serialization where appropriate.
- Used relative closepath commands in relative serialization.
- Added segment indices to discontinuity errors.

## 0.1.0 - 2026-06-18

### Added

- Added the core path model: `Path`, `Subpath`, `Segment`, and `Point`.
- Added constructors and accessors for paths, subpaths, segments, and points.
- Added continuity checking for subpath construction and append/close helpers.
- Added line, quadratic Bezier, cubic Bezier, and arc segment constructors.
- Added initial path serialization options.
- Added the first line-command parser.
