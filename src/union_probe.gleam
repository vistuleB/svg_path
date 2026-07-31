//// Scratch probe: offset + union on the first two subpaths (S and V), with the
//// outer contour identified in Gleam (largest absolute signed area) and drawn
//// orange, the interior contours drawn blue. Not part of the library.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import svg_path
import svg_path/area
import svg_path/intersections
import svg_path/offset
import svg_path/parse
import svg_path/point as point_helpers
import svg_path/robust_union
import svg_path/svg
import svg_path/trig

const input = "examples/debug/package_title.svg"

pub fn main() -> Dynamic {
  let assert Ok(contents) = read_file(input)
  let assert Ok(full) = parse.path(first_path_data(contents))

  let first_three = svg_path.path_subpaths(full) |> list.take(3)
  let source = svg_path.Path(first_three)

  let assert Ok(offset_path) =
    offset.path_with(source, distance: 1.0, options: offset.default_options())

  io.println("source segments: " <> seg_report(source))
  io.println("offset segments: " <> seg_report(offset_path))

  // Sweep offset options to see which knob controls the degenerate spurs.
  let base = offset.default_options()
  let variants =
    [0.01, 0.1, 0.5, 1.0, 2.0, 5.0]
    |> list.map(fn(angle) {
      #(
        "heal=" <> float.to_string(angle) <> "deg",
        offset.Options(..base, tangent_heal_angle_degrees: angle),
      )
    })
  list.each(variants, fn(v) {
    let #(label, opts) = v
    case offset.path_with(source, distance: 1.0, options: opts) {
      Ok(p) -> io.println("  offset[" <> label <> "]: " <> seg_report(p))
      Error(e) ->
        io.println("  offset[" <> label <> "]: ERROR " <> string.inspect(e))
    }
  })

  // Re-node the offset at different tolerances to test the too-tight-tolerance
  // hypothesis for the micro-segment explosion.
  let offset_segs =
    svg_path.path_subpaths(offset_path)
    |> list.flat_map(svg_path.subpath_segments)
  list.each([0.000000001, 0.0001, 0.001, 0.01], fn(tol) {
    let opts = intersections.IntersectionOptions(tolerance: tol, max_depth: 20)
    case robust_union.node_segments_with(offset_segs, options: opts) {
      Ok(noded) ->
        io.println(
          "  noded @tol="
          <> float.to_string(tol)
          <> ": "
          <> seg_list_report(noded),
        )
      Error(e) ->
        io.println(
          "  noded @tol="
          <> float.to_string(tol)
          <> ": ERROR "
          <> string.inspect(e),
        )
    }
  })

  case robust_union.union_nonzero(offset_path) {
    Error(error) -> io.println("UNION ERROR: " <> string.inspect(error))
    Ok(union_path) -> {
      let subpaths = svg_path.path_subpaths(union_path)

      // Identify the outer contour as the one with the largest absolute signed
      // area, straight from the geometry (no string parsing).
      let assert Ok(outer) =
        list.reduce(subpaths, fn(best, sp) {
          case
            float.absolute_value(area.signed_subpath(sp))
            >. float.absolute_value(area.signed_subpath(best))
          {
            True -> sp
            False -> best
          }
        })
      let interior = list.filter(subpaths, keeping: fn(sp) { sp != outer })
      let assert Ok(orange_internal) =
        internal_segments(outer, within: offset_path, probe: 0.01)
      let assert Ok(internal_box) = segments_bounding_box(orange_internal)
      let assert #(prefix, bad, index) =
        first_bad_step(svg_path.subpath_segments(outer), orange_internal, 0, [])
      let assert Ok(noded_for_trace) = robust_union.node_segments(offset_segs)
      let assert Ok(incoming) = list.last(prefix)
      let candidates =
        incident_candidates(
          noded_for_trace,
          svg_path.segment_end(incoming),
          0.02,
          [],
        )

      io.println("union segments:  " <> seg_report(union_path))
      io.println("union contours: " <> string.inspect(list.length(subpaths)))
      io.println("outer area = " <> float.to_string(area.signed_subpath(outer)))
      io.println(
        "orange internal segments: "
        <> string.inspect(list.length(orange_internal)),
      )
      io.println("freezing before orange segment " <> string.inspect(index))
      io.println("  bad start: " <> point_report(svg_path.segment_start(bad)))
      io.println("  bad end:   " <> point_report(svg_path.segment_end(bad)))
      print_segment_measurement("red incoming", incoming)
      io.println(
        "visible candidate count: " <> string.inspect(list.length(candidates)),
      )
      print_candidate_colors(candidates, incoming, 0)
      print_candidate_headings(candidates, svg_path.segment_end(incoming), 0)
      print_turns(incoming, noded_for_trace)
      list.each(interior, fn(sp) {
        io.println(
          "  interior area = " <> float.to_string(area.signed_subpath(sp)),
        )
      })

      let assert Ok(box) =
        svg_path.path_bounding_box(svg_path.path_combine([source, offset_path]))
      let view = pad(box, 1.0)

      // One orientation arrow per subpath, colored to match its contour.
      let arrows =
        list.append(
          list.filter_map([outer], orientation_arrow(_, "#ea580c")),
          list.filter_map(interior, orientation_arrow(_, "#2563eb")),
        )
      let candidate_drawings = case orange_internal {
        [] -> []
        _ ->
          candidates
          |> list.index_map(fn(segment, index) {
            svg.StyledPath(
              svg_path.path_from_subpath(svg_path.subpath_assert([segment])),
              "fill: none; stroke: "
                <> candidate_color(index)
                <> "; stroke-width: 0.38; stroke-linejoin: round",
            )
          })
      }
      let freeze_drawings = case orange_internal {
        [] -> []
        _ -> [
          svg.StyledPath(
            svg_path.path_from_subpath(svg_path.subpath_assert(prefix)),
            "fill: none; stroke: #16a34a; stroke-width: 0.32; stroke-linejoin: round",
          ),
          svg.StyledPath(
            svg_path.path_from_subpath(svg_path.subpath_assert([bad])),
            "fill: none; stroke: #374151; stroke-width: 0.46; stroke-linejoin: round",
          ),
          svg.Rectangle(
            internal_box.min,
            svg_path.bounding_box_width(internal_box),
            svg_path.bounding_box_height(internal_box),
            "fill: none; stroke: #d946ef; stroke-width: 0.06; stroke-dasharray: 0.25 0.15",
          ),
        ]
      }

      let doc =
        svg.document(
          things: list.flatten([
            [
              svg.Rectangle(
                view.min,
                svg_path.bounding_box_width(view),
                svg_path.bounding_box_height(view),
                "fill: #f5f5f4; stroke: none",
              ),
              svg.StyledPath(
                source,
                "fill: none; stroke: #9ca3af; stroke-width: 0.06; stroke-dasharray: 0.3 0.2",
              ),
              // Orange outer first, blue interior last so blue draws on top.
              svg.StyledPath(
                svg_path.Path([outer]),
                "fill: none; stroke: #ea580c; stroke-width: 0.17; stroke-linejoin: round",
              ),
              svg.StyledPath(
                svg_path.Path(interior),
                "fill: none; stroke: #2563eb; stroke-width: 0.13; stroke-linejoin: round",
              ),
              svg.StyledPath(
                svg_path.Path(
                  list.map(orange_internal, fn(segment) {
                    svg_path.subpath_assert([segment])
                  }),
                ),
                "fill: none; stroke: #d946ef; stroke-width: 0.25; stroke-linejoin: round",
              ),
            ],
            freeze_drawings,
            candidate_drawings,
            // Arrows on top.
            arrows,
          ]),
          view_box: view,
        )
      let _ =
        write_file(
          "examples/debug/probe_sv_outer.svg",
          with_root_size(doc, width: 16_000, height: 3600),
        )
      let trimmed_doc =
        svg.document(
          things: [
            svg.Rectangle(
              view.min,
              svg_path.bounding_box_width(view),
              svg_path.bounding_box_height(view),
              "fill: #f5f5f4; stroke: none",
            ),
            svg.StyledPath(
              source,
              "fill: none; stroke: #9ca3af; stroke-width: 0.06; stroke-dasharray: 0.3 0.2",
            ),
            svg.StyledPath(
              svg_path.Path([outer]),
              "fill: none; stroke: #ea580c; stroke-width: 0.17; stroke-linejoin: round",
            ),
          ],
          view_box: view,
        )
      let _ =
        write_file(
          "examples/debug/probe_sv_outer_trimmed.svg",
          with_root_size(trimmed_doc, width: 16_000, height: 3600),
        )
      io.println("wrote examples/debug/probe_sv_outer.svg")
      io.println("wrote examples/debug/probe_sv_outer_trimmed.svg")
    }
  }

  dyn_nil()
}

