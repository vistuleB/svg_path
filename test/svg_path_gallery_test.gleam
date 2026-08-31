import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import svg_path
import svg_path/convex_hull
import svg_path/csg
import svg_path/cut
import svg_path/effects
import svg_path/format as number_format
import svg_path/intersections
import svg_path/marker
import svg_path/offset
import svg_path/parse
import svg_path/serialize
import svg_path/stroke
import svg_path/svg
import svg_path/transform
import svg_path/trig
import svg_path_convex_hull_gallery_fixture as convex_hull_gallery_fixture
import svg_path_figure_eight_correspondence_fixture as figure_eight_correspondence_fixture

const output_dir = "test/generated/gallery"

const stalled_arc_turn_radius = 40.0

const stalled_arc_turn_distance = 39.999

const stalled_arc_turn_threshold = 0.01

const cut_radiator_square_size = 16.26195

const cut_radiator_path_data = "m 4.5284748,13.174906 q -0.375,0 -0.705,-0.24 -0.33,-0.24 -0.585,-0.78 -0.24,-0.555 -0.39,-1.47 -0.15,-0.9299998 -0.15,-2.2799998 0,-1.2 0.105,-2.025 0.105,-0.84 0.285,-1.38 0.195,-0.54 0.435,-0.84 0.24,-0.315 0.495,-0.435 0.27,-0.12 0.525,-0.12 0.51,0 0.855,0.345 0.36,0.345 0.51,1.08 l -0.465,0.525 -0.105,0.12 -0.075,-0.075 q -0.015,-0.12 0,-0.27 0.03,-0.15 -0.06,-0.375 -0.15,-0.3 -0.315,-0.39 -0.165,-0.09 -0.36,-0.09 -0.24,0 -0.435,0.225 -0.195,0.21 -0.345,0.675 -0.135,0.465 -0.21,1.2 -0.075,0.72 -0.075,1.755 0,0.99 0.075,1.7399998 0.09,0.75 0.24,1.245 0.165,0.495 0.36,0.75 0.195,0.24 0.42,0.24 0.195,0 0.33,-0.105 0.15,-0.105 0.27,-0.3 0.12,-0.21 0.225,-0.51 l 0.465,0.66 q -0.24,0.585 -0.555,0.855 -0.3,0.27 -0.765,0.27 z m 3.5949999,0.015 q -0.915,0 -1.215,-0.75 -0.3,-0.765 -0.3,-2.34 V 3.6799062 h 0.75 0.15 v 0.105 q -0.09,0.09 -0.12,0.195 -0.015,0.105 -0.015,0.36 v 5.7749998 q 0,1.155 0.165,1.725 0.165,0.555 0.585,0.54 0.435,-0.015 0.585,-0.615 0.165,-0.615 0.165,-1.695 V 3.6799062 h 0.765 v 6.3749998 q 0,1.155 -0.15,1.845 -0.15,0.69 -0.495,0.99 -0.33,0.3 -0.87,0.3 z m 3.4150003,-0.165 V 4.5049062 h -1.215 v -0.84 h 3.24 v 0.84 h -1.26 v 8.5199998 z"

pub fn main() -> Nil {
  generate_gallery_figures()
}

pub fn generate_gallery_figures() {
  let _ = ensure_dir(output_dir <> "/README.md")

  let figures = [
    #(
      "gallery-rounded-rectangle-union.svg",
      "Rounded rectangle union",
      rounded_rectangle_union(),
    ),
    #("gallery-stroke-caps.svg", "Stroke caps", stroke_caps()),
    #("gallery-dashed-strokes.svg", "Dashed strokes", dashed_strokes()),
    #("gallery-recursive-dashes.svg", "Recursive dashes", recursive_dashes()),
    #(
      "gallery-figure-eight-band.svg",
      "Figure-eight asymmetric band",
      figure_eight_band(),
    ),
    #(
      "gallery-symmetric-figure-eight-bands.svg",
      "Symmetric figure-eight bands",
      symmetric_figure_eight_bands(),
    ),
    #(
      "gallery-figure-eight-correspondence-blocks.svg",
      "Figure-eight synchronized correspondence blocks",
      figure_eight_correspondence_fixture.figure_eight_correspondence_blocks(),
    ),
    #(
      "gallery-figure-eight-convex-hulls.svg",
      "Figure-eight convex-hull regressions",
      convex_hull_gallery_fixture.figure_eight_hull_strip(),
    ),
    #(
      "gallery-stroke-offset-tracks.svg",
      "Stroke offset tracks",
      stroke_offset_tracks(),
    ),
    #(
      "gallery-earth-tone-offsets.svg",
      "Earth-tone offsets",
      earth_tone_offsets(),
    ),
    #(
      "gallery-package-title-first-offset.svg",
      "Package title first offset",
      package_title_first_offset(),
    ),
    #(
      "gallery-package-title-second-offset-arrangement.svg",
      "Package title second offset arrangement",
      generated_debug_svg(
        "examples/debug/package_title_second_offset_arrangement.svg",
      ),
    ),
    #(
      "gallery-stalled-offset-arc-turns.svg",
      "Stalled offset arc turns",
      stalled_arc_turn_svg(stalled_arc_turn_cases()),
    ),
    #(
      "gallery-stalled-offset-corner-zoom.svg",
      "Stalled offset corner zoom",
      stalled_arc_turn_zoom_svg(stalled_arc_turn_cases()),
    ),
    #(
      "gallery-khmer-coil-offset-map.svg",
      "Khmer fixed-radius coil offset map",
      generated_debug_svg("examples/debug/the_quick_brown_khmer_spiral_map.svg"),
    ),
    #(
      "gallery-khmer-decaying-spiral-offset-map.svg",
      "Khmer decaying spiral offset map",
      generated_debug_svg(
        "examples/debug/the_quick_brown_khmer_decaying_spiral_map.svg",
      ),
    ),
    #("gallery-crescent-hull.svg", "Crescent hull", crescent_hull()),
    #(
      "gallery-basic-shapes-ellipse-verification.svg",
      "Circle and ellipse construction verification",
      generated_debug_svg(
        "test/fixtures/gallery/basic-shapes-ellipse-verification.svg",
      ),
    ),
    #("gallery-cut-radiator.svg", "Cut radiator", cut_radiator()),
    #("gallery-marker-pose-slots.svg", "Marker pose slots", marker_pose_slots()),
    #(
      "gallery-marker-orient-semantics.svg",
      "Marker orientation semantics",
      marker_orientation_semantics(),
    ),
    #(
      "gallery-marker-reference-semantics.svg",
      "Marker reference semantics",
      marker_reference_semantics(),
    ),
    #(
      "gallery-marker-units-semantics.svg",
      "Marker units semantics",
      marker_units_semantics(),
    ),
    #(
      "gallery-marker-viewbox-semantics.svg",
      "Marker viewBox semantics",
      marker_viewbox_semantics(),
    ),
  ]

  let entries =
    figures
    |> list.map(fn(figure) {
      let #(filename, title, contents) = figure
      let _ = write_file(output_dir <> "/" <> filename, contents)
      "- [" <> title <> "](" <> filename <> ")"
    })

  let _ =
    write_file(
      output_dir <> "/README.md",
      "# Generated Gallery Figures\n\n" <> string.join(entries, "\n") <> "\n",
    )

  assert figures != []
}

