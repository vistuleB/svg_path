# Changelog

This changelog was reconstructed from git history, `gleam.toml` version bumps,
tags, commit subjects, public module diffs, and README/test changes.

Tags begin at `v0.3.0`. The `0.1.0` and `0.2.0` sections are reconstructed
from the initial package version and the `0.2.0` version bump. A few older tags
are attached just before the matching `gleam.toml` version bump; in those cases
the entries below follow the intended release/version history rather than only
the tag object.

## Unreleased

### Added

- Added path-level nearest-point projection and distance helpers, including
  `PathProjection` and configurable `_with` variants.
- Added tolerance-controlled straight-line approximation for segments,
  subpaths, and paths through the `segment_to_lines`, `subpath_to_lines`, and
  `path_to_lines` function families.
- Added grouped segment-to-subpath intersection helpers that retain every
  corresponding `SubpathParameter`.

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
