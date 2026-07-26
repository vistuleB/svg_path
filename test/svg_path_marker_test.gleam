import gleam/list
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

pub fn subpath_poses_rejects_empty_subpath_test() {
  let subpath = svg_path.subpath_empty(at: svg_path.point(0.0, 0.0))

  assert marker.subpath_poses(subpath, orient: marker.Auto)
    == Error(marker.EmptySubpath)
}
