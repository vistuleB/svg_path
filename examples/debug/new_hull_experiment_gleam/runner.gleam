import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/maths
import new_hull_experiment/arc_trivial_hull
import new_hull_experiment/collinear_cubic
import new_hull_experiment/cubic_sample_hull
import new_hull_experiment/cubic_support
import new_hull_experiment/fixtures
import svg_path
import svg_path/convex_hull

const samples = 36

pub fn main() -> Nil {
  fixtures.cubic_specimens()
  |> list.map(compare_specimen)
  |> string.join("\n")
  |> io.println

  "\nArc trivial hulls"
  |> io.println

  fixtures.arc_specimens()
  |> list.map(compare_arc_specimen)
  |> string.join("\n")
  |> io.println
}

fn compare_arc_specimen(specimen: #(String, svg_path.Segment)) -> String {
  let #(name, segment) = specimen
  name <> arc_sample_hull_summary(segment) <> current_hull_summary(segment)
}

fn arc_sample_hull_summary(segment: svg_path.Segment) -> String {
  case arc_trivial_hull.hull(segment) {
    Ok(#(_, pieces)) -> ", trivial arc hull = " <> string.inspect(pieces)
    Error(error) -> ", trivial arc hull error = " <> string.inspect(error)
  }
}

fn compare_specimen(specimen: #(String, svg_path.Segment)) -> String {
  let #(name, segment) = specimen
  let errors =
    int.range(from: 0, to: samples - 1, with: [], run: fn(errors, i) {
      let angle = int.to_float(i) *. 360.0 /. int.to_float(samples)
      case compare_support(segment, angle) {
        Ok(error) -> [error, ..errors]
        Error(_) -> errors
      }
    })

  let worst =
    errors
    |> list.fold(0.0, fn(worst, error) { float.max(worst, error) })

  name
  <> ": worst support value delta = "
  <> float.to_string(worst)
  <> collinear_summary(segment)
  <> sample_hull_summary(segment)
  <> current_hull_summary(segment)
}

fn sample_hull_summary(segment: svg_path.Segment) -> String {
  case cubic_sample_hull.hull(segment, sample_count: 3600) {
    Ok(#(_, pieces)) -> {
      case
        cubic_sample_hull.worst_support_error(
          segment,
          pieces: pieces,
          sample_count: 3600,
        )
      {
        Ok(#(angle, error, original, candidate)) ->
          ", sample hull pieces = "
          <> int.to_string(list.length(pieces))
          <> ", sample hull support error = "
          <> float.to_string(error)
          <> " at "
          <> float.to_string(angle)
          <> " original="
          <> float.to_string(original)
          <> " candidate="
          <> float.to_string(candidate)
          <> case error >. 0.000001 {
            True -> {
              let supports = case
                cubic_sample_hull.piece_supports(
                  segment,
                  pieces: pieces,
                  angle: angle,
                )
              {
                Ok(supports) -> string.inspect(supports)
                Error(error) -> string.inspect(error)
              }
              " pieces="
              <> string.inspect(pieces)
              <> " piece_supports="
              <> supports
            }
            False -> ""
          }
        Error(error) ->
          ", sample hull support error = " <> string.inspect(error)
      }
    }
    Error(error) -> ", sample hull error = " <> string.inspect(error)
  }
}

fn collinear_summary(segment: svg_path.Segment) -> String {
  case collinear_cubic.hull_pieces(segment) {
    Ok(pieces) -> ", collinear pieces = " <> string.inspect(pieces)
    Error(_) -> ""
  }
}

fn current_hull_summary(segment: svg_path.Segment) -> String {
  case convex_hull.segment_hull(segment) {
    Ok(#(_, pieces)) -> ", current hull = " <> string.inspect(pieces)
    Error(error) -> ", current hull error = " <> string.inspect(error)
  }
}

fn compare_support(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(Float, Nil) {
  case
    cubic_support.support(segment, degrees: angle),
    numeric_support(segment, angle)
  {
    Ok(#(_, analytic_point)), Ok(numeric_point) ->
      Ok(float.absolute_value(
        point_support(analytic_point, angle)
        -. point_support(numeric_point, angle),
      ))
    _, _ -> Error(Nil)
  }
}

fn numeric_support(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  let direction = angle_direction(angle)
  use t <- result_try_float(
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    }),
  )

  svg_path.segment_point(segment, at: t)
}

fn point_support(point: svg_path.Point, degrees: Float) -> Float {
  dot(point, angle_direction(degrees))
}

fn angle_direction(degrees: Float) -> svg_path.Point {
  let radians = degrees *. maths.pi() /. 180.0

  svg_path.Point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn result_try_float(
  result: Result(Float, svg_path.Error),
  next: fn(Float) -> Result(a, svg_path.Error),
) -> Result(a, svg_path.Error) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}
