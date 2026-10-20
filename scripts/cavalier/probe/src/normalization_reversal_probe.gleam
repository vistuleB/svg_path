import gleam/list
import svg_path
import svg_path/degeneracy
import svg_path/measure
import svg_path/offset

pub fn main() {
  let assert Ok(source) =
    svg_path.subpath_polyline(
      list.map([-2.0, 0.0, 1.0, 0.5, 2.0, 3.0], fn(x) { svg_path.Point(x, 0.0) }),
    )
  let assert Ok(cleaned) =
    degeneracy.normalize_degenerate_segments(source, tolerance: 0.0)
  let assert Ok(normalized) =
    offset.normalize_source_subpath(source, offset.default_options())
  let assert Ok(raw) =
    offset.subpath_untrimmed_with(
      source,
      -1.0,
      offset.Round,
      offset.default_options(),
    )
  echo #("source length", measure.subpath_length(source))
  echo #("zero tolerance cleanup", measure.subpath_length(cleaned))
  echo #("offset normalization", measure.subpath_length(normalized))
  echo #("ordinary raw offset", measure.subpath_length(raw))
  let assert Ok(preserved) =
    offset.untrimmed_subpath_from_normalized_source(
      source,
      -1.0,
      offset.Round,
      offset.default_options(),
    )
  echo #(
    "raw offset with source supplied directly",
    measure.subpath_length(preserved),
  )
}
