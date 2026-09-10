import gleam/int
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

fn segment_count(path: svg_path.Path) -> Int {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.length
}

fn check_fill(input: svg_path.Path, output: svg_path.Path) {
  // Non-boundary grid samples compare the input even-odd target with output
  // nonzero fill. Boundary samples are explicitly excluded, not classified.
  list.each([-1, 0, 1, 2, 3, 4, 5, 6, 7], fn(x) {
    list.each([-1, 0, 1, 2, 3, 4, 5, 6, 7], fn(y) {
      let p = svg_path.Point(int.to_float(x) +. 0.37, int.to_float(y) +. 0.19)
      let assert Ok(a) = svg_path.path_winding(p, input)
      let assert Ok(b) = svg_path.path_winding(p, output)
      case a, b {
        svg_path.Winding(a), svg_path.Winding(b) -> {
          assert int.is_odd(a) == { b != 0 }
          assert b == 0 || b == 1
        }
        _, _ -> Nil
      }
    })
  })
}

fn check_orientation_choices(input: svg_path.Path, loops: svg_path.Path) {
  check_fill(input, loops)
  let choices =
    svg_path.path_subpaths(loops)
    |> list.fold([[]], fn(prefixes, loop) {
      prefixes
      |> list.flat_map(fn(prefix) {
        [
          list.append(prefix, [loop]),
          list.append(prefix, [svg_path.subpath_reverse(loop)]),
        ]
      })
    })
  list.each(choices, fn(subpaths) {
    let assert Ok(oriented) = offset.orient_band_path(svg_path.Path(subpaths))
    check_fill(input, oriented)
  })
}

pub fn bowtie_splits_into_two_independently_orientable_face_loops_test() {
  let bowtie =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
      svg_path.Point(4.0, 0.0),
    ])
  list.each([bowtie, svg_path.subpath_reverse(bowtie)], fn(contour) {
    let input = svg_path.Path([contour])
    let assert Ok(loops) = offset.enumerate_band_face_loops(input)
    assert list.length(svg_path.path_subpaths(loops)) == 2
    assert segment_count(loops) == 6
    check_orientation_choices(input, loops)
  })
}

pub fn nested_same_direction_contours_become_even_odd_boundary_loops_test() {
  let input = svg_path.Path([square(2.0, 2.0, 2.0), square(0.0, 0.0, 6.0)])
  let assert Ok(loops) = offset.enumerate_band_face_loops(input)
  assert list.length(svg_path.path_subpaths(loops)) == 2
  check_orientation_choices(input, loops)
}

pub fn touching_vertices_do_not_merge_filled_face_sectors_test() {
  let input = svg_path.Path([square(0.0, 0.0, 2.0), square(2.0, 2.0, 2.0)])
  let assert Ok(loops) = offset.enumerate_band_face_loops(input)
  assert list.length(svg_path.path_subpaths(loops)) == 2
  check_fill(input, loops)
  let assert Ok(oriented) = offset.orient_band_path(loops)
  check_fill(input, oriented)
}

pub fn multiply_wound_single_contour_can_be_reenumerated_before_orientation_test() {
  let input =
    svg_path.Path([
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
      ]),
    ])
  let assert Error(offset.InternalBandOrientationConflict(_)) =
    offset.orient_band_path(input)
  let assert Ok(loops) = offset.enumerate_band_face_loops(input)
  check_fill(input, loops)
  let assert Ok(oriented) = offset.orient_band_path(loops)
  check_fill(input, oriented)
}

pub fn crossing_contours_follow_even_odd_independent_of_input_directions_test() {
  let a = square(0.0, 0.0, 3.0)
  let b = square(1.0, 1.0, 3.0)
  list.each([a, svg_path.subpath_reverse(a)], fn(a) {
    list.each([b, svg_path.subpath_reverse(b)], fn(b) {
      let input = svg_path.Path([a, b])
      let assert Ok(loops) = offset.enumerate_band_face_loops(input)
      assert list.length(svg_path.path_subpaths(loops)) == 2
      check_fill(input, loops)
      let assert Ok(oriented) = offset.orient_band_path(loops)
      check_fill(input, oriented)
    })
  })
}

pub fn kissing_seam_retains_two_occurrences_but_old_orientation_rejects_owners_test() {
  let input = svg_path.Path([square(0.0, 0.0, 2.0), square(2.0, 0.0, 2.0)])
  let assert Ok(loops) = offset.enumerate_band_face_loops(input)
  assert list.length(svg_path.path_subpaths(loops)) == 2
  assert segment_count(loops) == 8
  check_fill(input, loops)
  // Enumeration has the requested seam multiplicity. The unchanged orientation
  // policy still forbids two different contour owners on the same graph edge.
  let assert Error(offset.InternalBandOrientationUnexpectedEdge(_, 2)) =
    offset.orient_band_path(loops)
}

pub fn even_multiplicity_outside_fill_is_preserved_as_retraces_test() {
  let a = square(0.0, 0.0, 2.0)
  let input = svg_path.Path([a, a])
  let assert Ok(loops) = offset.enumerate_band_face_loops(input)
  assert segment_count(loops) == 8
  check_fill(input, loops)
  let assert Ok(oriented) = offset.orient_band_path(loops)
  check_fill(input, oriented)
}

pub fn triple_multiplicity_is_not_silently_dropped_test() {
  let a = square(0.0, 0.0, 2.0)
  let assert Ok(loops) =
    offset.enumerate_band_face_loops(svg_path.Path([a, a, a]))
  assert segment_count(loops) == 12
  check_fill(svg_path.Path([a, a, a]), loops)
  let assert Error(offset.InternalBandOrientationUnexpectedEdge(_, 3)) =
    offset.orient_band_path(loops)
}

pub fn empty_and_open_inputs_have_explicit_contracts_test() {
  assert offset.enumerate_band_face_loops(svg_path.path_empty())
    == Ok(svg_path.path_empty())
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
    ])
  assert offset.enumerate_band_face_loops(svg_path.Path([open]))
    == Error(offset.InternalBandSubpathNotClosed)
}
