import gleam/list
import gleam/option.{None, Some}
import svg_path
import svg_path/marker
import svg_path/transform

pub fn subpath_poses_returns_start_mid_and_end_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(20.0, 10.0),
    ])

  let assert Ok(poses) = marker.subpath_poses(subpath, orient: marker.Auto)

  assert list.length(poses) == 4
  assert poses
    == [
      marker.MarkerPose(
        kind: marker.MarkerStart,
        point: svg_path.point(0.0, 0.0),
        angle: 0.0,
      ),
      marker.MarkerPose(
        kind: marker.MarkerMid,
        point: svg_path.point(10.0, 0.0),
        angle: 45.0,
      ),
      marker.MarkerPose(
        kind: marker.MarkerMid,
        point: svg_path.point(10.0, 10.0),
        angle: 45.0,
      ),
      marker.MarkerPose(
        kind: marker.MarkerEnd,
        point: svg_path.point(20.0, 10.0),
        angle: 0.0,
      ),
    ]
}

pub fn auto_start_reverse_flips_only_start_pose_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(poses) =
    marker.subpath_poses(subpath, orient: marker.AutoStartReverse)

  assert poses
    == [
      marker.MarkerPose(
        kind: marker.MarkerStart,
        point: svg_path.point(0.0, 0.0),
        angle: 180.0,
      ),
      marker.MarkerPose(
        kind: marker.MarkerMid,
        point: svg_path.point(10.0, 0.0),
        angle: 45.0,
      ),
      marker.MarkerPose(
        kind: marker.MarkerEnd,
        point: svg_path.point(10.0, 10.0),
        angle: 90.0,
      ),
    ]
}

pub fn closed_subpath_auto_orients_start_and_end_like_corner_test() {
  let subpath =
    svg_path.subpath_assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(poses) = marker.subpath_poses(subpath, orient: marker.Auto)
  let assert [start, _, _, _, end] = poses

  assert start
    == marker.MarkerPose(
      kind: marker.MarkerStart,
      point: svg_path.point(0.0, 0.0),
      angle: -45.0,
    )
  assert end
    == marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(0.0, 0.0),
      angle: -45.0,
    )
}

pub fn closed_subpath_auto_start_reverse_flips_only_start_corner_test() {
  let subpath =
    svg_path.subpath_assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(poses) =
    marker.subpath_poses(subpath, orient: marker.AutoStartReverse)
  let assert [start, _, _, _, end] = poses

  assert start
    == marker.MarkerPose(
      kind: marker.MarkerStart,
      point: svg_path.point(0.0, 0.0),
      angle: 135.0,
    )
  assert end
    == marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(0.0, 0.0),
      angle: -45.0,
    )
}

pub fn fixed_orient_uses_one_absolute_angle_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(poses) =
    marker.subpath_poses(subpath, orient: marker.Fixed(12.0))

  assert poses
    |> list.map(fn(pose) {
      let marker.MarkerPose(angle:, ..) = pose
      angle
    })
    == [12.0, 12.0, 12.0]
}

pub fn opposite_mid_tangents_fall_back_to_incoming_angle_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(0.0, 0.0),
    ])

  let assert Ok([_, mid, _]) =
    marker.subpath_poses(subpath, orient: marker.Auto)

  assert mid
    == marker.MarkerPose(
      kind: marker.MarkerMid,
      point: svg_path.point(10.0, 0.0),
      angle: 0.0,
    )
}

pub fn pose_transform_places_marker_origin_at_pose_test() {
  let pose =
    marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(10.0, 20.0),
      angle: 90.0,
    )

  let matrix = marker.pose_transform(pose)

  assert transform.point(svg_path.point(0.0, 0.0), by: matrix)
    == svg_path.point(10.0, 20.0)
  assert transform.point(svg_path.point(2.0, 0.0), by: matrix)
    == svg_path.point(10.0, 22.0)
}

pub fn pose_transform_with_reference_places_reference_at_pose_test() {
  let pose =
    marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(10.0, 20.0),
      angle: 90.0,
    )

  let matrix =
    marker.pose_transform_with_reference(
      pose,
      reference: svg_path.point(2.0, 0.0),
    )

  assert transform.point(svg_path.point(2.0, 0.0), by: matrix)
    == svg_path.point(10.0, 20.0)
  assert transform.point(svg_path.point(3.0, 0.0), by: matrix)
    == svg_path.point(10.0, 21.0)
}

pub fn layout_transform_without_view_box_matches_reference_transform_test() {
  let pose = basic_pose()
  let layout =
    marker.MarkerLayout(..basic_layout(), reference: svg_path.point(2.0, 0.0))

  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)

  assert transform.point(svg_path.point(2.0, 0.0), by: matrix)
    == svg_path.point(10.0, 20.0)
  assert transform.point(svg_path.point(3.0, 0.0), by: matrix)
    == svg_path.point(10.0, 21.0)
}

