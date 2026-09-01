import gleam/float
import gleam/order
import gleeunit
import svg_path

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn compare_subpath_parameters_orders_by_segment_then_t_test() {
  assert svg_path.subpath_parameters_compare(
      svg_path.SubpathParameter(0, 0.75),
      svg_path.SubpathParameter(1, 0.25),
    )
    == order.Lt
  assert svg_path.subpath_parameters_compare(
      svg_path.SubpathParameter(1, 0.25),
      svg_path.SubpathParameter(1, 0.25),
    )
    == order.Eq
  assert svg_path.subpath_parameters_compare(
      svg_path.SubpathParameter(2, 0.0),
      svg_path.SubpathParameter(1, 1.0),
    )
    == order.Gt
}

pub fn compare_path_parameters_orders_by_subpath_then_subpath_parameter_test() {
  assert svg_path.path_parameters_compare(
      svg_path.PathParameter(0, svg_path.SubpathParameter(3, 0.75)),
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.25)),
    )
    == order.Lt
  assert svg_path.path_parameters_compare(
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.25)),
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.25)),
    )
    == order.Eq
  assert svg_path.path_parameters_compare(
      svg_path.PathParameter(1, svg_path.SubpathParameter(2, 0.0)),
      svg_path.PathParameter(1, svg_path.SubpathParameter(1, 1.0)),
    )
    == order.Gt
}

pub fn from_end_parameter_converts_reversed_address_to_original_address_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(20.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(20.0, 0.0),
        end: svg_path.Point(30.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(30.0, 0.0),
        end: svg_path.Point(40.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 0, t: 0.0)
    == Ok(svg_path.SubpathParameter(segment_index: 3, t: 1.0))
  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 0, t: 1.0)
    == Ok(svg_path.SubpathParameter(segment_index: 3, t: 0.0))
  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 2, t: 0.25)
    == Ok(svg_path.SubpathParameter(segment_index: 1, t: 0.75))
}

pub fn from_end_parameter_rejects_empty_subpaths_test() {
  let subpath = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))

  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 0, t: 0.0)
    == Error(svg_path.EmptySubpath)
}

pub fn from_end_parameter_rejects_invalid_reversed_address_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(20.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 2, t: 0.0)
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 2,
      t: 0.0,
      length: 2,
    ))
  assert svg_path.subpath_parameter_from_end(subpath, segment_index: 0, t: -0.1)
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: -0.1,
      length: 2,
    ))
}

pub fn canonicalize_subpath_parameter_only_normalizes_exact_boundaries_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(20.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_canonicalize(
      subpath,
      parameter: svg_path.SubpathParameter(0, 1.0),
    )
    == Ok(svg_path.SubpathParameter(1, 0.0))
  assert svg_path.subpath_parameter_canonicalize(
      subpath,
      parameter: svg_path.SubpathParameter(0, 0.9999999),
    )
    == Ok(svg_path.SubpathParameter(0, 0.9999999))
}

pub fn snap_subpath_parameter_snaps_internal_segment_end_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(20.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_snap_to_boundary(
      subpath,
      parameter: svg_path.SubpathParameter(0, 0.9999999),
      tolerance: 0.000001,
    )
    == Ok(svg_path.SubpathParameter(1, 0.0))
}

pub fn snap_subpath_parameter_snaps_closed_wrap_test() {
  let subpath =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  assert svg_path.subpath_parameter_snap_to_boundary(
      subpath,
      parameter: svg_path.SubpathParameter(2, 0.9999999),
      tolerance: 0.000001,
    )
    == Ok(svg_path.SubpathParameter(0, 0.0))
}

pub fn snap_subpath_parameter_keeps_open_final_endpoint_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_snap_to_boundary(
      subpath,
      parameter: svg_path.SubpathParameter(0, 0.9999999),
      tolerance: 0.000001,
    )
    == Ok(svg_path.SubpathParameter(0, 1.0))
}

pub fn snap_subpath_parameter_rejects_invalid_inputs_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])

  assert svg_path.subpath_parameter_snap_to_boundary(
      subpath,
      parameter: svg_path.SubpathParameter(0, 0.5),
      tolerance: 0.0,
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
  assert svg_path.subpath_parameter_snap_to_boundary(
      subpath,
      parameter: svg_path.SubpathParameter(1, 0.5),
      tolerance: 0.000001,
    )
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 1,
      t: 0.5,
      length: 1,
    ))
}