fn marker_pose_slots() -> String {
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

fn marker_orientation_semantics() -> String {
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

fn marker_reference_semantics() -> String {
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

fn marker_units_semantics() -> String {
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

fn marker_viewbox_semantics() -> String {
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

fn rounded_rectangle_union() -> String {
  let rectangles = rectangle_stack()
  let assert Ok(union) =
    rectangles
    |> list.fold(Ok(svg_path.path_empty()), fn(acc, next) {
      use acc <- result_try(acc)
      csg.union(acc, next, using: svg_path.Nonzero)
      |> result.map(fn(result) {
        let csg.CsgResult(path:, ..) = result
        path
      })
    })
  let round_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )
  let assert Ok(rounded) =
    effects.round_corners_with(union, radius: 8.0, options: round_options)

  document(
    list.flatten([
      [panel(0.0, "rectangles")],
      [panel(250.0, "raw union")],
      [panel(500.0, "|> rounded_corners(..., 8.0)")],
      path_layer(
        rectangle_cloud_path(rectangles),
        0.0,
        fill: "#d9f99d",
        stroke: "#365314",
        width: 2.0,
        arrows: "#365314",
      ),
      path_layer(
        union,
        250.0,
        fill: "#bfdbfe",
        stroke: "#1f2937",
        width: 3.0,
        arrows: "#1f2937",
      ),
      path_layer(
        rounded,
        500.0,
        fill: "#bbf7d0",
        stroke: "#14532d",
        width: 3.0,
        arrows: "#14532d",
      ),
    ]),
    width: 730.0,
    height: 220.0,
  )
}

fn generated_debug_svg(path: String) -> String {
  let assert Ok(contents) = read_file(path)
  contents
}

fn cut_radiator() -> String {
  let assert Ok(cutter) = parse.path(cut_radiator_path_data)
  let snake = cut_radiator_snake(legs: 56)
  let assert Ok(cut_snake) =
    cut.path(subject: svg_path.subpath_as_path(snake), by: cutter)
  let assert Ok(kept) = keep_outside_cut(cut_snake, cutter)

  cut_radiator_document(kept)
}

fn cut_radiator_snake(legs legs: Int) -> svg_path.Subpath {
  let inset = 0.55
  let left = inset
  let right = cut_radiator_square_size -. inset
  let top = inset
  let bottom = cut_radiator_square_size -. inset
  let step = { bottom -. top } /. int.to_float(legs - 1)

  let segments =
    cut_radiator_segments(
      index: 0,
      legs:,
      left:,
      right:,
      y: top,
      step:,
      accumulated: [],
    )

  svg_path.subpath_assert(segments)
}

fn cut_radiator_segments(
  index index: Int,
  legs legs: Int,
  left left: Float,
  right right: Float,
  y y: Float,
  step step: Float,
  accumulated accumulated: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= legs {
    True -> accumulated
    False -> {
      let start_x = case index % 2 {
        0 -> left
        _ -> right
      }
      let end_x = case index % 2 {
        0 -> right
        _ -> left
      }
      let horizontal =
        svg_path.Line(
          start: svg_path.Point(start_x, y),
          end: svg_path.Point(end_x, y),
        )
      let accumulated = list.append(accumulated, [horizontal])

      case index == legs - 1 {
        True -> accumulated
        False -> {
          let next_y = y +. step
          let vertical =
            svg_path.Line(
              start: svg_path.Point(end_x, y),
              end: svg_path.Point(end_x, next_y),
            )
          cut_radiator_segments(
            index: index + 1,
            legs:,
            left:,
            right:,
            y: next_y,
            step:,
            accumulated: list.append(accumulated, [vertical]),
          )
        }
      }
    }
  }
}

fn keep_outside_cut(
  pieces: svg_path.Path,
  cutter: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  use kept <- result_try(
    pieces
    |> svg_path.path_subpaths
    |> keep_outside_cut_loop(cutter, kept: []),
  )
  Ok(svg_path.Path(kept))
}

fn keep_outside_cut_loop(
  pieces: List(svg_path.Subpath),
  cutter: svg_path.Path,
  kept kept: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case pieces {
    [] -> Ok(list.reverse(kept))
    [piece, ..rest] -> {
      use keep <- result_try(keep_cut_piece(piece, cutter))
      let kept = case keep {
        True -> [piece, ..kept]
        False -> kept
      }
      keep_outside_cut_loop(rest, cutter, kept:)
    }
  }
}

fn keep_cut_piece(
  piece: svg_path.Subpath,
  cutter: svg_path.Path,
) -> Result(Bool, svg_path.Error) {
  use length <- result_try(svg_path.subpath_length(piece))
  case length <=. 0.000001 {
    True -> Ok(False)
    False -> {
      use point <- result_try(svg_path.subpath_point_at_length(
        piece,
        length /. 2.0,
      ))
      use containment <- result_try(svg_path.path_containment(
        point,
        within: cutter,
        using: svg_path.Nonzero,
      ))
      case containment {
        svg_path.Inside -> Ok(False)
        svg_path.Outside | svg_path.Boundary -> Ok(True)
      }
    }
  }
}

fn cut_radiator_document(path: svg_path.Path) -> String {
  let scale = 26.0
  let margin = 36.0
  let width = margin *. 2.0 +. cut_radiator_square_size *. scale
  let height = width

  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 "
  <> gallery_float_to_string(width)
  <> " "
  <> gallery_float_to_string(height)
  <> "\" width=\""
  <> gallery_float_to_string(width)
  <> "\" height=\""
  <> gallery_float_to_string(height)
  <> "\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <g transform=\"translate("
  <> gallery_float_to_string(margin)
  <> " "
  <> gallery_float_to_string(margin)
  <> ") scale("
  <> gallery_float_to_string(scale)
  <> ")\">\n"
  <> "    <rect x=\"0\" y=\"0\" width=\""
  <> gallery_float_to_string(cut_radiator_square_size)
  <> "\" height=\""
  <> gallery_float_to_string(cut_radiator_square_size)
  <> "\" fill=\"#f8fafc\" stroke=\"#111827\" stroke-width=\"0.055\"/>\n"
  <> "    <path d=\""
  <> serialize.path(path)
  <> "\" fill=\"none\" stroke=\"#0f766e\" stroke-width=\"0.032\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n"
  <> "  </g>\n"
  <> "</svg>\n"
}

pub fn generate_recursive_dash_failure_zoom() {
  let _ = ensure_dir("examples/debug/recursive-dash-failure-zoom.svg")
  let drawing = recursive_dashes()
  let _ = write_file("examples/debug/recursive-dash-failure-zoom.svg", drawing)
  Nil
}

pub fn generate_recursive_dash_cap_report() {
  let _ = ensure_dir("examples/debug/recursive-dash-cap-report.txt")
  let source = place_subpath(recursive_dash_source(), 92.0, 154.0)
  let first_options =
    stroke.Options(
      width: 58.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(first_stroke) =
    stroke.subpath_dashed_with(
      source,
      options: first_options,
      dash_options: stroke.default_dash_options(
        pattern: [112.0, 48.0],
        offset: 10.0,
      ),
    )
  let outline = nth_subpath(svg_path.path_subpaths(first_stroke), 2)
  let assert Ok(dashes) =
    stroke.subpath_dashes(outline, pattern: [17.0, 9.0], offset: 3.0)
  let dash = nth_subpath(dashes, 4)
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let stroke_options =
    stroke.Options(width: 6.0, cap: stroke.Round, offset: options)
  let radius = 3.0
  let positive = offset.subpath_untrimmed_with(dash, offset: radius, options:)
  let negative =
    offset.subpath_untrimmed_with(dash, offset: 0.0 -. radius, options:)
  let start_cap = debug_round_start_cap(dash, radius)
  let end_cap = debug_round_end_cap(dash, radius)
  let candidate = case positive, negative, start_cap, end_cap {
    Ok(positive), Ok(negative), Ok(start_cap), Ok(end_cap) -> {
      let segments =
        list.append(
          svg_path.subpath_segments(positive),
          list.append(
            [end_cap],
            list.append(
              debug_reverse_segments(svg_path.subpath_segments(negative)),
              [
                start_cap,
              ],
            ),
          ),
        )
      case svg_path.subpath_with(segments, policy: svg_path.Wiggle) {
        Ok(candidate) ->
          svg_path.subpath_set_closed_with(
            candidate,
            closed: True,
            policy: svg_path.Wiggle,
          )
        Error(error) -> Error(error)
      }
    }
    _, _, _, _ -> Error(svg_path.EmptySubpath)
  }
  let report =
    string.join(
      [
        "dash index: 4",
        "dash segment count: "
          <> int.to_string(list.length(svg_path.subpath_segments(dash))),
        "dash length: "
          <> length_result_to_string(svg_path.subpath_length(dash)),
        "start point: " <> point_result_to_string(svg_path.subpath_start(dash)),
        "end point: " <> point_result_to_string(svg_path.subpath_end(dash)),
        "first derivative length at t=0: "
          <> derivative_length_result_to_string(first_segment(dash), 0.0),
        "last derivative length at t=1: "
          <> derivative_length_result_to_string(last_segment(dash), 1.0),
        "start cap: " <> cap_result_to_string(start_cap),
        "end cap: " <> cap_result_to_string(end_cap),
        "positive individual offset pieces: "
          <> individual_offset_piece_counts_to_string(
          svg_path.subpath_segments(dash),
          distance: radius,
          options: options,
        ),
        "negative individual offset pieces: "
          <> individual_offset_piece_counts_to_string(
          svg_path.subpath_segments(dash),
          distance: 0.0 -. radius,
          options: options,
        ),
        "positive side: " <> offset_subpath_result_to_string(positive),
        "negative side: " <> offset_subpath_result_to_string(negative),
        "positive inserted joins: "
          <> inserted_join_diameters_to_string(positive),
        "negative inserted joins: "
          <> inserted_join_diameters_to_string(negative),
        "positive raw pair 0->1 before join: "
          <> raw_offset_pair_report(
          svg_path.subpath_segments(dash),
          distance: radius,
          options: options,
        ),
        "negative raw pair 0->1 before join: "
          <> raw_offset_pair_report(
          svg_path.subpath_segments(dash),
          distance: 0.0 -. radius,
          options: options,
        ),
        "assembled candidate: " <> subpath_result_to_string(candidate),
        "candidate self intersections: "
          <> self_intersections_result_to_string(candidate),
        self_intersection_points_result_to_string(candidate),
        "full stroke result: "
          <> stroke_result_to_string(stroke.subpath_with(
          dash,
          options: stroke_options,
        )),
      ],
      "\n",
    )
  let _ = write_file("examples/debug/recursive-dash-cap-report.txt", report)
  Nil
}

fn stroke_caps() -> String {
  let source =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 20.0),
        control1: svg_path.Point(40.0, -58.0),
        control2: svg_path.Point(100.0, 78.0),
        end: svg_path.Point(150.0, 0.0),
      ),
    ])
  let examples = [
    #(0.0, "butt", offset.Butt),
    #(250.0, "square", offset.Square),
    #(500.0, "round", offset.RoundCap),
  ]

  document(
    list.flatten(
      examples
      |> list.map(fn(example) {
        let #(x, label, cap) = example
        let placed = place_subpath(source, x +. 42.0, 112.0)
        let options =
          offset.Options(..offset.default_options(), join: offset.Round)
        let assert Ok(stroke) =
          offset.subpath_stroke_with(placed, width: 28.0, cap:, options:)
        [
          panel(x, label),
          svg.StyledPath(
            stroke,
            "fill: #fed7aa; stroke: #7c2d12; stroke-width: 2.5; stroke-linejoin: round",
          ),
          svg.StyledPath(
            svg_path.subpath_as_path(placed),
            "fill: none; stroke: #4c1d95; stroke-width: 2; stroke-dasharray: 5 5; stroke-linecap: round",
          ),
          ..path_arrows(stroke, "#7c2d12", 1.0)
        ]
      }),
    ),
    width: 730.0,
    height: 220.0,
  )
}

fn dashed_strokes() -> String {
  let source = dash_source()
  let examples = [
    #(0.0, "short dashes", [18.0, 12.0], 0.0, "#7f1d1d", "#fecaca"),
    #(
      250.0,
      "offset pattern",
      [26.0, 12.0, 8.0, 12.0],
      18.0,
      "#854d0e",
      "#fde68a",
    ),
    #(500.0, "round caps", [34.0, 18.0], 9.0, "#14532d", "#bbf7d0"),
  ]

  document(
    list.flatten(
      examples
      |> list.map(fn(example) {
        let #(x, label, pattern, dash_offset, stroke_color, fill_color) =
          example
        let placed = place_subpath(source, x +. 22.0, 118.0)
        let options =
          stroke.Options(
            width: 16.0,
            cap: stroke.Round,
            offset: offset.Options(
              ..offset.default_options(),
              join: offset.Round,
            ),
          )
        let assert Ok(dashed) =
          stroke.subpath_dashed_with(
            placed,
            options:,
            dash_options: stroke.default_dash_options(
              pattern:,
              offset: dash_offset,
            ),
          )
        [
          panel(x, label),
          svg.StyledPath(
            dashed,
            "fill: "
              <> fill_color
              <> "; stroke: "
              <> stroke_color
              <> "; stroke-width: 2.2; stroke-linejoin: round",
          ),
          svg.StyledPath(
            svg_path.subpath_as_path(placed),
            "fill: none; stroke: #334155; stroke-width: 1.8; stroke-dasharray: 5 6; stroke-linecap: round",
          ),
          ..path_arrows(dashed, stroke_color, 0.8)
        ]
      }),
    ),
    width: 730.0,
    height: 220.0,
  )
}