pub fn layout_transform_scales_stroke_width_units_test() {
  let pose = basic_pose()
  let layout =
    marker.MarkerLayout(
      ..basic_layout(),
      reference: svg_path.point(2.0, 0.0),
      marker_units: marker.StrokeWidth,
      stroke_width: 4.0,
    )

  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)

  assert transform.point(svg_path.point(2.0, 0.0), by: matrix)
    == svg_path.point(10.0, 20.0)
  assert transform.point(svg_path.point(3.0, 0.0), by: matrix)
    == svg_path.point(10.0, 24.0)
}

pub fn layout_transform_stretches_view_box_test() {
  let pose =
    marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(100.0, 100.0),
      angle: 0.0,
    )
  let layout =
    marker.MarkerLayout(
      ..basic_layout(),
      reference: svg_path.point(10.0, 5.0),
      marker_width: 20.0,
      marker_height: 10.0,
      view_box: Some(box(0.0, 0.0, 10.0, 10.0)),
      preserve_aspect_ratio: marker.Stretch,
    )

  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)

  assert transform.point(svg_path.point(10.0, 5.0), by: matrix)
    == svg_path.point(100.0, 100.0)
  assert transform.point(svg_path.point(0.0, 5.0), by: matrix)
    == svg_path.point(80.0, 100.0)
}

pub fn layout_transform_meet_aligns_view_box_test() {
  let pose =
    marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(100.0, 100.0),
      angle: 0.0,
    )
  let layout =
    marker.MarkerLayout(
      ..basic_layout(),
      reference: svg_path.point(5.0, 5.0),
      marker_width: 20.0,
      marker_height: 10.0,
      view_box: Some(box(0.0, 0.0, 10.0, 10.0)),
      preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
    )

  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)

  assert transform.point(svg_path.point(5.0, 5.0), by: matrix)
    == svg_path.point(100.0, 100.0)
  assert transform.point(svg_path.point(0.0, 0.0), by: matrix)
    == svg_path.point(95.0, 95.0)
}

pub fn layout_transform_slice_aligns_view_box_test() {
  let pose =
    marker.MarkerPose(
      kind: marker.MarkerEnd,
      point: svg_path.point(100.0, 100.0),
      angle: 0.0,
    )
  let layout =
    marker.MarkerLayout(
      ..basic_layout(),
      reference: svg_path.point(5.0, 5.0),
      marker_width: 20.0,
      marker_height: 10.0,
      view_box: Some(box(0.0, 0.0, 10.0, 10.0)),
      preserve_aspect_ratio: marker.Slice(marker.XMidYMid),
    )

  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)

  assert transform.point(svg_path.point(5.0, 5.0), by: matrix)
    == svg_path.point(100.0, 100.0)
  assert transform.point(svg_path.point(0.0, 0.0), by: matrix)
    == svg_path.point(90.0, 90.0)
}

pub fn layout_transform_rejects_invalid_dimensions_test() {
  let pose = basic_pose()

  assert marker.pose_layout_transform(
      pose,
      layout: marker.MarkerLayout(..basic_layout(), marker_width: 0.0),
    )
    == Error(marker.InvalidMarkerWidth(0.0))
  assert marker.pose_layout_transform(
      pose,
      layout: marker.MarkerLayout(..basic_layout(), marker_height: 0.0),
    )
    == Error(marker.InvalidMarkerHeight(0.0))
  assert marker.pose_layout_transform(
      pose,
      layout: marker.MarkerLayout(
        ..basic_layout(),
        marker_units: marker.StrokeWidth,
        stroke_width: 0.0,
      ),
    )
    == Error(marker.InvalidStrokeWidth(0.0))
  assert marker.pose_layout_transform(
      pose,
      layout: marker.MarkerLayout(
        ..basic_layout(),
        view_box: Some(box(0.0, 0.0, 0.0, 10.0)),
      ),
    )
    == Error(marker.InvalidViewBox(box(0.0, 0.0, 0.0, 10.0)))
}

pub fn subpath_poses_rejects_empty_subpath_test() {
  let subpath = svg_path.subpath_empty(at: svg_path.point(0.0, 0.0))

  assert marker.subpath_poses(subpath, orient: marker.Auto)
    == Error(marker.EmptySubpath)
}

fn basic_pose() -> marker.MarkerPose {
  marker.MarkerPose(
    kind: marker.MarkerEnd,
    point: svg_path.point(10.0, 20.0),
    angle: 90.0,
  )
}

fn basic_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    reference: svg_path.point(0.0, 0.0),
    marker_width: 10.0,
    marker_height: 10.0,
    marker_units: marker.UserSpaceOnUse,
    stroke_width: 1.0,
    view_box: None,
    preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
  )
}

fn box(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.point(min_x, min_y),
    max: svg_path.point(max_x, max_y),
  )
}
