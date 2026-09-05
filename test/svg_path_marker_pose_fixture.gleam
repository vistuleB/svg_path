import gleam/list
import gleam/option.{None, Some}
import svg_path
import svg_path/marker
import svg_path/svg
import svg_path/transform

fn document(
  things: svg.ThingsToDraw,
  width width: Float,
  height height: Float,
) -> String {
  svg.document(
    things: list.append(
      [
        svg.Rectangle(svg_path.Point(0.0, 0.0), width, height, "fill: #ffffff"),
      ],
      things,
    ),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(width, height),
    ),
  )
}

pub fn marker_pose_slots() -> String {
  let width = 900.0
  let height = 260.0
  let source = marker_pose_demo_subpath(72.0)
  let path = svg_path.Path([source])
  let assert Ok(poses) = marker.subpath_poses(source, orient: marker.Auto)

  document(
    [
      svg.Text(
        "marker.subpath_poses(...) returns start, mid, and end poses",
        marker_title_style(),
        svg_path.Point(450.0, 34.0),
        22.0,
      ),
      svg.StyledPath(path, marker_source_path_style()),
      ..list.append(
        marker_pose_points(poses),
        list.append(
          marker_glyphs(poses, marker_orientation_layout()),
          marker_pose_slot_labels(poses),
        ),
      )
    ],
    width:,
    height:,
  )
}

pub fn marker_orientation_semantics() -> String {
  let width = 900.0
  let height = 500.0
  let rows = [
    #("Auto", marker.Auto, 50.0),
    #("AutoStartReverse", marker.AutoStartReverse, 200.0),
    #("Fixed(0)", marker.Fixed(0.0), 350.0),
  ]

  document(
    [
      svg.Text(
        "marker.subpath_poses(...) orientation policies",
        marker_title_style(),
        svg_path.Point(450.0, 34.0),
        22.0,
      ),
      ..rows
      |> list.flat_map(fn(row) {
        let #(label, orient, y) = row
        marker_orientation_row(label, orient, y)
      })
    ],
    width:,
    height:,
  )
}

fn marker_orientation_row(
  label: String,
  orient: marker.MarkerOrient,
  y: Float,
) -> svg.ThingsToDraw {
  let source = marker_pose_demo_subpath(y)
  let path = svg_path.Path([source])
  let assert Ok(poses) = marker.subpath_poses(source, orient:)

  [
    svg.Text(label, marker_label_style(), svg_path.Point(38.0, y +. 60.0), 17.0),
    svg.StyledPath(path, marker_source_path_style()),
    ..list.append(
      marker_pose_points(poses),
      marker_glyphs(poses, marker_orientation_layout()),
    )
  ]
}

pub fn marker_reference_semantics() -> String {
  let width = 900.0
  let height = 380.0
  let rows = [
    #("refX at tail", svg_path.Point(0.0, 0.0), 80.0),
    #("refX at center", svg_path.Point(12.0, 0.0), 180.0),
    #("refX at tip", svg_path.Point(24.0, 0.0), 280.0),
  ]

  document(
    [
      svg.Text(
        "refX/refY pins one marker-local point to the path pose",
        marker_title_style(),
        svg_path.Point(450.0, 34.0),
        22.0,
      ),
      ..rows
      |> list.flat_map(fn(row) {
        let #(label, reference, y) = row
        marker_reference_row(label, reference, y)
      })
    ],
    width:,
    height:,
  )
}

fn marker_reference_row(
  label: String,
  reference: svg_path.Point,
  y: Float,
) -> svg.ThingsToDraw {
  let source = marker_reference_source_subpath(y)
  let pose = marker_end_pose_from_source(source)
  let layout =
    marker_layout(reference:, marker_width: 28.0, marker_height: 16.0)
  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)
  let assert Ok(glyph) = transform.path(marker_reference_shape(), by: matrix)
  let marker.MarkerPose(point:, ..) = pose
  let reference_point = transform.point(reference, by: matrix)

  [
    svg.Text(label, marker_label_style(), svg_path.Point(38.0, y +. 5.0), 17.0),
    svg.StyledPath(
      svg_path.Path([source]),
      "fill: none; stroke: #cbd5e1; stroke-width: 2",
    ),
    svg.Circle(point, 5.5, "fill: #111827"),
    svg.Circle(
      reference_point,
      9.0,
      "fill: none; stroke: #f59e0b; stroke-width: 3",
    ),
    svg.StyledPath(glyph, marker_fill_style("#0f766e")),
  ]
}