fn recursive_dashes() -> String {
  let source = place_subpath(recursive_dash_source(), 92.0, 154.0)
  let first_dash_pattern = [112.0, 48.0]
  let first_dash_offset = 10.0
  let assert Ok(source) =
    recursive_dash_truncate_source(
      source,
      pattern: first_dash_pattern,
      offset: first_dash_offset,
    )
  let first_options =
    stroke.Options(
      width: 58.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(first_stroke) =
    stroke.subpath_dashed_with(
      source,
      options: first_options,
      dash_options: stroke.default_dash_options(
        pattern: first_dash_pattern,
        offset: first_dash_offset,
      ),
    )
  let second_options =
    stroke.Options(
      width: 6.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(second_paths) =
    recursive_dash_outline_strokes(
      svg_path.path_subpaths(first_stroke),
      options: second_options,
      accumulated: [],
    )
  let second_path =
    second_paths
    |> list.flat_map(svg_path.path_subpaths)
    |> svg_path.Path

  document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(8.0, 18.0),
          714.0,
          304.0,
          "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
        ),
        svg.StyledPath(
          first_stroke,
          "fill: #fed7aa; stroke: #9a3412; stroke-width: 1.4; stroke-linejoin: round; opacity: 0.42",
        ),
        svg.StyledPath(
          second_path,
          "fill: #fee2e2; stroke: #7f1d1d; stroke-width: 1.7; stroke-linejoin: round",
        ),
      ],
      [
        svg.StyledPath(
          svg_path.subpath_as_path(source),
          "fill: none; stroke: #334155; stroke-width: 1.8; stroke-linecap: round; stroke-dasharray: 7 7; opacity: 0.75",
        ),
      ],
      path_arrows(second_path, "#7f1d1d", 0.65),
    ]),
    width: 730.0,
    height: 340.0,
  )
}

fn recursive_dash_truncate_source(
  source: svg_path.Subpath,
  pattern pattern: List(Float),
  offset offset: Float,
) -> Result(svg_path.Subpath, svg_path.Error) {
  use length <- result.try(svg_path.subpath_length(source))
  let intervals = gallery_dash_intervals(length, pattern, offset: offset)
  case list.last(intervals) {
    Ok(#(_, last_distance)) ->
      svg_path.subpath_between_lengths(source, from: 0.0, to: last_distance)
    Error(_) -> Ok(source)
  }
}

fn gallery_dash_intervals(
  length: Float,
  pattern: List(Float),
  offset offset: Float,
) -> List(#(Float, Float)) {
  let pattern_length =
    list.fold(pattern, 0.0, fn(total, value) { total +. value })
  let offset = gallery_positive_remainder(offset, pattern_length)
  let #(index, remaining) = gallery_dash_start(pattern, offset, index: 0)
  gallery_dash_intervals_loop(
    length,
    pattern,
    position: 0.0,
    index:,
    remaining:,
    intervals: [],
  )
}

fn gallery_dash_start(
  pattern: List(Float),
  offset: Float,
  index index: Int,
) -> #(Int, Float) {
  case pattern {
    [] -> #(0, 0.0)
    [first, ..rest] -> {
      case offset <. first || rest == [] {
        True -> #(index, first -. offset)
        False -> gallery_dash_start(rest, offset -. first, index: index + 1)
      }
    }
  }
}

fn gallery_dash_intervals_loop(
  length: Float,
  pattern: List(Float),
  position position: Float,
  index index: Int,
  remaining remaining: Float,
  intervals intervals: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case position >=. length {
    True -> list.reverse(intervals)
    False if remaining <=. 0.0 -> {
      let next_index = gallery_next_dash_index(index, pattern)
      gallery_dash_intervals_loop(
        length,
        pattern,
        position:,
        index: next_index,
        remaining: gallery_dash_length_at(pattern, next_index),
        intervals:,
      )
    }
    False -> {
      let step = float.min(remaining, length -. position)
      let next = position +. step
      let intervals = case index % 2 == 0 && step >. 0.0 {
        True -> [#(position, next), ..intervals]
        False -> intervals
      }
      let next_index = gallery_next_dash_index(index, pattern)
      gallery_dash_intervals_loop(
        length,
        pattern,
        position: next,
        index: next_index,
        remaining: gallery_dash_length_at(pattern, next_index),
        intervals:,
      )
    }
  }
}

fn gallery_next_dash_index(index: Int, pattern: List(Float)) -> Int {
  let next = index + 1
  case next >= list.length(pattern) {
    True -> 0
    False -> next
  }
}

fn gallery_dash_length_at(pattern: List(Float), index: Int) -> Float {
  case list.drop(pattern, index) {
    [length, ..] -> length
    [] -> 0.0
  }
}

fn gallery_positive_remainder(value: Float, modulus: Float) -> Float {
  let turns = float.floor(value /. modulus)
  let remainder = value -. turns *. modulus
  case remainder <. 0.0 {
    True -> remainder +. modulus
    False ->
      case remainder >=. modulus {
        True -> remainder -. modulus
        False -> remainder
      }
  }
}

fn recursive_dash_outline_strokes(
  outlines: List(svg_path.Subpath),
  options options: stroke.Options,
  accumulated accumulated: List(svg_path.Path),
) -> Result(List(svg_path.Path), stroke.Error) {
  case outlines {
    [] -> Ok(list.reverse(accumulated))
    [outline, ..rest] -> {
      case stroke.subpath_dashes(outline, pattern: [17.0, 9.0], offset: 3.0) {
        Ok(dashes) -> {
          use stroked <- result_try(
            stroke_non_degenerate_dashes(dashes, options:, accumulated: []),
          )
          recursive_dash_outline_strokes(rest, options:, accumulated: [
            svg_path.Path(stroked),
            ..accumulated
          ])
        }
        Error(_) -> recursive_dash_outline_strokes(rest, options:, accumulated:)
      }
    }
  }
}

fn crescent_hull() -> String {
  let start = crescent_radius_point(-35.0)
  let end = crescent_radius_point(35.0)
  let points = crescent_points(54)
  let source =
    crescent_point_cloud_path(points, line_start: start, line_end: end)
  let reference = crescent_reference_path(start, end)
  let assert Ok(hull) = convex_hull.path_hull(source)
  let by = crescent_display_transform()
  let assert Ok(display_source) = transform.path(source, by:)
  let assert Ok(display_reference) = transform.path(reference, by:)
  let assert Ok(display_hull) = transform.path(svg_path.Path([hull]), by:)
  let display_points = points |> list.map(transform.point(_, by:))

  document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(8.0, 18.0),
          314.0,
          324.0,
          "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
        ),
        svg.StyledPath(
          display_reference,
          "fill: none; stroke: #94a3b8; stroke-width: 1.4; stroke-linecap: round",
        ),
        svg.StyledPath(
          display_source,
          "fill: none; stroke: #64748b; stroke-width: 1.2; stroke-linecap: round",
        ),
        svg.StyledPath(
          display_hull,
          "fill: #fed7aa; fill-opacity: 0.54; stroke: #9a3412; stroke-width: 2.4; stroke-linejoin: round",
        ),
      ],
      crescent_point_markers(display_points),
    ]),
    width: 330.0,
    height: 360.0,
  )
}

fn crescent_point_cloud_path(
  points: List(svg_path.Point),
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Path {
  let chord =
    svg_path.subpath_assert([
      svg_path.Line(start: line_start, end: line_end),
    ])
  let point_subpaths = points |> list.map(svg_path.subpath_empty(at: _))

  svg_path.Path([chord, ..point_subpaths])
}

fn crescent_reference_path(
  start: svg_path.Point,
  end: svg_path.Point,
) -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.Arc(
        start:,
        radius: svg_path.Point(120.0, 120.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end:,
      ),
    ]),
  ])
}

