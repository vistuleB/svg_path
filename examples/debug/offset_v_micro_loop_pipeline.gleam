import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/arrangement
import svg_path/offset
import svg_path/parse

const input = "examples/debug/package_title.svg"

const distance = 1.05

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert [_, v, ..] = svg_path.path_subpaths(title)
  let source = svg_path.Path([v])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(untrimmed) = offset.path_untrimmed_with(source, distance, options)
  let assert Ok(trace) = offset.internal_single_offset_loop_trace(
    v,
    distance:,
    options:,
  )
  let offset.SingleOffsetLoopTrace(graph:, loops:, blocks:, ..) = trace
  let assert Ok(areas) = offset.internal_synchronized_offset_area_trace(
    v,
    inner_distance: 0.0,
    outer_distance: distance,
    options:,
  )
  let assert Ok(joins) = offset.internal_synchronized_join_trace(
    v,
    inner_distance: 0.0,
    outer_distance: distance,
    options:,
  )
  let assert Ok(filtered) =
    offset.internal_filter_directly_contained_arrangement_loops(
      trace,
      inner_offset: 0.0,
      outer_offset: distance,
    )
  io.println(
    "untrimmed_subpaths="
    <> int.to_string(list.length(svg_path.path_subpaths(untrimmed))),
  )
  io.println(
    "trimmed_subpaths="
    <> int.to_string(list.length(loops)),
  )
  io.println(
    "source_correspondence_areas="
    <> int.to_string(list.length(areas))
    <> " join_correspondences="
    <> int.to_string(list.length(joins)),
  )
  io.println("arrangement_blocks=" <> int.to_string(list.length(blocks)))
  io.println(
    "directly_filtered_subpaths=" <> int.to_string(list.length(filtered)),
  )
  report_loops(loops, blocks, graph, 0)
}

fn report_loops(
  loops: List(offset.ArrangementLoop),
  blocks: List(offset.BandBlock),
  graph: arrangement.ArrangementGraph,
  index: Int,
) -> Nil {
  case loops {
    [] -> Nil
    [offset.ArrangementLoop(subpath:, edges:), ..rest] -> {
      let assert Ok(bounds) = svg_path.subpath_bounding_box(subpath)
      let #(containing_blocks, block_errors) = direct_containing_block_counts(
        graph,
        offset.ArrangementLoop(subpath:, edges:),
        blocks,
        containing: 0,
        errors: 0,
      )
      io.println(
        "subpath="
        <> int.to_string(index)
        <> " closed="
        <> string.inspect(svg_path.subpath_is_closed(subpath))
        <> " segments="
        <> int.to_string(list.length(svg_path.subpath_segments(subpath)))
        <> " arrangement_edges="
        <> int.to_string(list.length(edges))
        <> " edge_ids="
        <> string.join(
          list.map(edges, fn(edge) { int.to_string(edge.edge_id) }),
          with: ",",
        )
        <> " bounds="
        <> string.inspect(#(
          svg_path.bounding_box_width(bounds),
          svg_path.bounding_box_height(bounds),
        ))
        <> " band_sized="
        <> result_bool(offset.internal_arrangement_loop_is_band_sized(
          offset.ArrangementLoop(subpath: subpath, edges: []),
          0.0,
          distance,
        ))
        <> " ghosts_share_face="
        <> result_bool(offset.internal_arrangement_loop_ghosts_share_face(
          graph,
          offset.ArrangementLoop(subpath:, edges:),
        ))
        <> " direct_blocks="
        <> int.to_string(containing_blocks)
        <> " block_errors="
        <> int.to_string(block_errors),
      )
      report_loops(rest, blocks, graph, index + 1)
    }
  }
}

fn direct_containing_block_counts(
  graph: arrangement.ArrangementGraph,
  loop: offset.ArrangementLoop,
  blocks: List(offset.BandBlock),
  containing containing: Int,
  errors errors: Int,
) -> #(Int, Int) {
  case blocks {
    [] -> #(containing, errors)
    [first, ..rest] ->
      case offset.internal_arrangement_loop_directly_contained_by_block(
        graph,
        loop,
        first,
      ) {
        Ok(True) -> direct_containing_block_counts(
          graph,
          loop,
          rest,
          containing: containing + 1,
          errors:,
        )
        Ok(False) -> direct_containing_block_counts(
          graph,
          loop,
          rest,
          containing:,
          errors:,
        )
        Error(error) -> {
          case errors == 0 {
            True -> io.println("first_block_error=" <> string.inspect(error))
            False -> Nil
          }
          direct_containing_block_counts(
            graph,
            loop,
            rest,
            containing:,
            errors: errors + 1,
          )
        }
      }
  }
}

fn result_bool(value: Result(Bool, offset.Error)) -> String {
  case value {
    Ok(value) -> string.inspect(value)
    Error(error) -> string.inspect(error)
  }
}

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)