pub fn marker_units_semantics() -> String {
  let width = 980.0
  let height = 270.0
  let rows = [
    #("UserSpaceOnUse", marker_user_space_layout(), 94.0),
    #("StrokeWidth, stroke_width: 3", marker_stroke_width_layout(), 196.0),
  ]

  document(
    [
      svg.Text(
        "markerUnits changes the size of marker-local coordinates",
        marker_title_style(),
        svg_path.Point(490.0, 34.0),
        22.0,
      ),
      ..rows
      |> list.flat_map(fn(row) {
        let #(label, layout, y) = row
        marker_layout_row(label, layout, y)
      })
    ],
    width:,
    height:,
  )
}

pub fn marker_viewbox_semantics() -> String {
  let width = 980.0
  let height = 372.0
  let rows = [
    #("Stretch", marker_stretch_layout(), 94.0),
    #("Meet(XMidYMid)", marker_meet_layout(), 196.0),
    #("Slice(XMidYMid)", marker_slice_layout(), 298.0),
  ]

  document(
    [
      svg.Text(
        "viewBox + preserveAspectRatio changes marker content fitting",
        marker_title_style(),
        svg_path.Point(490.0, 34.0),
        22.0,
      ),
      ..rows
      |> list.flat_map(fn(row) {
        let #(label, layout, y) = row
        marker_layout_row(label, layout, y)
      })
    ],
    width:,
    height:,
  )
}

fn marker_layout_row(
  label: String,
  layout: marker.MarkerLayout,
  y: Float,
) -> svg.ThingsToDraw {
  let source = marker_layout_source_subpath(y)
  let pose = marker_end_pose_from_source(source)
  let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)
  let assert Ok(marker_body) =
    transform.path(marker_layout_body_shape(), by: matrix)
  let assert Ok(marker_content) =
    transform.path(marker_layout_content_shape(), by: matrix)
  let marker.MarkerPose(point:, ..) = pose
  let marker.MarkerLayout(reference:, ..) = layout
  let reference_point = transform.point(reference, by: matrix)

  [
    svg.Text(label, marker_label_style(), svg_path.Point(40.0, y +. 6.0), 16.0),
    svg.StyledPath(
      svg_path.Path([source]),
      "fill: none; stroke: #cbd5e1; stroke-width: 2",
    ),
    svg.Circle(point, 5.5, "fill: #111827"),
    svg.Circle(
      reference_point,
      8.0,
      "fill: none; stroke: #f59e0b; stroke-width: 2.5",
    ),
    svg.StyledPath(marker_body, marker_layout_body_style()),
    svg.StyledPath(marker_content, marker_layout_content_style()),
  ]
}

fn marker_reference_source_subpath(y: Float) -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(250.0, y),
      end: svg_path.Point(390.0, y),
    ),
  ])
}

fn marker_layout_source_subpath(y: Float) -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(360.0, y),
      end: svg_path.Point(500.0, y),
    ),
  ])
}

fn marker_end_pose_from_source(source: svg_path.Subpath) -> marker.MarkerPose {
  let assert Ok(poses) = marker.subpath_poses(source, orient: marker.Auto)
  let assert Ok(pose) =
    poses
    |> list.find(fn(pose) { pose.kind == marker.MarkerEnd })
  pose
}

fn marker_glyphs(
  poses: List(marker.MarkerPose),
  layout: marker.MarkerLayout,
) -> svg.ThingsToDraw {
  poses
  |> list.map(fn(pose) {
    let assert Ok(matrix) = marker.pose_layout_transform(pose, layout:)
    let assert Ok(glyph) =
      transform.path(marker_orientation_shape(), by: matrix)
    let fill = case pose.kind {
      marker.MarkerStart -> "#0f766e"
      marker.MarkerMid -> "#b45309"
      marker.MarkerEnd -> "#1d4ed8"
    }
    svg.StyledPath(glyph, marker_fill_style(fill))
  })
}

fn marker_pose_points(poses: List(marker.MarkerPose)) -> svg.ThingsToDraw {
  poses
  |> list.map(fn(pose) {
    let marker.MarkerPose(point:, ..) = pose
    svg.Circle(point, 4.4, "fill: #111827")
  })
}

fn marker_pose_slot_labels(poses: List(marker.MarkerPose)) -> svg.ThingsToDraw {
  poses
  |> list.map(fn(pose) {
    let marker.MarkerPose(kind:, point:, ..) = pose
    svg.Text(
      marker_pose_kind_label(kind),
      marker_label_style(),
      svg_path.Point(point.x, point.y +. 34.0),
      14.0,
    )
  })
}