pub fn from_end_parameter_can_address_open_at_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let subpath = closed_subpath([ab, bc, cd, da])
  let assert Ok(parameter) =
    svg_path.subpath_parameter_from_end(subpath, segment_index: 2, t: 1.0)

  let assert Ok(opened) = svg_path.subpath_open_at(subpath, at: parameter)

  assert svg_path.subpath_segments(opened) == [bc, cd, da, ab]
  assert svg_path.subpath_start(opened) == b
}

pub fn from_end_parameter_can_address_subpath_between_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])
  let assert Ok(from) =
    svg_path.subpath_parameter_from_end(subpath, segment_index: 2, t: 0.0)
  let assert Ok(to) =
    svg_path.subpath_parameter_from_end(subpath, segment_index: 0, t: 1.0)

  let assert Ok(piece) = svg_path.subpath_between(subpath, from:, to:)

  assert svg_path.subpath_segments(piece)
    == [
      svg_path.Line(start: b, end: c),
    ]
}

pub fn subpath_point_evaluates_segment_address_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 20.0),
      ),
    ])
  let assert Ok(point) =
    svg_path.subpath_point(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 1, t: 0.25),
    )

  assert point_near(point, svg_path.Point(10.0, 5.0))
}

pub fn subpath_derivative_evaluates_segment_address_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 20.0),
      ),
    ])
  let assert Ok(derivative) =
    svg_path.subpath_derivative(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 1, t: 0.25),
    )

  assert point_near(derivative, svg_path.Point(0.0, 20.0))
}

pub fn subpath_derivative_uses_canonical_next_segment_at_internal_vertices_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 20.0),
      ),
    ])
  let assert Ok(derivative) =
    svg_path.subpath_derivative(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
    )

  assert point_near(derivative, svg_path.Point(0.0, 20.0))
}

pub fn subpath_point_and_derivative_reject_invalid_parameters_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])

  assert svg_path.subpath_point(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 1, t: 0.0),
    )
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 1,
      t: 0.0,
      length: 1,
    ))
  assert svg_path.subpath_derivative(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 0, t: -0.1),
    )
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: -0.1,
      length: 1,
    ))
}

pub fn split_subpath_splits_inside_segment_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok(#(left, right)) =
    svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(0, 0.5))

  assert svg_path.subpath_segments(left)
    == [
      svg_path.Line(start: a, end: svg_path.Point(5.0, 0.0)),
    ]
  assert svg_path.subpath_segments(right)
    == [
      svg_path.Line(start: svg_path.Point(5.0, 0.0), end: b),
      svg_path.Line(start: b, end: c),
    ]
}

pub fn split_subpath_splits_at_internal_vertex_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let second = svg_path.Line(start: b, end: c)
  let subpath = svg_path.subpath_assert([first, second])

  let assert Ok(#(left, right)) =
    svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(0, 1.0))

  assert svg_path.subpath_segments(left) == [first]
  assert svg_path.subpath_segments(right) == [second]
}

pub fn split_subpath_rejects_closed_empty_boundary_and_outside_parameters_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
  let closed =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])

  assert svg_path.subpath_split(closed, at: svg_path.SubpathParameter(0, 0.5))
    == Error(svg_path.AlreadyClosed)
  assert svg_path.subpath_split(
      svg_path.subpath_empty(at: a),
      at: svg_path.SubpathParameter(0, 0.5),
    )
    == Error(svg_path.EmptySubpath)
  assert svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(0, 0.0))
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: 0.0,
      length: 2,
    ))
  assert svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(1, 1.0))
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 1,
      t: 1.0,
      length: 2,
    ))
  assert svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(2, 0.0))
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 2,
      t: 0.0,
      length: 2,
    ))
  assert svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(0, 1.01))
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: 1.01,
      length: 2,
    ))
}

pub fn subpath_between_extracts_open_interval_across_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  let assert Ok(piece) =
    svg_path.subpath_between(
      subpath,
      from: svg_path.SubpathParameter(0, 0.5),
      to: svg_path.SubpathParameter(2, 0.5),
    )

  assert svg_path.subpath_segments(piece)
    == [
      svg_path.Line(start: svg_path.Point(5.0, 0.0), end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: svg_path.Point(25.0, 0.0)),
    ]
}

