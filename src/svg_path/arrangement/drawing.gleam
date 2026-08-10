//// SVG drawing helpers for arrangement graphs and their source paths.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import svg_path
import svg_path/arrangement.{
  type ArrangementEdge, type ArrangementGraph, type Error, ArrangementEdge,
  ArrangementGraph, ArrangementVertex, PathError,
}
import svg_path/point
import svg_path/svg
import svg_path/trig
import svg_path/winding_field

/// Placement of an edge annotation derived from the stored segment itself.
/// `rotation` is an SVG rotation angle for which the annotation's local up
/// direction follows the segment tangent.
pub type EdgeAnnotationPose {
  EdgeAnnotationPose(point: svg_path.Point, rotation: Float)
}

/// Proportional sizing for an annotated arrangement-graph drawing.
pub type AnnotatedDrawingOptions {
  AnnotatedDrawingOptions(scale: Float)
}

/// Default sizing for an annotated arrangement-graph drawing.
pub fn default_annotated_drawing_options() -> AnnotatedDrawingOptions {
  AnnotatedDrawingOptions(scale: 1.0)
}

/// Draw edges, clustered vertices, vertex ids, and directional multiplicities.
pub fn drawing(graph: ArrangementGraph) -> svg.ThingsToDraw {
  let ArrangementGraph(vertices:, edges:) = graph
  let edge_things =
    edges
    |> list.flat_map(fn(edge) {
      let ArrangementEdge(
        segment:,
        forward_multiplicity:,
        reverse_multiplicity:,
        ..,
      ) = edge
      let midpoint =
        svg_path.segment_point(segment, at: 0.5)
        |> result.unwrap(svg_path.segment_start(segment))
      let label =
        int.to_string(forward_multiplicity)
        <> "/"
        <> int.to_string(reverse_multiplicity)
      [
        svg.StyledPath(
          svg_path.Path([svg_path.subpath_assert([segment])]),
          "fill: none; stroke: #334155; stroke-width: 1.5",
        ),
        svg.Rectangle(
          svg_path.Point(midpoint.x -. 11.0, midpoint.y -. 7.0),
          22.0,
          14.0,
          "fill: white; stroke: #94a3b8; stroke-width: 0.75",
        ),
        svg.Text(
          label,
          "fill: #0f172a; font-family: monospace; text-anchor: middle; dominant-baseline: central",
          svg_path.Point(midpoint.x, midpoint.y +. 0.5),
          8,
        ),
      ]
    })
  let vertex_things =
    vertices
    |> list.flat_map(fn(vertex) {
      let ArrangementVertex(id:, point:, ..) = vertex
      svg.labeled_point("v" <> int.to_string(id), "#dc2626", point, 8)
    })
  list.append(edge_things, vertex_things)
}