fn crescent_points(count: Int) -> List(svg_path.Point) {
  int.range(from: 0, to: count - 1, with: [], run: fn(points, index) {
    [crescent_point(index, count), ..points]
  })
  |> list.reverse
}

fn crescent_point(index: Int, count: Int) -> svg_path.Point {
  let angle = -33.5 +. int.to_float(index) *. 67.0 /. int.to_float(count - 1)
  let circle = crescent_radius_point(angle)
  let chord_x = 120.0 *. trig.cos_degrees(35.0)
  let fraction =
    0.1
    +. 0.82
    *. int.to_float({ { index * 61 + 43 } * { index * 31 + 29 } + 17 } % 10_000)
    /. 10_000.0

  svg_path.Point(chord_x +. fraction *. { circle.x -. chord_x }, circle.y)
}

fn crescent_radius_point(angle: Float) -> svg_path.Point {
  svg_path.Point(
    120.0 *. trig.cos_degrees(angle),
    120.0 *. trig.sin_degrees(angle),
  )
}

fn crescent_display_transform() -> transform.Matrix {
  transform.matrix(a: 5.8, b: 0.0, c: 0.0, d: 2.0, e: -482.4, f: 182.0)
}

fn crescent_point_markers(points: List(svg_path.Point)) -> svg.ThingsToDraw {
  points
  |> list.map(fn(point) {
    svg.Circle(point, 2.3, "fill: #166534; stroke: #f0fdf4; stroke-width: 0.8")
  })
}

fn stroke_non_degenerate_dashes(
  dashes: List(svg_path.Subpath),
  options options: stroke.Options,
  accumulated accumulated: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), stroke.Error) {
  case dashes {
    [] -> Ok(list.reverse(accumulated))
    [dash, ..rest] -> {
      case svg_path.subpath_length(dash) {
        Ok(length) if length >. 0.1 -> {
          case stroke.subpath_with(dash, options:) {
            Ok(stroked) ->
              stroke_non_degenerate_dashes(
                rest,
                options:,
                accumulated: list.append(
                  svg_path.path_subpaths(stroked),
                  accumulated,
                ),
              )
            Error(_) ->
              stroke_non_degenerate_dashes(rest, options:, accumulated:)
          }
        }
        _ -> stroke_non_degenerate_dashes(rest, options:, accumulated:)
      }
    }
  }
}

fn nth_subpath(
  subpaths: List(svg_path.Subpath),
  index: Int,
) -> svg_path.Subpath {
  let assert [first, ..rest] = subpaths
  case index <= 0 {
    True -> first
    False -> nth_subpath(rest, index - 1)
  }
}

fn first_segment(subpath: svg_path.Subpath) -> svg_path.Segment {
  let assert [first, ..] = svg_path.subpath_segments(subpath)
  first
}

fn last_segment(subpath: svg_path.Subpath) -> svg_path.Segment {
  let assert Ok(last) = list.last(svg_path.subpath_segments(subpath))
  last
}

fn debug_round_start_cap(
  source: svg_path.Subpath,
  radius: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  let first = first_segment(source)
  use tangent <- result_try(debug_unit_tangent(first, 0.0))
  use start <- result_try(svg_path.subpath_start(source))
  Ok(debug_round_cap(start, tangent, radius, at_end: False))
}

fn debug_round_end_cap(
  source: svg_path.Subpath,
  radius: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  let last = last_segment(source)
  use tangent <- result_try(debug_unit_tangent(last, 1.0))
  use end <- result_try(svg_path.subpath_end(source))
  Ok(debug_round_cap(end, tangent, radius, at_end: True))
}

fn debug_round_cap(
  center: svg_path.Point,
  tangent: svg_path.Point,
  radius: Float,
  at_end at_end: Bool,
) -> svg_path.Segment {
  let normal = svg_path.Point(tangent.y, 0.0 -. tangent.x)
  let positive = add_points(center, scale_point(normal, radius))
  let negative = add_points(center, scale_point(normal, 0.0 -. radius))
  let start = case at_end {
    True -> positive
    False -> negative
  }
  let end = case at_end {
    True -> negative
    False -> positive
  }
  svg_path.Arc(
    start:,
    radius: svg_path.Point(radius, radius),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: True,
    end:,
  )
}

fn debug_unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  use derivative <- result_try(svg_path.segment_derivative(segment, at: t))
  let length = point_length(derivative)
  case length >. 0.000001 {
    True -> Ok(scale_point(derivative, 1.0 /. length))
    False -> {
      let chord =
        subtract_points(
          svg_path.segment_end(segment),
          svg_path.segment_start(segment),
        )
      let length = point_length(chord)
      case length >. 0.000001 {
        True -> Ok(scale_point(chord, 1.0 /. length))
        False -> Error(svg_path.EmptySubpath)
      }
    }
  }
}

fn debug_reverse_segments(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  segments
  |> list.reverse
  |> list.map(svg_path.segment_reverse)
}

fn add_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn subtract_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x -. b.x, a.y -. b.y)
}

fn scale_point(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.Point(point.x *. factor, point.y *. factor)
}

fn length_result_to_string(result: Result(Float, svg_path.Error)) -> String {
  case result {
    Ok(length) -> debug_float_to_string(length)
    Error(_) -> "Error"
  }
}

fn point_result_to_string(
  result: Result(svg_path.Point, svg_path.Error),
) -> String {
  case result {
    Ok(point) -> point_to_string(point)
    Error(_) -> "Error"
  }
}

fn point_to_string(point: svg_path.Point) -> String {
  "("
  <> debug_float_to_string(point.x)
  <> ", "
  <> debug_float_to_string(point.y)
  <> ")"
}

fn derivative_length_result_to_string(
  segment: svg_path.Segment,
  t: Float,
) -> String {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> debug_float_to_string(point_length(derivative))
    Error(_) -> "Error"
  }
}

fn cap_result_to_string(
  result: Result(svg_path.Segment, svg_path.Error),
) -> String {
  case result {
    Ok(cap) ->
      "Ok(start="
      <> point_to_string(svg_path.segment_start(cap))
      <> ", end="
      <> point_to_string(svg_path.segment_end(cap))
      <> ")"
    Error(_) -> "Error"
  }
}

fn subpath_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Ok(subpath) ->
      "Ok(segments="
      <> int.to_string(list.length(svg_path.subpath_segments(subpath)))
      <> ", closed="
      <> bool_to_string(svg_path.subpath_is_closed(subpath))
      <> ", length="
      <> length_result_to_string(svg_path.subpath_length(subpath))
      <> ")"
    Error(_) -> "Error"
  }
}

fn offset_subpath_result_to_string(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Ok(subpath) -> subpath_summary_to_string(subpath)
    Error(error) -> offset_error_to_string(error)
  }
}

fn inserted_join_diameters_to_string(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(error) -> offset_error_to_string(error)
    Ok(subpath) ->
      inserted_join_diameters_loop(
        svg_path.subpath_segments(subpath),
        index: 0,
        joins: [],
      )
  }
}

fn raw_offset_pair_report(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
) -> String {
  let raw = raw_offset_segments(segments, distance:, options:, accumulated: [])
  case raw {
    [left, right, ..] -> {
      let left_end = svg_path.segment_end(left)
      let right_start = svg_path.segment_start(right)
      "left_end="
      <> point_to_string(left_end)
      <> "; right_start="
      <> point_to_string(right_start)
      <> "; gap="
      <> debug_float_to_string(point_distance(left_end, right_start))
      <> "; intersections="
      <> segment_intersections_to_string(intersections.segment(left, right))
    }
    _ -> "not enough raw offset segments"
  }
}

fn raw_offset_segments(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
  accumulated accumulated: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> list.reverse(accumulated)
    [segment, ..rest] -> {
      let next = case offset.segment_with(segment, offset: distance, options:) {
        Ok(subpath) -> list.reverse(svg_path.subpath_segments(subpath))
        Error(_) -> []
      }
      raw_offset_segments(
        rest,
        distance:,
        options:,
        accumulated: list.append(next, accumulated),
      )
    }
  }
}

fn segment_intersections_to_string(
  result: Result(List(svg_path.SegmentIntersection), svg_path.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(intersections) ->
      "count="
      <> int.to_string(list.length(intersections))
      <> "; "
      <> segment_intersection_list_to_string(intersections, index: 0)
  }
}

fn segment_intersection_list_to_string(
  intersections: List(svg_path.SegmentIntersection),
  index index: Int,
) -> String {
  case intersections {
    [] -> ""
    [first, ..rest] -> {
      let svg_path.SegmentIntersection(left_t:, right_t:, point:) = first
      int.to_string(index)
      <> ": left_t="
      <> debug_float_to_string(left_t)
      <> ", right_t="
      <> debug_float_to_string(right_t)
      <> ", point="
      <> point_to_string(point)
      <> case rest {
        [] -> ""
        _ -> "; "
      }
      <> segment_intersection_list_to_string(rest, index: index + 1)
    }
  }
}

fn inserted_join_diameters_loop(
  segments: List(svg_path.Segment),
  index index: Int,
  joins joins: List(String),
) -> String {
  case segments {
    [] -> {
      let joins = list.reverse(joins)
      "count="
      <> int.to_string(list.length(joins))
      <> "; "
      <> string.join(joins, "; ")
    }
    [segment, ..rest] -> {
      let joins = case segment {
        svg_path.Arc(..) -> [
          "segment "
            <> int.to_string(index)
            <> " bbox_diameter="
            <> segment_bounding_box_diameter_to_string(segment)
            <> " chord="
            <> debug_float_to_string(svg_path.segment_chord_length(segment)),
          ..joins
        ]
        _ -> joins
      }
      inserted_join_diameters_loop(rest, index: index + 1, joins:)
    }
  }
}

