import gleeunit
import svg_path
import svg_path/cut
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn subpath_cut_splits_open_subject_in_order_test() {
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(30.0, 0.0),
      ),
    ])
  let cutter =
    svg_path.subpath_assert_polyline([
      svg_path.point(10.0, -5.0),
      svg_path.point(10.0, 5.0),
      svg_path.point(20.0, 5.0),
      svg_path.point(20.0, -5.0),
    ])

  let assert Ok(pieces) = cut.subpath(subject: subject, by: cutter)

  assert serialize.path(svg_path.Path(pieces))
    == "M 0 0 H 10 M 10 0 H 20 M 20 0 H 30"
}

pub fn subpath_cut_returns_subject_when_no_intersections_test() {
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 5.0),
        end: svg_path.point(10.0, 5.0),
      ),
    ])

  assert cut.subpath(subject: subject, by: cutter) == Ok([subject])
}

pub fn subpath_cut_ignores_open_subject_endpoint_intersections_test() {
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, -5.0),
        end: svg_path.point(0.0, 5.0),
      ),
    ])

  assert cut.subpath(subject: subject, by: cutter) == Ok([subject])
}

pub fn subpath_cut_dedupes_internal_boundary_aliases_test() {
  let middle = svg_path.point(10.0, 0.0)
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(start: svg_path.point(0.0, 0.0), end: middle),
      svg_path.Line(start: middle, end: svg_path.point(20.0, 0.0)),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(10.0, -5.0),
        end: svg_path.point(10.0, 5.0),
      ),
    ])

  let assert Ok(pieces) = cut.subpath(subject: subject, by: cutter)

  assert serialize.path(svg_path.Path(pieces)) == "M 0 0 H 10 M 10 0 H 20"
}

pub fn subpath_cut_opens_closed_subject_at_single_cut_test() {
  let subject =
    svg_path.subpath_assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(5.0, -5.0),
        end: svg_path.point(5.0, 0.0),
      ),
    ])

  let assert Ok([opened]) = cut.subpath(subject: subject, by: cutter)

  assert !svg_path.subpath_is_closed(opened)
  assert serialize.path(svg_path.path_from_subpath(opened))
    == "M 5 0 H 10 V 10 H 0 V 0 H 5"
}

pub fn subpath_cut_splits_closed_subject_cyclically_test() {
  let subject =
    svg_path.subpath_assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(5.0, -5.0),
        end: svg_path.point(5.0, 15.0),
      ),
    ])

  let assert Ok(pieces) = cut.subpath(subject: subject, by: cutter)

  assert serialize.path(svg_path.Path(pieces))
    == "M 5 0 H 10 V 10 H 5 M 5 10 H 0 V 0 H 5"
}

pub fn subpath_cut_propagates_intersection_option_errors_test() {
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(5.0, -5.0),
        end: svg_path.point(5.0, 5.0),
      ),
    ])

  assert cut.subpath_with(
      subject: subject,
      by: cutter,
      options: svg_path.IntersectionOptions(tolerance: 0.0, max_depth: 48),
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
}

pub fn path_cut_cuts_each_subject_subpath_by_all_cutter_subpaths_test() {
  let top =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(30.0, 0.0),
      ),
    ])
  let bottom =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 10.0),
        end: svg_path.point(30.0, 10.0),
      ),
    ])
  let left_cut =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(10.0, -5.0),
        end: svg_path.point(10.0, 15.0),
      ),
    ])
  let right_cut =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(20.0, -5.0),
        end: svg_path.point(20.0, 15.0),
      ),
    ])

  let assert Ok(result) =
    cut.path(
      subject: svg_path.Path([top, bottom]),
      by: svg_path.Path([right_cut, left_cut]),
    )

  assert serialize.path(result)
    == "M 0 0 H 10 M 10 0 H 20 M 20 0 H 30 M 0 10 H 10 M 10 10 H 20 M 20 10 H 30"
}

pub fn path_cut_empty_subject_returns_empty_path_test() {
  let cutter =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(5.0, -5.0),
        end: svg_path.point(5.0, 5.0),
      ),
    ])

  assert cut.path(subject: svg_path.Path([]), by: svg_path.Path([cutter]))
    == Ok(svg_path.Path([]))
}

pub fn path_cut_empty_cutter_returns_subject_path_test() {
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])

  assert cut.path(subject: svg_path.Path([subject]), by: svg_path.Path([]))
    == Ok(svg_path.Path([subject]))
}

pub fn path_cut_dedupes_near_internal_boundary_aliases_test() {
  let middle = svg_path.point(10.0, 0.0)
  let subject =
    svg_path.subpath_assert([
      svg_path.Line(start: svg_path.point(0.0, 0.0), end: middle),
      svg_path.Line(start: middle, end: svg_path.point(20.0, 0.0)),
    ])
  let left_near_cut =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(9.9999999999, -5.0),
        end: svg_path.point(9.9999999999, 5.0),
      ),
    ])
  let right_near_cut =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(10.0000000001, -5.0),
        end: svg_path.point(10.0000000001, 5.0),
      ),
    ])

  let assert Ok(result) =
    cut.path_with(
      subject: svg_path.Path([subject]),
      by: svg_path.Path([left_near_cut, right_near_cut]),
      options: svg_path.IntersectionOptions(tolerance: 0.000001, max_depth: 48),
    )

  assert serialize.path(result) == "M 0 0 H 10 M 10 0 H 20"
}
