# Changelog

This changelog was reconstructed from published Hex versions, git history,
`gleam.toml` version bumps, commit subjects, public module diffs, and
README/test changes.

Published versions begin at `0.1.0`; repository tags begin at `v0.3.0`. A few
older tags are attached just before the matching `gleam.toml` version bump; in
those cases the entries below follow the published release/version history
rather than only the tag object.

## 0.36.0 - 2026-08-10

### Changed

- Reduced the supported `svg_path/ellipse` API by internalizing affine and
  collapsed-arc transformation helpers used only by `svg_path/transform`.
- Added deterministic cross-scale stress coverage for curve evaluation,
  intersections, overlaps, convex hulls, transforms, and CSG topology.

## 0.35.0 - 2026-08-10

### Changed

- Standardized validation of geometric and parameter tolerances, including
  finite-value checks and validation before empty-input fast paths.
- Made point, transform, congruency, area, Bezier-feature, and convex-circle
  calculations more stable across very small and very large coordinate scales.
- Made winding, arrangement drawing, and CSG boundary directions recover from
  singular derivatives by using the package's one-sided direction logic.
- Centralized finite-number checks and transform number formatting.
- Expanded the README and API documentation for direction queries, geometry
  conversions, graceful transforms, and numeric option contracts.

### Fixed

- Enforced SVG transform separators and bounded SVG numeric parsing without
  losing valid exponents or emitting invalid scientific Gleam literals.
- Corrected basic ellipse placement, equivalent ellipse-axis comparison, and
  scale-invariant affine fitting.
- Preserved overlap boundaries while clipping and cutting, deduplicated closed
  clipping seams, and compared arrangement cuts geometrically.
- Preserved small dash intervals, rejected overflowing dash patterns, and
  validated empty-path cuts and custom wiggle tolerances.
- Preserved smallest-enclosing-circle minimality and stabilized large-distance,
  centroid, RMS-error, and near-identity transform calculations.
- Corrected ambiguous and singular direction arrows in arrangement and CSG
  drawings, then regenerated the published Gallery fixtures.

## 0.34.0 - 2026-08-07

### Added

- Added `transform.path_gracefully`, the path-level counterpart of
  `transform.subpath_gracefully`, for transforms that may collapse arcs into
  line geometry.

### Changed

- Completed the configurable-function naming convention by renaming
  `inspect.point_with_options`, `inspect.point_code_with_options`, and
  `transform/serialize.to_string_with_options` to their corresponding `_with`
  names.
- Revised the package description to summarize parsing, serialization, and
  computational geometry without enumerating individual features.

## 0.33.0 - 2026-08-06

### Added

- Added subpath distance queries, path-level marker poses, and subpath-level
  direction-arrow drawing helpers to complete their segment/subpath/path
  function families.

### Changed

- Renamed `subpath_clean` to `subpath_normalize_zero_length_lines` to state its
  narrow normalization contract explicitly.
- Standardized configurable serializer and inspector function names by
  replacing their `_with_options` suffixes with `_with`.
- Simplified internal overlap sampling names and separated production segment
  projection into analytic line, sampled arc, and polynomial Bezier paths.
- Removed the retired general Bezier sampling comparison path while retaining
  fixed and numerical-quality projection regressions.

## 0.32.0 - 2026-08-06

- Renamed the public `svg_path/arrangement_graph` module to the shorter
  `svg_path/arrangement`, and renamed its drawing submodule accordingly. The
  public `ArrangementGraph` and `ArrangementGraphBuild` type names are
  unchanged.
- Expanded the README introduction to describe native curve preservation,
  arrangement construction, fill-rule-aware Boolean semantics, and the
  package's broader geometry operations.
- Added references to the standard planar-arrangement model and SVG fill-rule
  semantics underlying those APIs.

## 0.31.0 - 2026-08-06

### Added

- Added singularity-safe segment and subpath direction queries, with explicit
  tolerances for recovering directions when endpoint derivatives vanish.
- Added after-the-fact subpath intersection classification for transverse
  crossings, nontransverse contacts, endpoint contacts, and indeterminate
  cases, including traversal apertures and equal-arc-length contact ordering.
- Added total widening conversions from segments to subpaths and paths, and
  from subpaths to paths.