fn marker_pose_kind_label(kind: marker.MarkerKind) -> String {
  case kind {
    marker.MarkerStart -> "start"
    marker.MarkerMid -> "mid"
    marker.MarkerEnd -> "end"
  }
}

fn marker_pose_demo_subpath(y: Float) -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(210.0, y +. 60.0),
      end: svg_path.Point(340.0, y +. 60.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(340.0, y +. 60.0),
      control1: svg_path.Point(405.0, y +. 0.0),
      control2: svg_path.Point(485.0, y +. 120.0),
      end: svg_path.Point(550.0, y +. 60.0),
    ),
    svg_path.Line(
      start: svg_path.Point(550.0, y +. 60.0),
      end: svg_path.Point(690.0, y +. 20.0),
    ),
  ])
}

fn marker_orientation_shape() -> svg_path.Path {
  marker_arrow_shape(length: 28.0, half_height: 9.0)
}

fn marker_reference_shape() -> svg_path.Path {
  marker_arrow_shape(length: 24.0, half_height: 8.0)
}

fn marker_layout_body_shape() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, -10.0),
      svg_path.Point(26.0, -10.0),
      svg_path.Point(36.0, 0.0),
      svg_path.Point(26.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ]),
  ])
}

fn marker_layout_content_shape() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert_polygon([
      svg_path.Point(5.0, -5.0),
      svg_path.Point(17.0, -5.0),
      svg_path.Point(17.0, 5.0),
      svg_path.Point(5.0, 5.0),
    ]),
  ])
}

fn marker_arrow_shape(
  length length: Float,
  half_height half_height: Float,
) -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0 -. half_height),
      svg_path.Point(length, 0.0),
      svg_path.Point(0.0, half_height),
    ]),
  ])
}

fn marker_orientation_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    reference: svg_path.Point(0.0, 0.0),
    marker_width: 28.0,
    marker_height: 18.0,
    marker_units: marker.UserSpaceOnUse,
    stroke_width: 1.0,
    view_box: None,
    preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
  )
}

fn marker_layout(
  reference reference: svg_path.Point,
  marker_width marker_width: Float,
  marker_height marker_height: Float,
) -> marker.MarkerLayout {
  marker.MarkerLayout(
    reference:,
    marker_width:,
    marker_height:,
    marker_units: marker.UserSpaceOnUse,
    stroke_width: 1.0,
    view_box: None,
    preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
  )
}

fn marker_user_space_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    reference: svg_path.Point(18.0, 0.0),
    marker_width: 36.0,
    marker_height: 20.0,
    marker_units: marker.UserSpaceOnUse,
    stroke_width: 1.0,
    view_box: None,
    preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
  )
}

fn marker_stroke_width_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    ..marker_user_space_layout(),
    marker_units: marker.StrokeWidth,
    stroke_width: 3.0,
  )
}

fn marker_stretch_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    ..marker_user_space_layout(),
    reference: svg_path.Point(18.0, 0.0),
    marker_width: 70.0,
    marker_height: 30.0,
    view_box: Some(marker_box(0.0, -10.0, 36.0, 20.0)),
    preserve_aspect_ratio: marker.Stretch,
  )
}

fn marker_meet_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    ..marker_stretch_layout(),
    preserve_aspect_ratio: marker.Meet(marker.XMidYMid),
  )
}

fn marker_slice_layout() -> marker.MarkerLayout {
  marker.MarkerLayout(
    ..marker_stretch_layout(),
    preserve_aspect_ratio: marker.Slice(marker.XMidYMid),
  )
}

fn marker_box(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(min_x, min_y),
    max: svg_path.Point(max_x, max_y),
  )
}

fn marker_source_path_style() -> String {
  "fill: none; stroke: #1e293b; stroke-width: 3.2; stroke-linecap: round; stroke-linejoin: round"
}

fn marker_fill_style(fill: String) -> String {
  "fill: "
  <> fill
  <> "; fill-opacity: 0.88; stroke: #111827; stroke-width: 1.2; stroke-linejoin: round"
}

fn marker_layout_body_style() -> String {
  "fill: #b45309; fill-opacity: 0.38; stroke: #111827; stroke-width: 1.25; stroke-linejoin: round"
}

fn marker_layout_content_style() -> String {
  "fill: none; stroke: #0f172a; stroke-width: 1.6; stroke-linejoin: round"
}

fn marker_title_style() -> String {
  "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700; text-anchor: middle"
}

fn marker_label_style() -> String {
  "fill: #334155; font-family: ui-monospace, SFMono-Regular, Menlo, monospace"
}