fn segment_bounding_box_diameter_to_string(
  segment: svg_path.Segment,
) -> String {
  case svg_path.segment_bounding_box(segment) {
    Ok(box) -> debug_float_to_string(svg_path.bounding_box_diameter(box))
    Error(_) -> "Error"
  }
}

fn individual_offset_piece_counts_to_string(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
) -> String {
  let counts =
    individual_offset_piece_counts(segments, distance:, options:, counts: [])
  "counts="
  <> string.join(counts, ",")
  <> "; total="
  <> int.to_string(sum_strings_as_ints(counts, total: 0))
}

fn individual_offset_piece_counts(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
  counts counts: List(String),
) -> List(String) {
  case segments {
    [] -> list.reverse(counts)
    [segment, ..rest] -> {
      let count = case
        offset.segment_with(segment, offset: distance, options:)
      {
        Ok(offset) ->
          int.to_string(list.length(svg_path.subpath_segments(offset)))
        Error(_) -> "Error"
      }
      individual_offset_piece_counts(rest, distance:, options:, counts: [
        count,
        ..counts
      ])
    }
  }
}

fn sum_strings_as_ints(strings: List(String), total total: Int) -> Int {
  case strings {
    [] -> total
    [first, ..rest] -> {
      let value = case first {
        "0" -> 0
        "1" -> 1
        "2" -> 2
        "3" -> 3
        "4" -> 4
        "5" -> 5
        _ -> 0
      }
      sum_strings_as_ints(rest, total: total + value)
    }
  }
}

fn subpath_summary_to_string(subpath: svg_path.Subpath) -> String {
  "Ok(segments="
  <> int.to_string(list.length(svg_path.subpath_segments(subpath)))
  <> ", closed="
  <> bool_to_string(svg_path.subpath_is_closed(subpath))
  <> ", length="
  <> length_result_to_string(svg_path.subpath_length(subpath))
  <> ")"
}

fn offset_error_to_string(error: offset.Error) -> String {
  case error {
    offset.DegenerateTangent(t) ->
      "DegenerateTangent(" <> debug_float_to_string(t) <> ")"
    _ -> "OffsetError"
  }
}

fn self_intersections_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Error(_) -> "not computed"
    Ok(subpath) -> {
      case
        intersections.subpath_self_with(
          subpath,
          options: intersections.default_self_intersection_options(),
        )
      {
        Ok(intersections) -> int.to_string(list.length(intersections))
        Error(_) -> "Error"
      }
    }
  }
}

fn self_intersection_points_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Error(_) -> "candidate self intersection points: not computed"
    Ok(subpath) -> {
      case
        intersections.subpath_self_with(
          subpath,
          options: intersections.default_self_intersection_options(),
        )
      {
        Ok(intersections) ->
          "candidate self intersection points:\n"
          <> self_intersection_points_to_string(intersections, index: 0)
        Error(_) -> "candidate self intersection points: Error"
      }
    }
  }
}

fn self_intersection_points_to_string(
  intersections: List(svg_path.SubpathSelfIntersection),
  index index: Int,
) -> String {
  case intersections {
    [] -> ""
    [intersection, ..rest] -> {
      let svg_path.SubpathSelfIntersection(point:, ..) = intersection
      "  "
      <> int.to_string(index)
      <> ": "
      <> point_to_string(point)
      <> "\n"
      <> self_intersection_points_to_string(rest, index: index + 1)
    }
  }
}

fn stroke_result_to_string(
  result: Result(svg_path.Path, stroke.Error),
) -> String {
  case result {
    Ok(path) ->
      "Ok(subpaths="
      <> int.to_string(list.length(svg_path.path_subpaths(path)))
      <> ")"
    Error(error) -> stroke_error_name(error)
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn debug_float_to_string(value: Float) -> String {
  number_format.number(
    value,
    with: number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(12),
      ),
      [value],
    ),
  )
}

fn stroke_error_name(error: stroke.Error) -> String {
  case error {
    stroke.OffsetError(offset.DegenerateTangent(t)) ->
      "OffsetError(DegenerateTangent(" <> debug_float_to_string(t) <> "))"
    stroke.OffsetError(_) -> "OffsetError(...)"
    stroke.PathError(_) -> "PathError(...)"
    stroke.InvalidWidth(_) -> "InvalidWidth"
    stroke.InvalidDashLength(_) -> "InvalidDashLength"
    stroke.InvalidDashOffset(_) -> "InvalidDashOffset"
    stroke.InvalidDashPatternLength -> "InvalidDashPatternLength"
  }
}

fn figure_eight_band() -> String {
  let source = place_subpath(figure_eight(), 430.0, 190.0)
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      inner_offset: 18.0,
      outer_offset: 34.0,
      options:,
    )

  document(
    list.flatten([
      [wide_panel()],
      [
        svg.StyledPath(
          band,
          "fill: #bbf7d0; stroke: #14532d; stroke-width: 3.2; stroke-linejoin: round",
        ),
      ],
      [
        svg.StyledPath(
          svg_path.subpath_as_path(source),
          "fill: none; stroke: #be123c; stroke-width: 2.2; stroke-dasharray: 7 6; stroke-linecap: round",
        ),
      ],
    ]),
    width: 860.0,
    height: 380.0,
  )
}

fn symmetric_figure_eight_bands() -> String {
  let assert Ok(contents) =
    read_file("examples/debug/loop_8_symmetric_arcs.svg")
  let assert Ok(svg_path.Path([source])) =
    parse.path(first_svg_path_data(contents))
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(wide_band) =
    offset.subpath_band_with(
      source,
      inner_offset: -5.0,
      outer_offset: 25.0,
      options:,
    )
  let assert Ok(outer_band) =
    offset.subpath_band_with(
      source,
      inner_offset: 10.0,
      outer_offset: 20.0,
      options:,
    )

  let left = symmetric_figure_eight_panel(source, wide_band, x: 20.0)
  let right = symmetric_figure_eight_panel(source, outer_band, x: 610.0)
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1200\" height=\"560\" viewBox=\"0 0 1200 560\">\n"
  <> "  <rect x=\"0\" y=\"0\" width=\"1200\" height=\"560\" fill=\"white\" />\n"
  <> "  <text x=\"305\" y=\"35\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"22\" fill=\"#3f3f46\">−5 to +25</text>\n"
  <> "  <text x=\"895\" y=\"35\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"22\" fill=\"#3f3f46\">+10 to +20</text>\n"
  <> left
  <> right
  <> "</svg>\n"
}

fn symmetric_figure_eight_panel(
  source: svg_path.Subpath,
  band: svg_path.Path,
  x x: Float,
) -> String {
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let geometry_width = max.x -. min.x
  let geometry_height = max.y -. min.y
  let padding = float.max(geometry_width, geometry_height) *. 0.12
  let view_x = min.x -. padding
  let view_y = min.y -. padding
  let view_width = geometry_width +. 2.0 *. padding
  let view_height = geometry_height +. 2.0 *. padding
  "  <svg x=\""
  <> gallery_float_to_string(x)
  <> "\" y=\"50\" width=\"570\" height=\"490\" viewBox=\""
  <> gallery_float_to_string(view_x)
  <> " "
  <> gallery_float_to_string(view_y)
  <> " "
  <> gallery_float_to_string(view_width)
  <> " "
  <> gallery_float_to_string(view_height)
  <> "\" preserveAspectRatio=\"xMidYMid meet\">\n"
  <> "    <path d=\""
  <> serialize.path(band)
  <> "\" fill=\"#d946ef\" fill-opacity=\"0.46\" fill-rule=\"nonzero\" stroke=\"#a21caf\" stroke-width=\"0.9\" stroke-linejoin=\"round\" />\n"
  <> "    <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#18181b\" stroke-width=\"0.8\" stroke-dasharray=\"4 3\" stroke-linecap=\"round\" />\n"
  <> "  </svg>\n"
}

fn first_svg_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

fn stroke_offset_tracks() -> String {
  let source = offset_track_source()
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let offsets = [
    #(-42.0, "#7f1d1d"),
    #(-28.0, "#c2410c"),
    #(-14.0, "#b45309"),
    #(14.0, "#047857"),
    #(28.0, "#0369a1"),
    #(42.0, "#6d28d9"),
  ]
  let tracks =
    offsets
    |> list.map(fn(entry) {
      let #(distance, color) = entry
      let assert Ok(track) =
        offset.subpath_untrimmed_with(source, offset: distance, options:)
      #(track, color)
    })
  let geometry_path =
    svg_path.Path([
      source,
      ..tracks
      |> list.map(fn(entry) {
        let #(track, _) = entry
        track
      })
    ])
  let assert Ok(box) = svg_path.path_bounding_box(geometry_path)
  let center = svg_path.bounding_box_center(box)
  let panel_center = svg_path.Point(365.0, 140.0)
  let dx = panel_center.x -. center.x
  let dy = panel_center.y -. center.y
  let assert Ok(source) = transform.translate_subpath(source, x: dx, y: dy)
  let tracks =
    tracks
    |> list.map(fn(entry) {
      let #(track, color) = entry
      let assert Ok(track) = transform.translate_subpath(track, x: dx, y: dy)
      #(track, color)
    })

  document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(8.0, 18.0),
          714.0,
          244.0,
          "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
        ),
      ],
      tracks
        |> list.map(fn(entry) {
          let #(track, color) = entry
          svg.StyledPath(
            svg_path.subpath_as_path(track),
            "fill: none; stroke: "
              <> color
              <> "; stroke-width: 3.2; stroke-linecap: round; stroke-linejoin: round",
          )
        }),
      [
        svg.StyledPath(
          svg_path.subpath_as_path(source),
          "fill: none; stroke: #111827; stroke-width: 3.6; stroke-dasharray: 7 6; stroke-linecap: round",
        ),
      ],
      subpath_arrows(source, "#111827", 1.0),
    ]),
    width: 730.0,
    height: 280.0,
  )
}

