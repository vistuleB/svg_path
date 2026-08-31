//// Full package-title first and second offset probe.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/serialize
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_double_offset_1_05.svg"

const offset_distance = 1.05

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(first_offset) =
    offset.path_with(source, offset: offset_distance, options:)
  io.println(
    "first offset subpaths: "
    <> int.to_string(list.length(svg_path.path_subpaths(first_offset))),
  )
  report_subpath_counts("first offset", first_offset)
  report_subpath_segments("first offset", first_offset, 4)

  let second_untrimmed =
    offset.path_untrimmed_with(first_offset, offset: offset_distance, options:)
  case second_untrimmed {
    Ok(untrimmed) -> {
      io.println(
        "second untrimmed offset subpaths: "
        <> int.to_string(list.length(svg_path.path_subpaths(untrimmed))),
      )
      report_subpath_counts("second untrimmed", untrimmed)
    }
    Error(error) ->
      io.println(
        "second untrimmed offset error: " <> offset_error_to_string(error),
      )
  }

  let second_trimmed =
    offset.path_with(first_offset, offset: offset_distance, options:)
  case second_trimmed {
    Ok(second_offset) -> {
      io.println(
        "second offset subpaths: "
        <> int.to_string(list.length(svg_path.path_subpaths(second_offset))),
      )
      write_file(
        output,
        render(source, first_offset, second_untrimmed, Ok(second_offset)),
      )
    }
    Error(error) -> {
      io.println("second offset error: " <> offset_error_to_string(error))
      write_file(
        output,
        render(source, first_offset, second_untrimmed, Error(error)),
      )
    }
  }
  Nil
}

fn report_subpath_segments(
  label: String,
  path: svg_path.Path,
  index: Int,
) -> Nil {
  case subpath_at(svg_path.path_subpaths(path), index) {
    Error(_) -> Nil
    Ok(subpath) -> {
      subpath
      |> svg_path.subpath_segments
      |> list.index_map(fn(segment, segment_index) {
        io.println(
          label
          <> " subpath "
          <> int.to_string(index)
          <> " segment "
          <> int.to_string(segment_index)
          <> " chord="
          <> float.to_string(svg_path.segment_chord_length(segment))
          <> " "
          <> serialize.segment(segment),
        )
      })
      Nil
    }
  }
}

fn subpath_at(
  subpaths: List(svg_path.Subpath),
  index: Int,
) -> Result(svg_path.Subpath, Nil) {
  case subpaths, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> subpath_at(rest, index - 1)
  }
}

fn report_subpath_counts(label: String, path: svg_path.Path) -> Nil {
  path
  |> svg_path.path_subpaths
  |> list.index_map(fn(subpath, index) {
    io.println(
      label
      <> " subpath "
      <> int.to_string(index)
      <> " segments="
      <> int.to_string(list.length(svg_path.subpath_segments(subpath)))
      <> " closed="
      <> bool_to_string(svg_path.subpath_is_closed(subpath))
      <> " box="
      <> subpath_box_to_string(subpath),
    )
  })
  Nil
}

