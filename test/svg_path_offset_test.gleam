import gleam/float
import gleam/int
import svg_path
import svg_path/offset

pub fn segment_offsets_line_to_the_right_of_direction_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: 2.0)

  assert svg_path.segments(offset)
    == [
      svg_path.Line(
        start: svg_path.point(0.0, -2.0),
        end: svg_path.point(10.0, -2.0),
      ),
    ]
}

pub fn segment_offsets_line_to_left_for_negative_distance_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(0.0, 10.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: -3.0)

  assert svg_path.segments(offset)
    == [
      svg_path.Line(
        start: svg_path.point(-3.0, 0.0),
        end: svg_path.point(-3.0, 10.0),
      ),
    ]
}

pub fn segment_offsets_quadratic_to_cubic_pieces_within_tolerance_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(50.0, -80.0),
      end: svg_path.point(100.0, 0.0),
    )
  let options =
    offset.Options(..offset.default_options(), tolerance: 0.001, samples: 12)

  let assert Ok(offset_subpath) =
    offset.segment_with(curve, distance: 5.0, options:)

  assert svg_path.segments(offset_subpath) != []
  assert max_offset_error(curve, offset_subpath, distance: 5.0) <=. 0.01
}

pub fn segment_offsets_arc_after_cubic_conversion_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(10.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(0.0, 10.0),
    )

  let assert Ok(offset_subpath) = offset.segment(arc, distance: 2.0)

  assert svg_path.segments(offset_subpath) != []
}

pub fn segment_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let options = offset.Options(..offset.default_options(), tolerance: 0.0)

  assert offset.segment_with(line, distance: 1.0, options:)
    == Error(offset.InvalidTolerance(0.0))
}

pub fn segment_rejects_zero_length_line_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(1.0, 2.0),
    )

  assert offset.segment(line, distance: 1.0)
    == Error(offset.DegenerateTangent(0.0))
}

fn max_offset_error(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance distance: Float,
) -> Float {
  max_offset_error_loop(source, offset_subpath, distance, sample: 1, best: 0.0)
}

fn max_offset_error_loop(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance: Float,
  sample sample: Int,
  best best: Float,
) -> Float {
  case sample > 19 {
    True -> best
    False -> {
      let t = int.to_float(sample) /. 20.0
      let assert Ok(point) = svg_path.segment_point(source, at: t)
      let assert Ok(derivative) = svg_path.segment_derivative(source, at: t)
      let normal = right_unit_normal(derivative)
      let extruded =
        svg_path.point(
          point.x +. normal.x *. distance,
          point.y +. normal.y *. distance,
        )
      let assert Ok(projection) =
        svg_path.subpath_projection(extruded, to: offset_subpath)

      max_offset_error_loop(
        source,
        offset_subpath,
        distance,
        sample: sample + 1,
        best: float.max(best, projection.distance),
      )
    }
  }
}

fn right_unit_normal(point: svg_path.Point) -> svg_path.Point {
  let length = distance(svg_path.point(0.0, 0.0), point)
  svg_path.point(point.y /. length, { 0.0 -. point.x } /. length)
}

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let assert Ok(distance) =
    float.square_root(
      { a.x -. b.x } *. { a.x -. b.x } +. { a.y -. b.y } *. { a.y -. b.y },
    )
  distance
}