fn earth_tone_offsets() -> String {
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let colors = ["#5f4339", "#8a5a3c", "#a36a2d", "#7c6a3d", "#51633f"]
  document(
    list.flatten([
      [panel(0.0, "soft arc")],
      [panel(250.0, "bending line")],
      [panel(500.0, "quiet turn")],
      centered_offset_family(
        source: earth_arc_source(),
        panel_center: svg_path.Point(119.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
      centered_offset_family(
        source: earth_bend_source(),
        panel_center: svg_path.Point(369.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
      centered_offset_family(
        source: earth_turn_source(),
        panel_center: svg_path.Point(619.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
    ]),
    width: 730.0,
    height: 220.0,
  )
}

fn package_title_first_offset() -> String {
  let assert Ok(contents) = read_file("examples/debug/package_title.svg")
  let assert Ok(source) = parse.path(package_title_first_path_data(contents))
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )
  let distance = 1.05
  let assert Ok(untrimmed) =
    offset.path_untrimmed_with(source, offset: distance, options:)
  let assert Ok(trimmed) = offset.path_with(source, offset: distance, options:)
  package_title_first_offset_document(source, untrimmed, trimmed)
}

fn package_title_first_offset_document(
  source: svg_path.Path,
  untrimmed: svg_path.Path,
  trimmed: svg_path.Path,
) -> String {
  let boxes = path_boxes([source, untrimmed, trimmed])
  let view_box = padded_box(boxes, margin: 3.0)
  let things = [
    gallery_background(view_box),
    svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.18"),
    svg.StyledPath(
      untrimmed,
      "fill: none; stroke: #9ca3af; stroke-width: 0.10; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.StyledPath(
      trimmed,
      "fill: none; stroke: #2563eb; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.Text(
      "gray = untrimmed; blue = trimmed single offset, distance 1.05",
      "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
      svg_path.Point(view_box.min.x +. 1.0, view_box.min.y +. 1.2),
      0.9,
    ),
  ]

  svg.document(things:, view_box:)
  |> gallery_with_root_size(width: 1800, height: 420)
}

fn package_title_first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

fn path_boxes(paths: List(svg_path.Path)) -> List(svg_path.BoundingBox) {
  paths
  |> list.filter_map(svg_path.path_bounding_box)
}

fn gallery_background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined =
    list.fold(boxes, first, fn(acc, box) { combine_boxes(acc, box) })
  let svg_path.BoundingBox(min:, max:) = combined

  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn combine_boxes(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(
      float.min(left.min.x, right.min.x),
      float.min(left.min.y, right.min.y),
    ),
    max: svg_path.Point(
      float.max(left.max.x, right.max.x),
      float.max(left.max.y, right.max.y),
    ),
  )
}

fn gallery_with_root_size(
  svg_document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(svg_document, on: "\" width=\"")
  let assert Ok(#(_, after_height)) =
    string.split_once(after_width, on: "\" height=\"")
  let assert Ok(#(_, rest)) = string.split_once(after_height, on: "\">")

  before_width
  <> "\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\">"
  <> rest
}

fn centered_offset_family(
  source source: svg_path.Subpath,
  panel_center panel_center: svg_path.Point,
  distances distances: List(Float),
  colors colors: List(String),
  options options: offset.Options,
) -> svg.ThingsToDraw {
  let tracks =
    distances
    |> list.map(fn(distance) {
      let assert Ok(track) =
        offset.subpath_untrimmed_with(source, offset: distance, options:)
      track
    })
  let geometry_path = svg_path.Path([source, ..tracks])
  let assert Ok(box) = svg_path.path_bounding_box(geometry_path)
  let center = svg_path.bounding_box_center(box)
  let dx = panel_center.x -. center.x
  let dy = panel_center.y -. center.y
  let assert Ok(placed_source) =
    transform.translate_subpath(source, x: dx, y: dy)
  let placed_tracks =
    tracks
    |> list.map(fn(track) {
      let assert Ok(placed) = transform.translate_subpath(track, x: dx, y: dy)
      placed
    })

  list.flatten([
    placed_tracks
      |> list.index_map(fn(track, index) {
        let color = color_from(colors, index)
        svg.StyledPath(
          svg_path.subpath_as_path(track),
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 2.8; stroke-linecap: round; stroke-linejoin: round",
        )
      }),
    [
      svg.StyledPath(
        svg_path.subpath_as_path(placed_source),
        "fill: none; stroke: #1f1a17; stroke-width: 3.1; stroke-dasharray: 7 6; stroke-linecap: round; stroke-linejoin: round",
      ),
    ],
  ])
}

fn color_from(colors: List(String), index: Int) -> String {
  case colors |> list.drop(index % list.length(colors)) {
    [color, ..] -> color
    [] -> "#1f2937"
  }
}

fn rectangle_stack() -> List(svg_path.Path) {
  [
    square_path(0.0, 22.0, 96.0),
    rectangle_path(42.0, 0.0, 150.0, 64.0),
    rectangle_path(118.0, 38.0, 210.0, 118.0),
    rectangle_path(24.0, 88.0, 146.0, 146.0),
    rectangle_path(152.0, 86.0, 226.0, 152.0),
  ]
}

fn rectangle_cloud_path(paths: List(svg_path.Path)) -> svg_path.Path {
  paths
  |> list.flat_map(svg_path.path_subpaths)
  |> svg_path.Path
}

fn square_path(x: Float, y: Float, size: Float) -> svg_path.Path {
  svg_path.subpath_as_path(square_subpath(x, y, size))
}

fn rectangle_path(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  svg_path.subpath_as_path(
    svg_path.subpath_assert_polygon([
      svg_path.Point(min_x, min_y),
      svg_path.Point(max_x, min_y),
      svg_path.Point(max_x, max_y),
      svg_path.Point(min_x, max_y),
    ]),
  )
}

fn square_subpath(x: Float, y: Float, size: Float) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(x, y),
    svg_path.Point(x +. size, y),
    svg_path.Point(x +. size, y +. size),
    svg_path.Point(x, y +. size),
  ])
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(-336.0, -234.0),
      control2: svg_path.Point(-336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(336.0, -234.0),
      control2: svg_path.Point(336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn stalled_arc_turn_cases() -> List(
  #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
) {
  let subdivisions = [1, 4, 30]
  list.append(
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case("real arcs", "arc", count, use_arcs: True)
      }),
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case(
          "cubic approximation",
          "cubic",
          count,
          use_arcs: False,
        )
      }),
  )
}

fn stalled_arc_turn_case(
  row_label: String,
  unit_label: String,
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> #(
  String,
  String,
  Int,
  svg_path.Subpath,
  Result(svg_path.Subpath, offset.Error),
) {
  let source = stalled_arc_turn_source(subdivisions, use_arcs:)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.001),
      join: offset.Round,
    )
  let result =
    offset.subpath_untrimmed_with(
      source,
      offset: stalled_arc_turn_distance,
      options:,
    )
  #(row_label, unit_label, subdivisions, source, result)
}

fn stalled_arc_turn_source(
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> svg_path.Subpath {
  let r = stalled_arc_turn_radius
  let arc_start = circle_point(0.0, radius: r)
  let arc_end = circle_point(-90.0, radius: r)
  let turn_segments = case use_arcs {
    True -> quarter_turn_arcs(subdivisions)
    False -> quarter_turn_cubics(subdivisions)
  }
  let segments = [
    svg_path.Line(start: svg_path.Point(r, r), end: arc_start),
    ..list.append(turn_segments, [
      svg_path.Line(start: arc_end, end: svg_path.Point(0.0 -. r, 0.0 -. r)),
    ])
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  subpath
}

fn quarter_turn_arcs(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_arcs_loop(0, subdivisions, arcs: [])
}

fn quarter_turn_arcs_loop(
  index: Int,
  subdivisions: Int,
  arcs arcs: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(arcs)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_arcs_loop(index + 1, subdivisions, arcs: [
        circle_arc_segment(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..arcs
      ])
    }
  }
}

fn circle_arc_segment(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  svg_path.Arc(
    start: circle_point(start_angle, radius:),
    radius: svg_path.Point(radius, radius),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: False,
    end: circle_point(end_angle, radius:),
  )
}

fn quarter_turn_cubics(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_cubics_loop(0, subdivisions, cubics: [])
}

fn quarter_turn_cubics_loop(
  index: Int,
  subdivisions: Int,
  cubics cubics: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(cubics)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_cubics_loop(index + 1, subdivisions, cubics: [
        circle_arc_cubic(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..cubics
      ])
    }
  }
}

fn circle_arc_cubic(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  let start = circle_point(start_angle, radius:)
  let end = circle_point(end_angle, radius:)
  let k = 4.0 /. 3.0 *. trig.tan_degrees({ end_angle -. start_angle } /. 4.0)
  let start_tangent = circle_angle_tangent(start_angle)
  let end_tangent = circle_angle_tangent(end_angle)
  svg_path.CubicBezier(
    start:,
    control1: add(start, scale(start_tangent, k *. radius)),
    control2: subtract_points(end, scale(end_tangent, k *. radius)),
    end:,
  )
}

fn circle_point(angle: Float, radius radius: Float) -> svg_path.Point {
  svg_path.Point(
    clean_zero(radius *. trig.cos_degrees(angle)),
    clean_zero(radius *. trig.sin_degrees(angle)),
  )
}