fn with_root_size(
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

// Build a small filled triangle pointing along the subpath's traversal
// direction at the midpoint of its first segment. Returns Error for degenerate
// subpaths whose tangent is too small to orient (they get no arrow).
fn orientation_arrow(
  sp: svg_path.Subpath,
  color: String,
) -> Result(svg.ThingToDraw, Nil) {
  let at = svg_path.SubpathParameter(segment_index: 0, t: 0.5)
  use point <- result.try(
    svg_path.subpath_point(sp, at:) |> result.replace_error(Nil),
  )
  use deriv <- result.try(
    svg_path.subpath_derivative(sp, at:) |> result.replace_error(Nil),
  )
  let magnitude =
    float.square_root(deriv.x *. deriv.x +. deriv.y *. deriv.y)
    |> result.unwrap(0.0)
  case magnitude >. 0.0001 {
    False -> Error(Nil)
    True -> {
      let ux = deriv.x /. magnitude
      let uy = deriv.y /. magnitude
      // Perpendicular (left of travel).
      let px = 0.0 -. uy
      let py = ux
      let half = 0.34
      let wide = 0.28
      let tip = svg_path.Point(point.x +. ux *. half, point.y +. uy *. half)
      let back_x = point.x -. ux *. half
      let back_y = point.y -. uy *. half
      let left = svg_path.Point(back_x +. px *. wide, back_y +. py *. wide)
      let right = svg_path.Point(back_x -. px *. wide, back_y -. py *. wide)
      Ok(svg.StyledPath(
        svg_path.Path([svg_path.subpath_assert_polygon([tip, left, right])]),
        "fill: " <> color <> "; stroke: none",
      ))
    }
  }
}

fn lengths_line(sp: svg_path.Subpath) -> String {
  svg_path.subpath_segments(sp)
  |> list.map(fn(s) {
    case svg_path.segment_length(s) {
      Ok(l) -> round4(l)
      Error(_) -> "?"
    }
  })
  |> string.join(" ")
}

fn round4(x: Float) -> String {
  let scaled = float.round(x *. 10_000.0)
  float.to_string(int_to_float(scaled) /. 10_000.0)
}

@external(erlang, "erlang", "float")
fn int_to_float(x: Int) -> Float

fn seg_report(path: svg_path.Path) -> String {
  svg_path.path_subpaths(path)
  |> list.flat_map(svg_path.subpath_segments)
  |> seg_list_report
}

fn internal_segments(
  contour: svg_path.Subpath,
  within filled: svg_path.Path,
  probe probe_distance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  internal_segments_loop(
    svg_path.subpath_segments(contour),
    filled,
    probe_distance,
    [],
  )
}

fn internal_segments_loop(
  segments: List(svg_path.Segment),
  filled: svg_path.Path,
  probe_distance: Float,
  internal: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case segments {
    [] -> Ok(list.reverse(internal))
    [segment, ..rest] -> {
      use midpoint <- result.try(svg_path.segment_point(segment, at: 0.5))
      use derivative <- result.try(svg_path.segment_derivative(segment, at: 0.5))
      let magnitude =
        float.square_root(
          derivative.x *. derivative.x +. derivative.y *. derivative.y,
        )
        |> result.unwrap(0.0)
      case magnitude <=. 0.000000001 {
        True -> internal_segments_loop(rest, filled, probe_distance, internal)
        False -> {
          let nx = { 0.0 -. derivative.y } /. magnitude *. probe_distance
          let ny = derivative.x /. magnitude *. probe_distance
          use left_state <- result.try(svg_path.path_containment(
            svg_path.Point(midpoint.x +. nx, midpoint.y +. ny),
            within: filled,
            using: svg_path.Nonzero,
          ))
          use right_state <- result.try(svg_path.path_containment(
            svg_path.Point(midpoint.x -. nx, midpoint.y -. ny),
            within: filled,
            using: svg_path.Nonzero,
          ))
          let internal = case left_state, right_state {
            svg_path.Inside, svg_path.Inside -> [segment, ..internal]
            _, _ -> internal
          }
          internal_segments_loop(rest, filled, probe_distance, internal)
        }
      }
    }
  }
}

fn segments_bounding_box(
  segments: List(svg_path.Segment),
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  case segments {
    [] ->
      Ok(svg_path.BoundingBox(
        min: svg_path.Point(0.0, 0.0),
        max: svg_path.Point(0.0, 0.0),
      ))
    [first, ..rest] -> {
      use first_box <- result.try(svg_path.segment_bounding_box(first))
      segments_bounding_box_loop(rest, first_box)
    }
  }
}

fn first_bad_step(
  segments: List(svg_path.Segment),
  bad_segments: List(svg_path.Segment),
  index: Int,
  reversed_prefix: List(svg_path.Segment),
) -> #(List(svg_path.Segment), svg_path.Segment, Int) {
  case bad_segments {
    [] -> {
      let assert [first, ..] = segments
      #([first], first, -1)
    }
    _ -> first_bad_step_nonempty(segments, bad_segments, index, reversed_prefix)
  }
}

