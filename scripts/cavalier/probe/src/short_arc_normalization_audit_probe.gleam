import svg_path.{Arc, Line, Point}
import svg_path/degeneracy
import svg_path/offset

pub fn main() {
  let arc =
    Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.00003, 0.0))
  let assert Ok(alone) = svg_path.subpath([arc])
  echo degeneracy.normalize_degenerate_segments(alone, 0.001)
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(-1.0, 0.0), arc.start),
      arc,
      Line(arc.end, Point(0.00003, 1.0)),
    ])
  echo offset.normalize_short_source_runs(source, 0.001)
  echo offset.subpath(source, 0.1, offset.Round, offset.Butt)
}