fn clean_zero(value: Float) -> Float {
  case float.absolute_value(value) <=. 0.000000000001 {
    True -> 0.0
    False -> value
  }
}

fn circle_angle_tangent(angle: Float) -> svg_path.Point {
  svg_path.Point(0.0 -. trig.sin_degrees(angle), trig.cos_degrees(angle))
}

fn count_stalled_segments(segments: List(svg_path.Segment)) -> Int {
  segments
  |> list.filter(stalled_arc_turn_segment_is_caught)
  |> list.length
}

fn stalled_arc_turn_segment_is_caught(segment: svg_path.Segment) -> Bool {
  let start = offset_endpoint(segment, 0.0)
  let end = offset_endpoint(segment, 1.0)
  case start, end {
    Ok(start), Ok(end) ->
      point_distance(start, end) <=. stalled_arc_turn_threshold
    _, _ -> False
  }
}

fn offset_endpoint(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case
    svg_path.segment_point(segment, at: t),
    svg_path.segment_derivative(segment, at: t)
  {
    Ok(point), Ok(derivative) -> {
      let normal = right_unit_normal(derivative)
      Ok(add(point, scale(normal, stalled_arc_turn_distance)))
    }
    _, _ -> Error(Nil)
  }
}

fn right_unit_normal(point: svg_path.Point) -> svg_path.Point {
  let length = point_length(point)
  svg_path.Point(point.y /. length, { 0.0 -. point.x } /. length)
}

fn stalled_arc_turn_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 570\" width=\"860\" height=\"570\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"28\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"16\" text-anchor=\"middle\" fill=\"#111827\">near-collapsed quarter-turn offsets</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_zoom_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 650\" width=\"860\" height=\"650\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"30\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"15\" text-anchor=\"middle\" fill=\"#111827\">corner zoom; distance="
  <> gallery_float_to_string(stalled_arc_turn_distance)
  <> "; threshold="
  <> gallery_float_to_string(stalled_arc_turn_threshold)
  <> "</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_zoom_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let column = index % 3
  let row = index / 3
  let tx = 145.0 +. int.to_float(column) *. 280.0
  let ty = 145.0 +. int.to_float(row) *. 260.0
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #2563eb; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round\" />\n"
    Error(error) ->
      "    <text x=\"0\" y=\"24\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"7\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> gallery_float_to_string(tx)
  <> " "
  <> gallery_float_to_string(ty)
  <> ") scale(2)\">\n"
  <> "    <rect x=\"-58\" y=\"-58\" width=\"116\" height=\"88\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.7\" />\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #9ca3af; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> "  </g>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(tx)
  <> "\" y=\""
  <> gallery_float_to_string(ty +. 105.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"12\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "</text>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(tx)
  <> "\" y=\""
  <> gallery_float_to_string(ty +. 122.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#334155\">corner segments="
  <> stalled_arc_turn_corner_segment_count(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.subpath_segments(source)))
  <> "</text>"
}

fn stalled_arc_turn_zoom_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let #(clip_x, clip_y, clip_size) = stalled_arc_turn_zoom_box(source, result)
  let scale = 220.0 /. clip_size
  let column = index % 3
  let row = index / 3
  let panel_x = 145.0 +. int.to_float(column) *. 280.0
  let panel_y = 170.0 +. int.to_float(row) *. 260.0
  let tx = panel_x -. { clip_x +. clip_size /. 2.0 } *. scale
  let ty = panel_y -. { clip_y +. clip_size /. 2.0 } *. scale
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #1d4ed8; stroke-width: 0.00008; stroke-linecap: round; stroke-linejoin: round\" />\n"
      <> "    <circle cx=\"0\" cy=\"0\" r=\"0.00008\" fill=\"#111827\" />\n"
      <> stalled_arc_turn_output_control_marks(subpath)
    Error(error) ->
      "    <text x=\"0\" y=\"0.0016\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.0003\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> gallery_float_to_string(tx)
  <> " "
  <> gallery_float_to_string(ty)
  <> ") scale("
  <> gallery_float_to_string(scale)
  <> ")\">\n"
  <> "    <clipPath id=\"corner-zoom-clip-"
  <> int.to_string(index)
  <> "\"><rect x=\""
  <> gallery_float_to_string(clip_x)
  <> "\" y=\""
  <> gallery_float_to_string(clip_y)
  <> "\" width=\""
  <> gallery_float_to_string(clip_size)
  <> "\" height=\""
  <> gallery_float_to_string(clip_size)
  <> "\" /></clipPath>\n"
  <> "    <rect x=\""
  <> gallery_float_to_string(clip_x)
  <> "\" y=\""
  <> gallery_float_to_string(clip_y)
  <> "\" width=\""
  <> gallery_float_to_string(clip_size)
  <> "\" height=\""
  <> gallery_float_to_string(clip_size)
  <> "\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.00003\" />\n"
  <> "    <g clip-path=\"url(#corner-zoom-clip-"
  <> int.to_string(index)
  <> ")\">\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #cbd5e1; stroke-width: 0.000035; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 0.000055; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> stalled_arc_turn_fit_marks(source)
  <> "    </g>\n"
  <> "  </g>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(panel_x)
  <> "\" y=\""
  <> gallery_float_to_string(panel_y +. 132.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "; corner "
  <> stalled_arc_turn_corner_label(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.subpath_segments(source)))
  <> "</text>"
}

fn stalled_arc_turn_zoom_box(
  source: svg_path.Subpath,
  result: Result(svg_path.Subpath, offset.Error),
) -> #(Float, Float, Float) {
  let points =
    list.append(
      stalled_arc_turn_offset_sample_points(source),
      stalled_arc_turn_corner_diagnostic_points(result),
    )

  case points {
    [] -> #(-0.004, -0.008, 0.01)
    [first, ..rest] -> {
      let #(min_x, min_y, max_x, max_y) =
        rest
        |> list.fold(#(first.x, first.y, first.x, first.y), fn(box, point) {
          let #(min_x, min_y, max_x, max_y) = box
          #(
            float.min(min_x, point.x),
            float.min(min_y, point.y),
            float.max(max_x, point.x),
            float.max(max_y, point.y),
          )
        })
      let width = max_x -. min_x
      let height = max_y -. min_y
      let size = float.max(float.max(width, height) *. 1.3, 0.002)
      let center_x = { min_x +. max_x } /. 2.0
      let center_y = { min_y +. max_y } /. 2.0
      #(center_x -. size /. 2.0, center_y -. size /. 2.0, size)
    }
  }
}

fn stalled_arc_turn_offset_sample_points(
  source: svg_path.Subpath,
) -> List(svg_path.Point) {
  let stalled =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_points(stalled)
}

fn stalled_arc_turn_sample_points(
  segments: List(svg_path.Segment),
) -> List(svg_path.Point) {
  stalled_arc_turn_sample_points_loop(segments, points: [])
}

fn stalled_arc_turn_sample_points_loop(
  segments: List(svg_path.Segment),
  points points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case segments {
    [] -> list.reverse(points)
    [first, ..rest] -> {
      let points =
        stalled_arc_turn_segment_sample_points(first, [0.25, 0.5, 0.75], points)
      stalled_arc_turn_sample_points_loop(rest, points:)
    }
  }
}

fn stalled_arc_turn_segment_sample_points(
  segment: svg_path.Segment,
  samples: List(Float),
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case samples {
    [] -> points
    [t, ..rest] -> {
      let points = case offset_endpoint(segment, t) {
        Ok(point) -> [point, ..points]
        Error(_) -> points
      }
      stalled_arc_turn_segment_sample_points(segment, rest, points)
    }
  }
}

fn stalled_arc_turn_corner_diagnostic_points(
  result: Result(svg_path.Subpath, offset.Error),
) -> List(svg_path.Point) {
  case result {
    Error(_) -> []
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.flat_map(stalled_arc_turn_segment_diagnostic_points)
  }
}

fn stalled_arc_turn_segment_diagnostic_points(
  segment: svg_path.Segment,
) -> List(svg_path.Point) {
  case segment {
    svg_path.Line(start:, end:) -> [start, end]
    svg_path.QuadraticBezier(start:, control:, end:) -> [start, control, end]
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> [
      start,
      control1,
      control2,
      end,
    ]
    svg_path.Arc(start:, end:, ..) -> [start, end]
  }
}