fn first_bad_step_nonempty(
  segments: List(svg_path.Segment),
  bad_segments: List(svg_path.Segment),
  index: Int,
  reversed_prefix: List(svg_path.Segment),
) -> #(List(svg_path.Segment), svg_path.Segment, Int) {
  case segments {
    [] -> panic as "orange traversal has no marked internal segment"
    [segment, ..rest] ->
      case
        list.any(bad_segments, fn(candidate) {
          same_segment_ends(segment, candidate)
        })
      {
        True -> #(list.reverse(reversed_prefix), segment, index)
        False ->
          first_bad_step_nonempty(rest, bad_segments, index + 1, [
            segment,
            ..reversed_prefix
          ])
      }
  }
}

fn same_segment_ends(left: svg_path.Segment, right: svg_path.Segment) -> Bool {
  let start_left = svg_path.segment_start(left)
  let start_right = svg_path.segment_start(right)
  let end_left = svg_path.segment_end(left)
  let end_right = svg_path.segment_end(right)
  start_left.x == start_right.x
  && start_left.y == start_right.y
  && end_left.x == end_right.x
  && end_left.y == end_right.y
}

fn point_report(point: svg_path.Point) -> String {
  "(" <> float.to_string(point.x) <> ", " <> float.to_string(point.y) <> ")"
}

