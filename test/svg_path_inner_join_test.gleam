import gleam/list
import gleam/option.{Some}
import svg_path.{Point}
import svg_path/offset

fn corner(y: Float) -> svg_path.Subpath {
  svg_path.subpath_assert_polyline([
    Point(-10.0, 0.0),
    Point(0.0, 0.0),
    Point(0.0, y),
  ])
}

fn arc_count(subpath: svg_path.Subpath) -> Int {
  subpath
  |> svg_path.subpath_segments
  |> list.filter(fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
  |> list.length
}

pub fn inner_join_defaults_depend_on_join_style_test() {
  list.each(
    [offset.Bevel, offset.Miter(4.0), offset.MiterClip(4.0), offset.Arcs(4.0)],
    fn(join) {
      assert offset.subpath_untrimmed(corner(10.0), -1.0, join)
        == offset.subpath_untrimmed(corner(10.0), -1.0, offset.Bevel)
    },
  )
  let assert Ok(rounded) =
    offset.subpath_untrimmed(corner(10.0), -1.0, offset.Round)
  assert arc_count(rounded) == 1
}

pub fn inner_round_override_applies_to_all_join_styles_and_offset_signs_test() {
  let options =
    offset.Options(
      ..offset.default_options(),
      inner_join: Some(offset.InnerRound),
    )
  list.each([#(10.0, -1.0), #(-10.0, 1.0)], fn(pair) {
    let #(y, distance) = pair
    list.each(
      [
        offset.Bevel,
        offset.Miter(4.0),
        offset.MiterClip(4.0),
        offset.Arcs(4.0),
        offset.Round,
      ],
      fn(join) {
        assert offset.subpath_untrimmed_with(corner(y), distance, join, options)
          == offset.subpath_untrimmed(corner(y), distance, offset.Round)
      },
    )
  })
}

pub fn inner_bevel_override_does_not_change_outer_round_join_test() {
  let options =
    offset.Options(
      ..offset.default_options(),
      inner_join: Some(offset.InnerBevel),
    )
  assert offset.subpath_untrimmed_with(
      corner(10.0),
      -1.0,
      offset.Round,
      options,
    )
    == offset.subpath_untrimmed(corner(10.0), -1.0, offset.Bevel)
  assert offset.subpath_untrimmed_with(corner(10.0), 1.0, offset.Round, options)
    == offset.subpath_untrimmed(corner(10.0), 1.0, offset.Round)
}

pub fn band_inner_join_is_local_not_the_named_inner_offset_test() {
  let options =
    offset.Options(
      ..offset.default_options(),
      inner_join: Some(offset.InnerRound),
      band_trimming: offset.BandTrimming(False, False, False),
    )
  list.each([#(-1.0, 1.0), #(1.0, -1.0)], fn(pair) {
    let #(inner, outer) = pair
    let assert Ok(band) =
      offset.subpath_band_with(
        corner(10.0),
        inner,
        outer,
        offset.Bevel,
        offset.Butt,
        options,
      )
    let assert [outline] = svg_path.path_subpaths(band)
    assert arc_count(outline) == 1
    let assert Ok(beveled) =
      offset.subpath_band_with(
        corner(10.0),
        inner,
        outer,
        offset.Bevel,
        offset.Butt,
        offset.Options(..options, inner_join: Some(offset.InnerBevel)),
      )
    let assert [outline] = svg_path.path_subpaths(beveled)
    assert arc_count(outline) == 0
  })
}

pub fn inner_join_override_includes_closed_seam_test() {
  let square =
    svg_path.subpath_assert_polygon([
      Point(0.0, 0.0),
      Point(10.0, 0.0),
      Point(10.0, 10.0),
      Point(0.0, 10.0),
    ])
  let options =
    offset.Options(
      ..offset.default_options(),
      inner_join: Some(offset.InnerRound),
    )
  let assert Ok(rounded) =
    offset.subpath_untrimmed_with(square, -1.0, offset.Miter(4.0), options)
  assert arc_count(rounded) == 4
  assert svg_path.subpath_is_closed(rounded)
}