fn subpath_box_to_string(subpath: svg_path.Subpath) -> String {
  case svg_path.subpath_bounding_box(subpath) {
    Error(_) -> "none"
    Ok(svg_path.BoundingBox(min:, max:)) ->
      "("
      <> float.to_string(min.x)
      <> ", "
      <> float.to_string(min.y)
      <> ") -> ("
      <> float.to_string(max.x)
      <> ", "
      <> float.to_string(max.y)
      <> ")"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn render(
  source: svg_path.Path,
  first_offset: svg_path.Path,
  second_untrimmed: Result(svg_path.Path, offset.Error),
  second_offset: Result(svg_path.Path, offset.Error),
) -> String {
  let paths = case second_untrimmed, second_offset {
    _, Ok(second) -> [source, first_offset, second]
    Ok(untrimmed), Error(_) -> [source, first_offset, untrimmed]
    Error(_), Error(_) -> [source, first_offset]
  }
  let boxes = path_boxes(paths)
  let view_box = padded_box(boxes, margin: 3.0)
  let untrimmed_layer = case second_untrimmed {
    Ok(untrimmed) -> [
      svg.StyledPath(
        untrimmed,
        "fill: none; stroke: #9ca3af; stroke-width: 0.06; stroke-linecap: round; stroke-linejoin: round",
      ),
    ]
    Error(_) -> []
  }
  let second_layer = case second_offset {
    Ok(second) -> [
      svg.StyledPath(
        second,
        "fill: none; stroke: #f97316; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
      ),
    ]
    Error(error) -> [
      svg.Text(
        "second trimmed offset error: " <> offset_error_to_string(error),
        "fill: #991b1b; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
        svg_path.Point(view_box.min.x +. 1.0, view_box.min.y +. 2.4),
        0.9,
      ),
    ]
  }
  let mini_first_offset_layer = case
    subpath_at(svg_path.path_subpaths(first_offset), 4)
  {
    Ok(subpath) -> [
      svg.StyledPath(
        svg_path.subpath_as_path(subpath),
        "fill: none; stroke: #7c3aed; stroke-width: 0.55; stroke-linecap: round; stroke-linejoin: round; opacity: 0.95",
      ),
    ]
    Error(_) -> []
  }
  let things = [
    background(view_box),
    svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.18"),
    svg.StyledPath(
      first_offset,
      "fill: none; stroke: #2563eb; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.Text(
      "blue = first offset; gray = second untrimmed; orange = second trimmed; distance 1.05",
      "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
      svg_path.Point(view_box.min.x +. 1.0, view_box.min.y +. 1.2),
      0.9,
    ),
    ..untrimmed_layer
  ]
  let things = list.append(things, second_layer)
  let things = list.append(things, mini_first_offset_layer)

  svg.document(things:, view_box:)
  |> with_root_size(width: 1800, height: 420)
}

fn offset_error_to_string(error: offset.Error) -> String {
  case error {
    offset.PathError(error) ->
      "PathError(" <> path_error_to_string(error) <> ")"
    offset.ArrangementGraphError(_) -> "ArrangementGraphError"
    offset.SourceNormalizationError(_) -> "SourceNormalizationError"
    offset.InvalidTolerance(tolerance) ->
      "InvalidTolerance(" <> float.to_string(tolerance) <> ")"
    offset.InvalidSamples(samples) ->
      "InvalidSamples(" <> int.to_string(samples) <> ")"
    offset.InvalidMaxDepth(max_depth) ->
      "InvalidMaxDepth(" <> int.to_string(max_depth) <> ")"
    offset.InvalidMiterLimit(miter_limit) ->
      "InvalidMiterLimit(" <> float.to_string(miter_limit) <> ")"
    offset.InvalidStalledOffsetDiameter(diameter) ->
      "InvalidStalledOffsetDiameter(" <> float.to_string(diameter) <> ")"
    offset.InvalidStrokeWidth(width) ->
      "InvalidStrokeWidth(" <> float.to_string(width) <> ")"
    offset.BandSubpathNotClosed -> "BandSubpathNotClosed"
    offset.DegenerateTangent(t) ->
      "DegenerateTangent(" <> float.to_string(t) <> ")"
    offset.MaxDepthReached(error) ->
      "MaxDepthReached(" <> float.to_string(error) <> ")"
    offset.NonFinite -> "NonFinite"
  }
}

fn path_error_to_string(error: svg_path.Error) -> String {
  case error {
    svg_path.AlreadyClosed -> "AlreadyClosed"
    svg_path.Discontinuous(previous_index, next_index, expected, got, distance) ->
      "Discontinuous(previous_index="
      <> int.to_string(previous_index)
      <> ", next_index="
      <> int.to_string(next_index)
      <> ", distance="
      <> float.to_string(distance)
      <> ", expected="
      <> point_to_string(expected)
      <> ", got="
      <> point_to_string(got)
      <> ")"
    svg_path.EmptySubpath -> "EmptySubpath"
    svg_path.NotClosed -> "NotClosed"
    svg_path.EmptyPath -> "EmptyPath"
    svg_path.EmptySubpaths -> "EmptySubpaths"
    svg_path.DegenerateArc -> "DegenerateArc"
    svg_path.CannotMapArcNonlinearly -> "CannotMapArcNonlinearly"
    svg_path.InvalidSplice(start, delete, length) ->
      "InvalidSplice(start="
      <> int.to_string(start)
      <> ", delete="
      <> int.to_string(delete)
      <> ", length="
      <> int.to_string(length)
      <> ")"
    svg_path.InvalidSubpathParameter(segment_index, t, length) ->
      "InvalidSubpathParameter(segment_index="
      <> int.to_string(segment_index)
      <> ", t="
      <> float.to_string(t)
      <> ", length="
      <> int.to_string(length)
      <> ")"
    svg_path.InvalidPathParameter(subpath_index, length) ->
      "InvalidPathParameter(subpath_index="
      <> int.to_string(subpath_index)
      <> ", length="
      <> int.to_string(length)
      <> ")"
    svg_path.InvalidDirectionRelativeTolerance(tolerance) ->
      "InvalidDirectionRelativeTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.IndeterminateDirection -> "IndeterminateDirection"
    svg_path.InvalidWiggleTolerance(tolerance) ->
      "InvalidWiggleTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidSubpathInterval(_, _) -> "InvalidSubpathInterval"
    svg_path.InvalidCrossingSamples(samples) ->
      "InvalidCrossingSamples(" <> int.to_string(samples) <> ")"
    svg_path.InvalidCrossingTolerance(tolerance) ->
      "InvalidCrossingTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidCrossingMaxIterations(max_iterations) ->
      "InvalidCrossingMaxIterations(" <> int.to_string(max_iterations) <> ")"
    svg_path.CrossingMaxIterationsReached(estimate, value) ->
      "CrossingMaxIterationsReached(estimate="
      <> float.to_string(estimate)
      <> ", value="
      <> float.to_string(value)
      <> ")"
    svg_path.InvalidMinimizeSamples(samples) ->
      "InvalidMinimizeSamples(" <> int.to_string(samples) <> ")"
    svg_path.InvalidMinimizeTolerance(tolerance) ->
      "InvalidMinimizeTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidMinimizeMaxIterations(max_iterations) ->
      "InvalidMinimizeMaxIterations(" <> int.to_string(max_iterations) <> ")"
    svg_path.MinimizeMaxIterationsReached(estimate, value) ->
      "MinimizeMaxIterationsReached(estimate="
      <> float.to_string(estimate)
      <> ", value="
      <> float.to_string(value)
      <> ")"
    svg_path.InvalidLengthTolerance(tolerance) ->
      "InvalidLengthTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidLengthMaxDepth(max_depth) ->
      "InvalidLengthMaxDepth(" <> int.to_string(max_depth) <> ")"
    svg_path.LengthMaxDepthReached(estimate, error) ->
      "LengthMaxDepthReached(estimate="
      <> float.to_string(estimate)
      <> ", error="
      <> float.to_string(error)
      <> ")"
    svg_path.InvalidZeroLengthTolerance(tolerance) ->
      "InvalidZeroLengthTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidLengthDistance(distance, length) ->
      "InvalidLengthDistance(distance="
      <> float.to_string(distance)
      <> ", length="
      <> float.to_string(length)
      <> ")"
    svg_path.InvalidSubdivisionMaxLength(max_length) ->
      "InvalidSubdivisionMaxLength(" <> float.to_string(max_length) <> ")"
    svg_path.InvalidParametricTolerance(tolerance) ->
      "InvalidParametricTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidParametricSamplesPerPiece(samples) ->
      "InvalidParametricSamplesPerPiece(" <> int.to_string(samples) <> ")"
    svg_path.InvalidParametricInitialPieceCount(piece_count) ->
      "InvalidParametricInitialPieceCount(" <> int.to_string(piece_count) <> ")"
    svg_path.InvalidParametricMaxDepth(max_depth) ->
      "InvalidParametricMaxDepth(" <> int.to_string(max_depth) <> ")"
    svg_path.InvalidParametricInterval(start, end) ->
      "InvalidParametricInterval(start="
      <> float.to_string(start)
      <> ", end="
      <> float.to_string(end)
      <> ")"
    svg_path.NonFiniteParametricPoint(parameter, point) ->
      "NonFiniteParametricPoint(parameter="
      <> float.to_string(parameter)
      <> ", point="
      <> point_to_string(point)
      <> ")"
    svg_path.NonFiniteParametricTangent(parameter, tangent) ->
      "NonFiniteParametricTangent(parameter="
      <> float.to_string(parameter)
      <> ", tangent="
      <> point_to_string(tangent)
      <> ")"
    svg_path.ParametricMaxDepthReached(error) ->
      "ParametricMaxDepthReached(" <> float.to_string(error) <> ")"
    svg_path.ParametricFitFailed -> "ParametricFitFailed"
    svg_path.DegenerateCubicFitTangent -> "DegenerateCubicFitTangent"
    svg_path.UnderdeterminedCubicFit -> "UnderdeterminedCubicFit"
    svg_path.InvalidLinearizeTolerance(tolerance) ->
      "InvalidLinearizeTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidLinearizeMaxDepth(max_depth) ->
      "InvalidLinearizeMaxDepth(" <> int.to_string(max_depth) <> ")"
    svg_path.LinearizeMaxDepthReached(error) ->
      "LinearizeMaxDepthReached(" <> float.to_string(error) <> ")"
    svg_path.InvalidDistanceSamples(samples) ->
      "InvalidDistanceSamples(" <> int.to_string(samples) <> ")"
    svg_path.InvalidDistanceTolerance(tolerance) ->
      "InvalidDistanceTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidDistanceMaxIterations(max_iterations) ->
      "InvalidDistanceMaxIterations(" <> int.to_string(max_iterations) <> ")"
    svg_path.DistanceMaxIterationsReached(estimate, value) ->
      "DistanceMaxIterationsReached(estimate="
      <> float.to_string(estimate)
      <> ", value="
      <> float.to_string(value)
      <> ")"
    svg_path.DistanceRootIsolationFailed -> "DistanceRootIsolationFailed"
    svg_path.InvalidContainmentTolerance(tolerance) ->
      "InvalidContainmentTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidContainmentSamples(samples) ->
      "InvalidContainmentSamples(" <> int.to_string(samples) <> ")"
    svg_path.InvalidContainmentMaxIterations(max_iterations) ->
      "InvalidContainmentMaxIterations(" <> int.to_string(max_iterations) <> ")"
    svg_path.InvalidContainmentRayAngle(angle) ->
      "InvalidContainmentRayAngle(" <> float.to_string(angle) <> ")"
    svg_path.InconsistentContainment -> "InconsistentContainment"
    svg_path.IndeterminateWindingSideLevels -> "IndeterminateWindingSideLevels"
    svg_path.InconsistentWindingSideLevels -> "InconsistentWindingSideLevels"
    svg_path.InvalidIntersectionTolerance(tolerance) ->
      "InvalidIntersectionTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidOverlapTolerance(tolerance) ->
      "InvalidOverlapTolerance(" <> float.to_string(tolerance) <> ")"
    svg_path.InvalidOverlapSamples(samples) ->
      "InvalidOverlapSamples(" <> int.to_string(samples) <> ")"
    svg_path.InvalidIntersectionMaxDepth(max_depth) ->
      "InvalidIntersectionMaxDepth(" <> int.to_string(max_depth) <> ")"
    svg_path.InvalidIntersectionParameterSnapExponent(exponent) ->
      "InvalidIntersectionParameterSnapExponent("
      <> int.to_string(exponent)
      <> ")"
    svg_path.InvalidSelfIntersectionMinimumArcLengthSeparation(value) ->
      "InvalidSelfIntersectionMinimumArcLengthSeparation("
      <> float.to_string(value)
      <> ")"
    svg_path.InvalidSelfIntersectionDistanceTolerance(value) ->
      "InvalidSelfIntersectionDistanceTolerance("
      <> float.to_string(value)
      <> ")"
    svg_path.OverlappingSegments -> "OverlappingSegments"
    svg_path.InternalOverlapClassificationInconsistency ->
      "InternalOverlapClassificationInconsistency"
    svg_path.InternalUncertifiedSegmentIntersection(left, right, tolerance) ->
      "InternalUncertifiedSegmentIntersection(left="
      <> float.to_string(left)
      <> ", right="
      <> float.to_string(right)
      <> ", tolerance="
      <> float.to_string(tolerance)
      <> ")"
    svg_path.InternalOverlapParameterCorrespondenceInconsistency ->
      "InternalOverlapParameterCorrespondenceInconsistency"
    svg_path.NonAffineOverlapCorrespondence -> "NonAffineOverlapCorrespondence"
    svg_path.MultipleNonemptySubpaths -> "MultipleNonemptySubpaths"
    svg_path.NotCloseEnough(expected, got, tolerance) ->
      "NotCloseEnough(expected="
      <> point_to_string(expected)
      <> ", got="
      <> point_to_string(got)
      <> ", tolerance="
      <> float.to_string(tolerance)
      <> ")"
    svg_path.SplitOutsideSegment -> "SplitOutsideSegment"
  }
}

fn point_to_string(point: svg_path.Point) -> String {
  "(" <> float.to_string(point.x) <> ", " <> float.to_string(point.y) <> ")"
}

fn path_boxes(paths: List(svg_path.Path)) -> List(svg_path.BoundingBox) {
  paths
  |> list.filter_map(svg_path.path_bounding_box)
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined =
    list.fold(boxes, first, fn(acc, box) { combine_boxes(acc, box) })
  let svg_path.BoundingBox(min:, max:) = combined

  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn combine_boxes(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(
      float.min(left.min.x, right.min.x),
      float.min(left.min.y, right.min.y),
    ),
    max: svg_path.Point(
      float.max(left.max.x, right.max.x),
      float.max(left.max.y, right.max.y),
    ),
  )
}

fn with_root_size(
  svg_document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(svg_document, on: "\" width=\"")
  let assert Ok(#(_, after_height)) =
    string.split_once(after_width, on: "\" height=\"")
  let assert Ok(#(_, rest)) = string.split_once(after_height, on: "\">")

  before_width
  <> "\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\">"
  <> rest
}

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