fn print_segment_measurement(label: String, segment: svg_path.Segment) -> Nil {
  let start = svg_path.segment_start(segment)
  let end = svg_path.segment_end(segment)
  let vector = point_helpers.subtract(end, start)
  let length = svg_path.segment_length(segment) |> result.unwrap(0.0)
  io.println(
    "  "
    <> label
    <> " length="
    <> float.to_string(length)
    <> " heading="
    <> float.to_string(point_helpers.heading(vector)),
  )
}

fn print_turns(
  incoming: svg_path.Segment,
  pieces: List(svg_path.Segment),
) -> Nil {
  let junction = svg_path.segment_end(incoming)
  case svg_path.segment_derivative(incoming, at: 1.0) {
    Error(error) ->
      io.println("turn trace derivative error: " <> string.inspect(error))
    Ok(derivative) -> {
      let reversed_incoming =
        svg_path.Point(0.0 -. derivative.x, 0.0 -. derivative.y)
      io.println("turn trace at " <> point_report(junction))
      print_turn_candidates(pieces, junction, reversed_incoming, 0)
    }
  }
}

fn print_turn_candidates(
  pieces: List(svg_path.Segment),
  junction: svg_path.Point,
  reversed_incoming: svg_path.Point,
  index: Int,
) -> Nil {
  case pieces {
    [] -> Nil
    [piece, ..rest] -> {
      let oriented = case exact_point(svg_path.segment_start(piece), junction) {
        True -> Ok(piece)
        False ->
          case exact_point(svg_path.segment_end(piece), junction) {
            True -> Ok(svg_path.segment_reverse(piece))
            False -> Error(Nil)
          }
      }
      case oriented {
        Error(_) -> Nil
        Ok(candidate) ->
          case svg_path.segment_derivative(candidate, at: 0.0) {
            Error(_) -> Nil
            Ok(outgoing) -> {
              let turn =
                trig.atan2_degrees(
                  reversed_incoming.x
                    *. outgoing.y
                    -. reversed_incoming.y
                    *. outgoing.x,
                  reversed_incoming.x
                    *. outgoing.x
                    +. reversed_incoming.y
                    *. outgoing.y,
                )
              io.println(
                "  candidate "
                <> string.inspect(index)
                <> " turn="
                <> float.to_string(turn)
                <> " end="
                <> point_report(svg_path.segment_end(candidate)),
              )
            }
          }
      }
      print_turn_candidates(rest, junction, reversed_incoming, index + 1)
    }
  }
}

