import gleam/list
import svg_path
import svg_path/offset

fn square(x: Float, y: Float, size: Float) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(x, y),
    svg_path.Point(x +. size, y),
    svg_path.Point(x +. size, y +. size),
    svg_path.Point(x, y +. size),
  ])
}

pub fn nested_contours_alternate_orientation_independent_of_input_order_test() {
  let outer = square(0.0, 0.0, 10.0)
  let middle = square(2.0, 2.0, 6.0)
  let inner = square(4.0, 4.0, 2.0)
  let source =
    svg_path.Path([
      svg_path.subpath_reverse(inner),
      svg_path.subpath_reverse(outer),
      middle,
    ])
  let expected = svg_path.Path([inner, outer, svg_path.subpath_reverse(middle)])
  assert offset.orient_band_path(source) == Ok(expected)
  assert offset.orient_band_path(expected) == Ok(expected)
}

pub fn disconnected_and_vertex_touching_contours_orient_independently_test() {
  let a = square(0.0, 0.0, 2.0)
  let b = square(2.0, 2.0, 2.0)
  let c = square(8.0, 0.0, 2.0)
  assert offset.orient_band_path(
      svg_path.Path([
        svg_path.subpath_reverse(a),
        b,
        svg_path.subpath_reverse(c),
      ]),
    )
    == Ok(svg_path.Path([a, b, c]))
}

pub fn fully_retraced_contour_remains_undecided_test() {
  let retrace =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(3.0, 0.0),
    ])
  list.each([retrace, svg_path.subpath_reverse(retrace)], fn(contour) {
    let path = svg_path.Path([contour])
    assert offset.orient_band_path(path) == Ok(path)
  })
}

pub fn retraced_spur_does_not_constrain_its_loop_orientation_test() {
  let contour =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
      svg_path.Point(0.0, 0.0),
      svg_path.Point(-2.0, 0.0),
    ])
  assert offset.orient_band_path(
      svg_path.Path([svg_path.subpath_reverse(contour)]),
    )
    == Ok(svg_path.Path([contour]))
}

pub fn coincident_different_contours_are_unexpected_not_summed_test() {
  let contour = square(0.0, 0.0, 4.0)
  list.each(
    [
      [contour, contour],
      [contour, svg_path.subpath_reverse(contour)],
      [contour, contour, contour],
    ],
    fn(contours) {
      let assert Error(offset.InternalBandOrientationUnexpectedEdge(_, count)) =
        offset.orient_band_path(svg_path.Path(contours))
      assert count == list.length(contours)
    },
  )
}

pub fn same_loop_same_direction_duplicate_is_unexpected_test() {
  let contour =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
    ])
  let assert Error(offset.InternalBandOrientationUnexpectedEdge(_, 2)) =
    offset.orient_band_path(svg_path.Path([contour]))
}

pub fn opposite_lobe_orientations_allow_negative_face_values_test() {
  let bowtie =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
      svg_path.Point(4.0, 0.0),
    ])
  let assert Ok(result) = offset.orient_band_path(svg_path.Path([bowtie]))
  assert result == svg_path.Path([bowtie])
    || result == svg_path.Path([svg_path.subpath_reverse(bowtie)])
  assert offset.orient_band_path(result) == Ok(result)
}

pub fn same_direction_nested_lobe_exceeding_unit_winding_is_rejected_test() {
  let contour =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(6.0, 0.0),
      svg_path.Point(6.0, 6.0),
      svg_path.Point(0.0, 6.0),
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 1.0),
      svg_path.Point(3.0, 1.0),
      svg_path.Point(3.0, 3.0),
      svg_path.Point(1.0, 3.0),
      svg_path.Point(1.0, 1.0),
    ])
  // Both loops belong to one contour, connected by an opposite-pair bridge.
  // Its direction cannot change at the inner lobe to avoid winding magnitude 2.
  list.each([contour, svg_path.subpath_reverse(contour)], fn(contour) {
    let assert Error(offset.InternalBandOrientationConflict(_)) =
      offset.orient_band_path(svg_path.Path([contour]))
  })
}

pub fn open_contours_are_rejected_and_empty_path_is_preserved_test() {
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
    ])
  assert offset.orient_band_path(svg_path.Path([open]))
    == Error(offset.InternalBandSubpathNotClosed)
  assert offset.orient_band_path(svg_path.path_empty())
    == Ok(svg_path.path_empty())
}
