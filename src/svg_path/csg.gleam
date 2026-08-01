//// ArrangementGraph-based operations on SVG paths.
////
//// Binary operations interpret both operands with one fill rule. The unary
//// `monotone_contours` operation instead preserves the complete signed integer
//// winding field and therefore takes no fill rule.

import gleam/result
import svg_path
import svg_path/arrangement_graph

const default_minimum_chord = 0.00001

/// Numeric options used while constructing and classifying an arrangement.
pub type Options {
  Options(tolerance: Float, minimum_chord: Float)
}

/// Return default ArrangementGraph CSG options.
pub fn default_options() -> Options {
  Options(tolerance: 0.000001, minimum_chord: default_minimum_chord)
}

/// Return the Boolean union of two paths under `using`.
pub fn union(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  union_with(left, right, using: fill_rule, options: default_options())
}

/// Return the Boolean union using explicit arrangement options.
pub fn union_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  use built <- result.try(arrangement_graph.build(
    [left, right],
    tolerance: options.tolerance,
    minimum_chord: options.minimum_chord,
  ))
  let arrangement_graph.BuildResult(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  arrangement_graph.union_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  )
}

/// Return the Boolean intersection of two paths under `using`.
pub fn intersection(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  intersection_with(left, right, using: fill_rule, options: default_options())
}

/// Return the Boolean intersection using explicit arrangement options.
pub fn intersection_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  use built <- result.try(arrangement_graph.build(
    [left, right],
    tolerance: options.tolerance,
    minimum_chord: options.minimum_chord,
  ))
  let arrangement_graph.BuildResult(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  arrangement_graph.intersection_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  )
}

/// Return `left` minus `right` under `using`.
pub fn difference(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  difference_with(
    left,
    minus: right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return `left` minus `right` using explicit arrangement options.
pub fn difference_with(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  use built <- result.try(arrangement_graph.build(
    [left, right],
    tolerance: options.tolerance,
    minimum_chord: options.minimum_chord,
  ))
  let arrangement_graph.BuildResult(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  arrangement_graph.difference_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  )
}

/// Return the Boolean symmetric difference of two paths under `using`.
pub fn symmetric_difference(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  symmetric_difference_with(
    left,
    right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return the Boolean symmetric difference using explicit arrangement options.
pub fn symmetric_difference_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  use built <- result.try(arrangement_graph.build(
    [left, right],
    tolerance: options.tolerance,
    minimum_chord: options.minimum_chord,
  ))
  let arrangement_graph.BuildResult(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  arrangement_graph.symmetric_difference_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  )
}

/// Return nested or disjoint unit-level contours with the same signed winding
/// field as `path`.
pub fn monotone_contours(
  path: svg_path.Path,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  monotone_contours_with(path, options: default_options())
}

/// Return monotone contours using explicit arrangement options.
pub fn monotone_contours_with(
  path: svg_path.Path,
  options options: Options,
) -> Result(svg_path.Path, arrangement_graph.Error) {
  use built <- result.try(arrangement_graph.build(
    [path],
    tolerance: options.tolerance,
    minimum_chord: options.minimum_chord,
  ))
  let arrangement_graph.BuildResult(graph:, normalized_paths:) = built
  let assert [normalized_path] = normalized_paths
  arrangement_graph.monotone_contours_from_arrangement_graph(
    graph,
    normalized_path,
    tolerance: options.tolerance,
  )
}