fn stalled_arc_turn_output_control_marks(subpath: svg_path.Subpath) -> String {
  case svg_path.subpath_segments(subpath) {
    [_, svg_path.CubicBezier(control1:, control2:, ..), ..] ->
      "    <circle cx=\""
      <> gallery_float_to_string(control1.x)
      <> "\" cy=\""
      <> gallery_float_to_string(control1.y)
      <> "\" r=\"0.00007\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> gallery_float_to_string(control1.x)
      <> "\" y=\""
      <> gallery_float_to_string(control1.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c1</text>\n"
      <> "    <circle cx=\""
      <> gallery_float_to_string(control2.x)
      <> "\" cy=\""
      <> gallery_float_to_string(control2.y)
      <> "\" r=\"0.00007\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> gallery_float_to_string(control2.x)
      <> "\" y=\""
      <> gallery_float_to_string(control2.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c2</text>\n"
    _ -> ""
  }
}

fn stalled_arc_turn_fit_marks(source: svg_path.Subpath) -> String {
  let stalled =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_marks(stalled)
  <> stalled_arc_turn_tangent_marks(stalled)
}

fn stalled_arc_turn_sample_marks(segments: List(svg_path.Segment)) -> String {
  stalled_arc_turn_sample_marks_loop(segments, marks: "")
}

fn stalled_arc_turn_sample_marks_loop(
  segments: List(svg_path.Segment),
  marks marks: String,
) -> String {
  case segments {
    [] -> marks
    [first, ..rest] -> {
      let marks =
        marks <> stalled_arc_turn_segment_sample_marks(first, [0.25, 0.5, 0.75])
      stalled_arc_turn_sample_marks_loop(rest, marks:)
    }
  }
}

fn stalled_arc_turn_segment_sample_marks(
  segment: svg_path.Segment,
  samples: List(Float),
) -> String {
  case samples {
    [] -> ""
    [t, ..rest] -> {
      let mark = case offset_endpoint(segment, t) {
        Ok(point) ->
          "    <circle cx=\""
          <> gallery_float_to_string(point.x)
          <> "\" cy=\""
          <> gallery_float_to_string(point.y)
          <> "\" r=\"0.00007\" fill=\"#16a34a\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
        Error(_) -> ""
      }
      mark <> stalled_arc_turn_segment_sample_marks(segment, rest)
    }
  }
}

fn stalled_arc_turn_tangent_marks(segments: List(svg_path.Segment)) -> String {
  case segments {
    [] -> ""
    [first, ..rest] -> {
      let assert Ok(last) = list.last([first, ..rest])
      stalled_arc_turn_tangent_mark(first, t: 0.0, color: "#eab308")
      <> stalled_arc_turn_tangent_mark(last, t: 1.0, color: "#eab308")
    }
  }
}

fn stalled_arc_turn_tangent_mark(
  segment: svg_path.Segment,
  t t: Float,
  color color: String,
) -> String {
  case offset_endpoint(segment, t), segment_unit_tangent(segment, t) {
    Ok(point), Ok(tangent) -> {
      let end = add(point, scale(tangent, 0.00075))
      "    <line x1=\""
      <> gallery_float_to_string(point.x)
      <> "\" y1=\""
      <> gallery_float_to_string(point.y)
      <> "\" x2=\""
      <> gallery_float_to_string(end.x)
      <> "\" y2=\""
      <> gallery_float_to_string(end.y)
      <> "\" style=\"stroke: "
      <> color
      <> "; stroke-width: 0.000045; stroke-linecap: round\" />\n"
      <> "    <circle cx=\""
      <> gallery_float_to_string(point.x)
      <> "\" cy=\""
      <> gallery_float_to_string(point.y)
      <> "\" r=\"0.000075\" fill=\""
      <> color
      <> "\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
    }
    _, _ -> ""
  }
}

fn segment_unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> {
      let length = point_length(derivative)
      case length <=. 0.0 {
        True -> Error(Nil)
        False ->
          Ok(svg_path.Point(derivative.x /. length, derivative.y /. length))
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn stalled_arc_turn_corner_label(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) -> {
      let segments = stalled_arc_turn_corner_segments(subpath)
      int.to_string(list.length(segments))
      <> " seg; length "
      <> gallery_float_to_string(stalled_arc_turn_segments_length(segments))
    }
  }
}

fn stalled_arc_turn_corner_segment_count(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.length
      |> int.to_string
  }
}

fn stalled_arc_turn_corner_segments(
  subpath: svg_path.Subpath,
) -> List(svg_path.Segment) {
  case svg_path.subpath_segments(subpath) {
    [] | [_] | [_, _] -> []
    [_, ..rest] -> list.take(rest, list.length(rest) - 1)
  }
}

fn stalled_arc_turn_segments_length(segments: List(svg_path.Segment)) -> Float {
  segments
  |> list.fold(0.0, fn(total, segment) {
    case svg_path.segment_length(segment) {
      Ok(length) -> total +. length
      Error(_) -> total
    }
  })
}

fn serialize_segments(segments: List(svg_path.Segment)) -> String {
  case svg_path.subpath_with(segments, policy: svg_path.Wiggle) {
    Ok(subpath) -> serialize.subpath(subpath)
    Error(_) -> ""
  }
}

fn escape(text: String) -> String {
  text
  |> string.replace("&", "\\&amp;")
  |> string.replace("\"", "\\&quot;")
  |> string.replace("<", "\\&lt;")
  |> string.replace(">", "\\&gt;")
}

fn offset_track_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 32.0),
      control1: svg_path.Point(82.0, -108.0),
      control2: svg_path.Point(150.0, 142.0),
      end: svg_path.Point(232.0, 12.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(232.0, 12.0),
      control1: svg_path.Point(300.0, -92.0),
      control2: svg_path.Point(414.0, 118.0),
      end: svg_path.Point(532.0, -16.0),
    ),
  ])
}

fn dash_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 28.0),
      control1: svg_path.Point(48.0, -62.0),
      control2: svg_path.Point(112.0, 88.0),
      end: svg_path.Point(154.0, 16.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(154.0, 16.0),
      control1: svg_path.Point(194.0, -52.0),
      control2: svg_path.Point(218.0, 70.0),
      end: svg_path.Point(188.0, 42.0),
    ),
  ])
}

fn recursive_dash_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 34.0),
      control1: svg_path.Point(88.0, -112.0),
      control2: svg_path.Point(180.0, 146.0),
      end: svg_path.Point(270.0, 10.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(270.0, 10.0),
      control1: svg_path.Point(344.0, -98.0),
      control2: svg_path.Point(418.0, 138.0),
      end: svg_path.Point(520.0, 22.0),
    ),
  ])
}

fn earth_arc_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 28.0),
      control1: svg_path.Point(42.0, -24.0),
      control2: svg_path.Point(118.0, -24.0),
      end: svg_path.Point(164.0, 28.0),
    ),
  ])
}

fn earth_bend_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 42.0),
      control1: svg_path.Point(34.0, 6.0),
      control2: svg_path.Point(82.0, -18.0),
      end: svg_path.Point(126.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(126.0, 0.0),
      control1: svg_path.Point(156.0, 12.0),
      control2: svg_path.Point(160.0, 50.0),
      end: svg_path.Point(188.0, 66.0),
    ),
  ])
}

fn earth_turn_source() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(0.0, 34.0),
      end: svg_path.Point(68.0, -8.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(68.0, -8.0),
      control1: svg_path.Point(110.0, -34.0),
      control2: svg_path.Point(150.0, 34.0),
      end: svg_path.Point(188.0, 10.0),
    ),
  ])
}

fn panel(x: Float, _label: String) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.Point(x +. 8.0, 18.0),
    222.0,
    184.0,
    "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
  )
}

fn wide_panel() -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.Point(8.0, 18.0),
    844.0,
    344.0,
    "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
  )
}

fn path_layer(
  path: svg_path.Path,
  x: Float,
  fill fill: String,
  stroke stroke: String,
  width width: Float,
  arrows arrows: String,
) -> svg.ThingsToDraw {
  let placed = place_path(path, x +. 6.0, 34.0)
  [
    svg.StyledPath(
      placed,
      "fill: "
        <> fill
        <> "; stroke: "
        <> stroke
        <> "; stroke-width: "
        <> gallery_float_to_string(width)
        <> "; stroke-linejoin: round",
    ),
    ..path_arrows(placed, arrows, 0.9)
  ]
}

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

fn path_arrows(
  path: svg_path.Path,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(subpath_arrows(_, color, arrow_scale))
}

fn subpath_arrows(
  subpath: svg_path.Subpath,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case svg_path.subpath_length(subpath) {
    Error(_) -> []
    Ok(total_length) -> {
      let distance = total_length *. 0.34
      case
        svg_path.subpath_point_at_length(subpath, distance:),
        svg_path.subpath_derivative_at_length(subpath, distance:)
      {
        Ok(point), Ok(derivative) -> {
          let length = point_length(derivative)
          case length <=. 0.000001 {
            True -> []
            False -> [
              arrow_glyph(
                point,
                scale(derivative, 1.0 /. length),
                color,
                arrow_scale,
              ),
            ]
          }
        }
        _, _ -> []
      }
    }
  }
}

fn arrow_glyph(
  point: svg_path.Point,
  unit: svg_path.Point,
  color: String,
  arrow_scale: Float,
) -> svg.ThingToDraw {
  let half_width = 5.0 *. arrow_scale
  let arrow_height = half_width *. 1.7320508075688772
  let normal = rotate_counterclockwise(unit)
  let tip = add(point, scale(unit, arrow_height *. 2.0 /. 3.0))
  let base = add(point, scale(unit, 0.0 -. arrow_height /. 3.0))
  let left = add(base, scale(normal, half_width))
  let right = add(base, scale(normal, 0.0 -. half_width))
  svg.StyledPath(
    svg_path.Path([svg_path.subpath_assert_polygon([tip, left, right])]),
    "fill: " <> color <> "; stroke: none",
  )
}

fn place_path(path: svg_path.Path, x: Float, y: Float) -> svg_path.Path {
  let assert Ok(translated) = transform.translate_path(path, x:, y:)
  translated
}

fn place_subpath(
  subpath: svg_path.Subpath,
  x: Float,
  y: Float,
) -> svg_path.Subpath {
  let assert Ok(translated) = transform.translate_subpath(subpath, x:, y:)
  translated
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.Point(point.x *. factor, point.y *. factor)
}

fn point_length(point: svg_path.Point) -> Float {
  point.x *. point.x +. point.y *. point.y |> float_square_root
}

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy |> float_square_root
}

fn float_square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

fn rotate_counterclockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(point.y, 0.0 -. point.x)
}

fn gallery_float_to_string(value: Float) -> String {
  number_format.number(
    value,
    with: number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(6),
      ),
      [],
    ),
  )
}

fn result_try(
  result: Result(a, e),
  next: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)
