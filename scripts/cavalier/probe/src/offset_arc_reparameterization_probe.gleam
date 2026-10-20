import gleam/float
import svg_path

pub fn main() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(66.48121035659938, 6559.430109164913),
      radius: svg_path.Point(81.0, 81.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(70.02488902419492, 6397.468872007683),
    )
  let from = 0.00000003011885532211048
  let to = 0.2841409618472
  let assert Ok(tail) = svg_path.segment_between(arc, from:, to: 1.0)
  let assert Ok(original) = svg_path.segment_point(arc, at: to)
  let assert Ok(reconstructed) =
    svg_path.segment_point(tail, at: { to -. from } /. { 1.0 -. from })
  let dx = original.x -. reconstructed.x
  let dy = original.y -. reconstructed.y
  echo #("original", original)
  echo #("reconstructed", reconstructed)
  echo #("distance", float.square_root(dx *. dx +. dy *. dy))
}