/// Draw an arrangement graph using the shared Boolean-debug style.
///
/// Each tangent-oriented cartouche shows global winding immediately to the
/// left/right of the edge in black, with forward/reverse multiplicity below in
/// red. Red arrowheads show the stored forward direction. Vertices use the
/// established white-circle/red-outline style. Cartouches are sized per edge
/// and never exceed 80% of the chord remaining between its endpoint nodes.
pub fn annotated_drawing(
  graph: ArrangementGraph,
  source: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(svg.ThingsToDraw, Error) {
  annotated_drawing_with(
    graph,
    source,
    tolerance:,
    options: default_annotated_drawing_options(),
  )
}

/// Draw an arrangement graph with proportional control over its visual scale.
pub fn annotated_drawing_with(
  graph: ArrangementGraph,
  source: svg_path.Path,
  tolerance tolerance: Float,
  options options: AnnotatedDrawingOptions,
) -> Result(svg.ThingsToDraw, Error) {
  let AnnotatedDrawingOptions(scale:) = options
  let node_radius = 5.0 *. scale
  let ArrangementGraph(vertices:, edges:) = graph
  use edge_things <- result.try(
    annotated_edge_things(edges, source, tolerance, scale, node_radius, []),
  )
  let vertex_things =
    vertices
    |> list.map(fn(vertex) {
      let ArrangementVertex(point:, ..) = vertex
      svg.Circle(
        point,
        node_radius,
        "fill: #fff; stroke: #dc2626; stroke-width: "
          <> float.to_string(2.25 *. scale),
      )
    })
  Ok(list.append(edge_things, vertex_things))
}

fn annotated_edge_things(
  edges: List(ArrangementEdge),
  source: svg_path.Path,
  tolerance: Float,
  drawing_scale: Float,
  node_radius: Float,
  accumulated: List(svg.ThingsToDraw),
) -> Result(svg.ThingsToDraw, Error) {
  case edges {
    [] -> Ok(list.reverse(accumulated) |> list.flatten)
    [edge, ..rest] -> {
      let ArrangementEdge(
        segment:,
        forward_multiplicity:,
        reverse_multiplicity:,
        ..,
      ) = edge
      use levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: source,
          side_sampling_distance: tolerance *. 16.0,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      use pose <- result.try(
        edge_annotation_pose(edge) |> result.map_error(PathError),
      )
      let #(left_winding, right_winding) = levels
      let EdgeAnnotationPose(point: midpoint, rotation:) = pose
      // SVG's display Y axis is the reflection of the Cartesian Y axis used
      // by the side-level calculation. Swap the textual order so the first
      // number appears on the physical left of the directed edge.
      let winding_label =
        int.to_string(right_winding) <> "/" <> int.to_string(left_winding)
      let multiplicity_label =
        "↑"
        <> int.to_string(forward_multiplicity)
        <> "/"
        <> int.to_string(reverse_multiplicity)
        <> "↓"
      let arrow =
        segment_direction_arrow_with(
          segment,
          "#dc2626",
          length_scale: 2.0 *. node_radius /. 9.0,
          width_scale: 1.6 *. node_radius /. 3.5,
          arrival_offset: node_radius,
          opacity: 1.0,
        )
        |> result.unwrap(svg.StyledPath(svg_path.path_empty(), ""))
      let chord =
        point.distance(
          svg_path.segment_start(segment),
          svg_path.segment_end(segment),
        )
      let usable_chord = chord -. 2.0 *. node_radius
      let label_scale = case usable_chord <=. 0.0 {
        True -> 0.0
        False -> float_min(1.2 *. drawing_scale, usable_chord *. 0.8 /. 24.0)
      }
      let label_things = case label_scale <=. 0.0 {
        True -> []
        False -> {
          let width = 34.0 *. label_scale
          let height = 24.0 *. label_scale
          [
            svg.RotatedRectangle(
              svg_path.Point(
                midpoint.x -. width /. 2.0,
                midpoint.y -. height /. 2.0,
              ),
              width,
              height,
              "fill: #fff; stroke: #94a3b8; stroke-width: "
                <> float.to_string(0.75 *. drawing_scale),
              rotation:,
              origin: midpoint,
            ),
            svg.RotatedText(
              winding_label,
              "fill: #0f172a; font-family: ui-monospace, monospace; font-weight: 700; text-anchor: middle",
              svg_path.Point(midpoint.x, midpoint.y -. 2.0 *. label_scale),
              scaled_font_size(9.0, label_scale),
              rotation:,
              origin: midpoint,
            ),
            svg.RotatedText(
              multiplicity_label,
              "fill: #dc2626; font-family: ui-monospace, monospace; font-weight: 700; text-anchor: middle",
              svg_path.Point(midpoint.x, midpoint.y +. 9.0 *. label_scale),
              scaled_font_size(8.0, label_scale),
              rotation:,
              origin: midpoint,
            ),
          ]
        }
      }
      let things =
        list.append(
          [
            svg.StyledPath(
              svg_path.Path([svg_path.subpath_assert([segment])]),
              "fill: none; stroke: #334155; stroke-width: "
                <> float.to_string(3.25 *. drawing_scale),
            ),
            arrow,
          ],
          label_things,
        )
      annotated_edge_things(
        rest,
        source,
        tolerance,
        drawing_scale,
        node_radius,
        [things, ..accumulated],
      )
    }
  }
}

fn scaled_font_size(base: Float, scale: Float) -> Int {
  let size = float.round(base *. scale)
  case size < 1 {
    True -> 1
    False -> size
  }
}

/// Draw one arrowhead whose tip is the head of a segment.
pub fn segment_direction_arrow(
  segment: svg_path.Segment,
  color: String,
) -> Result(svg.ThingToDraw, Nil) {
  segment_direction_arrow_with(
    segment,
    color,
    length_scale: 1.0,
    width_scale: 1.0,
    arrival_offset: 0.0,
    opacity: 1.0,
  )
}

/// Draw one arrowhead whose tip is the head of a segment.
///
/// Length and width are scaled independently from the default dimensions.
pub fn segment_direction_arrow_with(
  segment: svg_path.Segment,
  color: String,
  length_scale length_scale: Float,
  width_scale width_scale: Float,
  arrival_offset arrival_offset: Float,
  opacity opacity: Float,
) -> Result(svg.ThingToDraw, Nil) {
  use endpoint <- result.try(
    svg_path.segment_point(segment, at: 1.0) |> result.replace_error(Nil),
  )
  use directions <- result.try(
    svg_path.segment_directions(segment, at: 1.0)
    |> result.replace_error(Nil),
  )
  case directions.incoming {
    None -> Error(Nil)
    Some(direction) -> {
      let ux = direction.x
      let uy = direction.y
      let px = 0.0 -. uy
      let py = ux
      let point =
        svg_path.Point(
          endpoint.x -. ux *. arrival_offset,
          endpoint.y -. uy *. arrival_offset,
        )
      let left =
        svg_path.Point(
          point.x -. ux *. 9.0 *. length_scale +. px *. 3.5 *. width_scale,
          point.y -. uy *. 9.0 *. length_scale +. py *. 3.5 *. width_scale,
        )
      let right =
        svg_path.Point(
          point.x -. ux *. 9.0 *. length_scale -. px *. 3.5 *. width_scale,
          point.y -. uy *. 9.0 *. length_scale -. py *. 3.5 *. width_scale,
        )
      Ok(svg.StyledPath(
        svg_path.Path([svg_path.subpath_assert_polygon([point, left, right])]),
        "fill: "
          <> color
          <> "; fill-opacity: "
          <> float.to_string(opacity)
          <> "; stroke: none",
      ))
    }
  }
}

/// Draw endpoint arrowheads for every segment of a subpath.
pub fn subpath_direction_arrows(
  subpath: svg_path.Subpath,
  color: String,
) -> svg.ThingsToDraw {
  subpath_direction_arrows_with(
    subpath,
    color,
    length_scale: 1.0,
    width_scale: 1.0,
    arrival_offset: 0.0,
    opacity: 1.0,
  )
}

/// Draw independently scaled endpoint arrowheads for every segment of a
/// subpath.
pub fn subpath_direction_arrows_with(
  subpath: svg_path.Subpath,
  color: String,
  length_scale length_scale: Float,
  width_scale width_scale: Float,
  arrival_offset arrival_offset: Float,
  opacity opacity: Float,
) -> svg.ThingsToDraw {
  subpath
  |> svg_path.subpath_segments
  |> list.filter_map(fn(segment) {
    segment_direction_arrow_with(
      segment,
      color,
      length_scale:,
      width_scale:,
      arrival_offset:,
      opacity:,
    )
  })
}

/// Draw endpoint arrowheads for every segment of a path.
pub fn path_direction_arrows(
  path: svg_path.Path,
  color: String,
) -> svg.ThingsToDraw {
  path_direction_arrows_with(
    path,
    color,
    length_scale: 1.0,
    width_scale: 1.0,
    arrival_offset: 0.0,
    opacity: 1.0,
  )
}

/// Draw independently scaled endpoint arrowheads for every segment of a path.
pub fn path_direction_arrows_with(
  path: svg_path.Path,
  color: String,
  length_scale length_scale: Float,
  width_scale width_scale: Float,
  arrival_offset arrival_offset: Float,
  opacity opacity: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(fn(subpath) {
    subpath_direction_arrows_with(
      subpath,
      color,
      length_scale:,
      width_scale:,
      arrival_offset:,
      opacity:,
    )
  })
}

/// Return the midpoint and traversal-aligned orientation for an edge annotation.
///
/// At a stationary midpoint with distinct directions on either side, the
/// incoming direction determines the orientation. The outgoing direction is
/// used when no incoming direction exists. Directionless geometry returns
/// `svg_path.IndeterminateDirection`.
pub fn edge_annotation_pose(
  edge: ArrangementEdge,
) -> Result(EdgeAnnotationPose, svg_path.Error) {
  let ArrangementEdge(segment:, ..) = edge
  use midpoint <- result.try(svg_path.segment_point(segment, at: 0.5))
  use directions <- result.try(svg_path.segment_directions(segment, at: 0.5))
  let direction = case directions.incoming, directions.outgoing {
    Some(direction), _ | None, Some(direction) -> Ok(direction)
    None, None -> Error(svg_path.IndeterminateDirection)
  }
  use direction <- result.try(direction)
  let angle = trig.atan2_degrees(direction.y, direction.x)
  Ok(EdgeAnnotationPose(point: midpoint, rotation: angle +. 90.0))
}

fn float_min(a: Float, b: Float) -> Float {
  case a <. b {
    True -> a
    False -> b
  }
}