fn exact_point(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy <=. 1.0e-18
}

fn incident_candidates(
  pieces: List(svg_path.Segment),
  junction: svg_path.Point,
  tolerance: Float,
  candidates: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case pieces {
    [] -> list.reverse(candidates)
    [piece, ..rest] -> {
      let candidate = case
        within_distance(svg_path.segment_start(piece), junction, tolerance)
      {
        True -> Ok(piece)
        False ->
          case
            within_distance(svg_path.segment_end(piece), junction, tolerance)
          {
            True -> Ok(svg_path.segment_reverse(piece))
            False -> Error(Nil)
          }
      }
      let candidates = case candidate {
        Ok(segment) -> [segment, ..candidates]
        Error(_) -> candidates
      }
      incident_candidates(rest, junction, tolerance, candidates)
    }
  }
}

fn within_distance(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance: Float,
) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy <=. tolerance *. tolerance
}

fn candidate_color(index: Int) -> String {
  let assert Ok(remainder) = int.remainder(index, by: 5)
  case remainder {
    0 -> "#ef4444"
    1 -> "#8b5cf6"
    2 -> "#06b6d4"
    3 -> "#84cc16"
    _ -> "#f59e0b"
  }
}

fn print_candidate_colors(
  candidates: List(svg_path.Segment),
  incoming: svg_path.Segment,
  index: Int,
) -> Nil {
  case candidates {
    [] -> Nil
    [candidate, ..rest] -> {
      let is_incoming =
        same_segment_ends(candidate, incoming)
        || same_segment_ends(svg_path.segment_reverse(candidate), incoming)
      io.println(
        "  "
        <> candidate_color(index)
        <> case is_incoming {
          True -> " = incoming"
          False -> " = incident"
        },
      )
      print_candidate_colors(rest, incoming, index + 1)
    }
  }
}

fn print_candidate_headings(
  candidates: List(svg_path.Segment),
  junction: svg_path.Point,
  index: Int,
) -> Nil {
  case candidates {
    [] -> Nil
    [candidate, ..rest] -> {
      let vector =
        point_helpers.subtract(
          svg_path.segment_end(candidate),
          svg_path.segment_start(candidate),
        )
      let distance =
        point_helpers.distance(svg_path.segment_start(candidate), junction)
      io.println(
        "  "
        <> candidate_color(index)
        <> " heading="
        <> float.to_string(point_helpers.heading(vector))
        <> " endpoint distance="
        <> float.to_string(distance),
      )
      print_candidate_headings(rest, junction, index + 1)
    }
  }
}

fn segments_bounding_box_loop(
  segments: List(svg_path.Segment),
  combined: svg_path.BoundingBox,
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  case segments {
    [] -> Ok(combined)
    [segment, ..rest] -> {
      use box <- result.try(svg_path.segment_bounding_box(segment))
      let svg_path.BoundingBox(min: a, max: b) = combined
      let svg_path.BoundingBox(min: c, max: d) = box
      let combined =
        svg_path.BoundingBox(
          min: svg_path.Point(float.min(a.x, c.x), float.min(a.y, c.y)),
          max: svg_path.Point(float.max(b.x, d.x), float.max(b.y, d.y)),
        )
      segments_bounding_box_loop(rest, combined)
    }
  }
}

fn seg_list_report(segs: List(svg_path.Segment)) -> String {
  let total = list.length(segs)
  let degenerate =
    list.count(segs, fn(s) {
      case svg_path.segment_is_zero_length(s, tolerance: 0.005) {
        Ok(True) -> True
        _ -> False
      }
    })
  string.inspect(total)
  <> " total, "
  <> string.inspect(degenerate)
  <> " near-zero-length (<=0.005)"
}

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

fn pad(box: svg_path.BoundingBox, margin: Float) -> svg_path.BoundingBox {
  let svg_path.BoundingBox(min:, max:) = box
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

@external(erlang, "erlang", "self")
fn dyn_nil() -> Dynamic

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