pub fn subpath_between_rejects_equal_and_reversed_open_intervals_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_between(
      subpath,
      from: svg_path.SubpathParameter(0, 0.5),
      to: svg_path.SubpathParameter(0, 0.5),
    )
    == Error(svg_path.InvalidSubpathInterval(
      from: svg_path.SubpathParameter(0, 0.5),
      to: svg_path.SubpathParameter(0, 0.5),
    ))
  assert svg_path.subpath_between(
      subpath,
      from: svg_path.SubpathParameter(1, 0.5),
      to: svg_path.SubpathParameter(0, 0.5),
    )
    == Error(svg_path.InvalidSubpathInterval(
      from: svg_path.SubpathParameter(1, 0.5),
      to: svg_path.SubpathParameter(0, 0.5),
    ))
}

pub fn subpath_between_wraps_closed_intervals_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok(piece) =
    svg_path.subpath_between(
      subpath,
      from: svg_path.SubpathParameter(2, 0.5),
      to: svg_path.SubpathParameter(1, 0.5),
    )

  assert svg_path.subpath_segments(piece)
    == [
      svg_path.Line(start: svg_path.Point(5.0, 10.0), end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: svg_path.Point(10.0, 5.0)),
    ]
}

pub fn subpaths_between_open_returns_outer_pieces_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  let assert Ok([first, second, third]) =
    svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(0, 0.5),
      svg_path.SubpathParameter(2, 0.5),
    ])

  assert svg_path.subpath_segments(first)
    == [svg_path.Line(start: a, end: svg_path.Point(5.0, 0.0))]
  assert svg_path.subpath_segments(second)
    == [
      svg_path.Line(start: svg_path.Point(5.0, 0.0), end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: svg_path.Point(25.0, 0.0)),
    ]
  assert svg_path.subpath_segments(third)
    == [svg_path.Line(start: svg_path.Point(25.0, 0.0), end: d)]
}

pub fn subpaths_between_open_rejects_boundary_and_duplicate_points_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(0, 0.0),
    ])
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: 0.0,
      length: 2,
    ))
  assert svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(0, 1.0),
      svg_path.SubpathParameter(1, 0.0),
    ])
    == Error(svg_path.InvalidSubpathInterval(
      from: svg_path.SubpathParameter(1, 0.0),
      to: svg_path.SubpathParameter(1, 0.0),
    ))
}

pub fn subpaths_between_closed_accepts_cyclic_order_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok([first, second, third]) =
    svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(2, 0.5),
      svg_path.SubpathParameter(3, 0.5),
      svg_path.SubpathParameter(1, 0.5),
    ])

  assert svg_path.subpath_segments(first)
    == [
      svg_path.Line(start: svg_path.Point(5.0, 10.0), end: d),
      svg_path.Line(start: d, end: svg_path.Point(0.0, 5.0)),
    ]
  assert svg_path.subpath_segments(second)
    == [
      svg_path.Line(start: svg_path.Point(0.0, 5.0), end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: svg_path.Point(10.0, 5.0)),
    ]
  assert svg_path.subpath_segments(third)
    == [
      svg_path.Line(start: svg_path.Point(10.0, 5.0), end: c),
      svg_path.Line(start: c, end: svg_path.Point(5.0, 10.0)),
    ]
}

pub fn subpaths_between_closed_accepts_single_split_point_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok([opened]) =
    svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(1, 0.5),
    ])

  assert !svg_path.subpath_is_closed(opened)
  assert svg_path.subpath_start(opened) == svg_path.Point(10.0, 5.0)
  assert svg_path.subpath_end(opened) == svg_path.Point(10.0, 5.0)
  assert svg_path.subpath_segments(opened)
    == [
      svg_path.Line(start: svg_path.Point(10.0, 5.0), end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: svg_path.Point(10.0, 5.0)),
    ]
}

pub fn subpaths_between_closed_rejects_duplicate_and_nonlinear_order_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  assert svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(3, 1.0),
      svg_path.SubpathParameter(0, 0.0),
    ])
    == Error(svg_path.InvalidSubpathInterval(
      from: svg_path.SubpathParameter(0, 0.0),
      to: svg_path.SubpathParameter(0, 0.0),
    ))
  assert svg_path.subpath_between_many(subpath, between: [
      svg_path.SubpathParameter(2, 0.5),
      svg_path.SubpathParameter(1, 0.5),
      svg_path.SubpathParameter(3, 0.5),
    ])
    == Error(svg_path.InvalidSubpathInterval(
      from: svg_path.SubpathParameter(3, 0.5),
      to: svg_path.SubpathParameter(2, 0.5),
    ))
}

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  svg_path.subpath_assert(segments)
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
