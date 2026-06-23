import gleam/list
import gleam/result
import svg_path
import svg_path/convex_hull

pub type CandidateError {
  NotArc
  PathError(svg_path.Error)
}

pub fn hull(
  segment: svg_path.Segment,
) -> Result(#(svg_path.Subpath, List(convex_hull.HullPiece)), CandidateError) {
  case segment {
    svg_path.Arc(..) -> {
      let pieces = [
        convex_hull.HullCurve(0.0, 1.0),
        convex_hull.HullLine(1.0, 0.0),
      ]

      use segments <- result.try(pieces_to_segments(segment, pieces))
      use subpath <- result.try(
        svg_path.subpath_with(segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      use closed <- result.try(
        svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )

      Ok(#(closed, pieces))
    }
    _ -> Error(NotArc)
  }
}

fn pieces_to_segments(
  segment: svg_path.Segment,
  pieces: List(convex_hull.HullPiece),
) -> Result(List(svg_path.Segment), CandidateError) {
  list.fold(pieces, Ok([]), fn(segments, piece) {
    use segments <- result.try(segments)
    use segment <- result.try(piece_to_segment(segment, piece))
    Ok([segment, ..segments])
  })
  |> result.map(list.reverse)
}

fn piece_to_segment(
  segment: svg_path.Segment,
  piece: convex_hull.HullPiece,
) -> Result(svg_path.Segment, CandidateError) {
  case piece {
    convex_hull.HullCurve(from, to) ->
      svg_path.sub_segment(segment, from: from, to: to)
      |> result.map_error(PathError)
    convex_hull.HullLine(from, to) -> {
      use start <- result.try(segment_point(segment, from))
      use end <- result.try(segment_point(segment, to))
      Ok(svg_path.Line(start: start, end: end))
    }
  }
}

fn segment_point(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, CandidateError) {
  svg_path.segment_point(segment, at: t)
  |> result.map_error(PathError)
}