- Added the MIT license file and parser error suffixes that preserve the
  unconsumed input at the point of failure.

### Changed

- Standardized public names for option defaults, normalization operations, and
  error variants, while reducing the internal API surface.
- Simplified convex-hull construction failures to one public error while
  retaining detailed construction diagnostics internally.
- Split ordinary and stress tests into independent fast and slow profiles used
  together by the release test command.

## 0.30.0 - 2026-08-05

- Removed the `gleam_community_maths` runtime dependency; `svg_path` now depends
  only on `gleam_stdlib`.
- Added local Erlang and JavaScript trigonometry bindings used by the public
  degree-based helpers and internal numerical geometry tests.
- Added cross-backend trigonometry coverage and updated standalone examples to
  avoid unnecessary direct dependencies.

## 0.29.2 - 2026-08-05

- Replaced scale-dependent cubic chord-tangency scanning in convex-hull
  construction with normalized polynomial root isolation.
- Added analytic chord-tangency regressions across parameter locations and
  geometry scales, together with figure-eight, offset-band, and combined-hull
  support tests.

## 0.29.1 - 2026-08-05

- Added `point.clockwise_aperture` and reused the point module's heading and
  direction helpers in CSG and convex-hull calculations.
- Added one canonical command for regenerating every published README and
  Gallery figure from current code.
- Regenerated all five README figures and all thirty Gallery figures, including
  current ArrangementGraph annotations for the CSG panels.

## 0.29.0 - 2026-08-05

### Added

- Added `svg_path/encounters` for combined overlap and isolated
  point-intersection queries between segments, segment-subpath pairs,
  subpaths, and paths.
- Added segment-subpath and path overlap values with complete piecewise-affine
  parameter correspondences and exact opposite-parameter lookup helpers.
- Added ordered source-segment images to `ArrangementGraphBuild`, identifying
  the atomic graph edges produced from every normalized source segment.
- Added canonical fast, slow, and release test profiles and documented the
  parser-conformance boundaries covered by the imported SVG fixtures.

### Changed

- Required every reported segment overlap to have an affine, monotone
  parameter correspondence; unsupported multiply traced or non-monotone
  correspondences now return `NonAffineOverlapCorrespondence`.
- Changed offset overlap filtering to use arrangement-graph segment images
  instead of independently rediscovering overlaps in the offset geometry.
- Changed cubic projection to isolate stationary-distance polynomial roots and
  refine them with bisection, while consolidating shared polynomial root logic.
- Refined cubic convex-hull tangency and chord normalization using isolated
  polynomial roots.
- Reduced the public overlap and encounter API to the supported query,
  correspondence, and explicitly derived filtering operations.

## 0.28.0 - 2026-08-02

- Added contextual parsing and minimized serialization of compact arc flags.
- Enforced SVG comma placement and recognized form-feed as path whitespace.
- Applied SVG arc normalization for negative radii, zero radii, and identical
  endpoints.
- Added parser-conformance cases adapted from Web Platform Tests and the W3C
  SVG 1.1 Second Edition test suite.

## 0.27.0 - 2026-08-02

- Added parser-tracked relative serialization that compensates for accumulated
  decimal-rounding drift while preserving horizontal and vertical lines.
- Added `explicit_initial_lineto` so the first line endpoint may be encoded as
  an additional moveto coordinate pair.
- Expanded `minimize_whitespace` to use signed-number and decimal boundaries
  and to omit leading zeroes from fractions.
- Extended the parser to accept leading-dot and adjacent decimal numbers
  emitted by minimized serialization.

## 0.26.1 - 2026-08-01

- Added proportional ArrangementGraph drawing options so nodes, edge strokes,
  arrowheads, and annotations scale together.
- Stopped graph arrowheads at the visible node boundary and added independent
  arrow length, width, opacity, and arrival controls.
- Rebuilt the README ArrangementGraph figures through reproducible generators
  and moved the eight-panel fill-rule comparison from the Gallery into the CSG
  documentation.

## 0.26.0 - 2026-08-01

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

## 1.0.0 - 2026-07-30 (withdrawn)

- Published briefly as a stable snapshot of the API developed through 0.23.0.
- Withdrawn from Hex; subsequent development resumed on the 0.x version line
  with 0.24.0.

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
