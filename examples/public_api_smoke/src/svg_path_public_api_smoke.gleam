//// Compile and runtime smoke coverage for public geometry APIs on both targets.

import svg_path
import svg_path/arrangement
import svg_path/bounds
import svg_path/containment
import svg_path/csg
import svg_path/curvature
import svg_path/distance
import svg_path/fit
import svg_path/intersections
import svg_path/measure
import svg_path/offset
import svg_path/overlaps
import svg_path/stroke
import svg_path/svg

pub fn main() -> Nil {
  let _ =
    svg.Circle(center: svg_path.Point(1.0, 2.0), radius: 3.0, style: "fill:red")
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)

  let assert Ok(build) =
    arrangement.build(
      [left, right],
      tolerance: 0.000001,
      minimum_length: 0.00001,
    )
  let arrangement.ArrangementGraphBuild(graph:, segment_images:) = build
  let _ = graph
  let _ = segment_images

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let _ = union.path
  let _ = union.build
  let _ = csg.intersection(left, right, using: svg_path.Nonzero)
  let _ = csg.difference(left, minus: right, using: svg_path.Nonzero)
  let _ = csg.symmetric_difference(left, right, using: svg_path.EvenOdd)
  let _ = csg.nested_contours(svg_path.path_combine([left, right]))

  let horizontal =
    svg_path.Line(
      start: svg_path.Point(0.0, 5.0),
      end: svg_path.Point(10.0, 5.0),
    )
  let vertical =
    svg_path.Line(
      start: svg_path.Point(5.0, 0.0),
      end: svg_path.Point(5.0, 10.0),
    )
  let _ = intersections.segment(horizontal, vertical)
  let assert Ok([crossing]) =
    intersections.segment_subpath(
      horizontal,
      svg_path.segment_as_subpath(vertical),
    )
  let assert True =
    crossing
    == svg_path.SegmentSubpathIntersection(
      point: svg_path.Point(5.0, 5.0),
      segment_t: 0.5,
      subpath_parameters: [svg_path.SubpathParameter(segment_index: 0, t: 0.5)],
    )
  let assert True = crossing.segment_t == 0.5
  let _ = overlaps.segment(horizontal, horizontal)
  let _ = svg_path.segment_as_subpath(horizontal)
  let _ = svg_path.segment_as_path(vertical)
  let shared_options = offset.default_options()
  let assert Ok(_) =
    offset.subpath_with(
      svg_path.segment_as_subpath(horizontal),
      offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options: shared_options,
      trimming: offset.default_single_offset_trimming(),
    )
  let assert Ok(_) =
    offset.path_band_with(
      left,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options: shared_options,
      trimming: offset.default_band_trimming(),
    )
  let assert Ok(_) =
    stroke.path_with(
      left,
      width: 2.0,
      join: offset.Round,
      cap: offset.Butt,
      options: shared_options,
    )
  let open = svg_path.segment_as_subpath(horizontal)
  let assert False = svg_path.subpath_is_closed(open)
  let assert Error(svg_path.Discontinuous(..)) = svg_path.subpath_close(open)
  let assert Ok(closed) = svg_path.subpath_close_with(open, svg_path.Bridge)
  let assert True = svg_path.subpath_is_closed(closed)
  let reopened = svg_path.subpath_open(closed)
  let assert False = svg_path.subpath_is_closed(reopened)
  let assert True =
    svg_path.subpath_segments(reopened) == svg_path.subpath_segments(closed)
  let assert Ok(reclosed) = svg_path.subpath_close(reopened)
  let assert True = reclosed == closed
  let assert Error(curvature.InfiniteRadiusOfCurvature) =
    curvature.segment_left_normal_radius(horizontal, at: 0.5)
  let assert [] = curvature.segment_inflection_parameters(horizontal)

  let assert Ok(path_only) =
    csg.union_path(left, right, using: svg_path.Nonzero)
  let assert True = path_only == union.path
  let assert Ok(50.0) = measure.path_length(path_only)
  let assert Ok(box) = bounds.path_bounding_box(path_only)
  let assert True = bounds.bounding_box_width(box) == 15.0
  let assert Ok(svg_path.Inside) =
    containment.path_containment(
      svg_path.Point(7.0, 5.0),
      within: path_only,
      using: svg_path.Nonzero,
    )
  let assert Ok(pair) =
    distance.segment_segment_closest_pair(horizontal, vertical)
  let assert True = pair.distance == 0.0
  let assert Ok(fitted) =
    fit.subpath_from_parametric(from: 0.0, to: 1.0, point: fn(t) {
      svg_path.Point(t *. 10.0, 0.0)
    })
  let assert Ok(_) =
    stroke.subpath_with(
      fitted,
      width: 2.0,
      join: offset.Round,
      cap: offset.Butt,
      options: offset.default_options(),
    )
  Nil
}

fn rectangle(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  let a = svg_path.Point(min_x, min_y)
  let b = svg_path.Point(max_x, min_y)
  let c = svg_path.Point(max_x, max_y)
  let d = svg_path.Point(min_x, max_y)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])
    |> svg_path.subpath_assert_close()
  svg_path.subpath_as_path(subpath)
}
