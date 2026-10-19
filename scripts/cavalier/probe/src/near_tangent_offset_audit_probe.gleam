import gleam/float
import svg_path.{Arc, Line, Point}
import svg_path/offset

pub fn main() {
  let tiny =
    Arc(
      Point(44.65470741897046, -2.0000001287369904),
      Point(1.0, 1.0),
      0.0,
      False,
      True,
      Point(44.65470741271587, -2.0000001287338165),
    )
  let _ = echo svg_path.arc_center_data(tiny)
  let _ = echo svg_path.segment_between_inside(tiny, 0.9999995858161379, 1.0)
  let assert Ok(#(_, remainder)) =
    svg_path.segment_split(tiny, 0.9999995858161379)
  let _ =
    echo #(svg_path.segment_start(remainder), svg_path.segment_end(remainder))
  let bulge = 0.198723
  let dx = 44.6542 -. 42.1788
  let dy = -3.0 -. -1.97424
  let assert Ok(chord) = float.square_root(dx *. dx +. dy *. dy)
  let radius = chord *. { 1.0 +. bulge *. bulge } /. { 4.0 *. bulge }
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(28.4408, 11.7648), Point(42.1788, -1.97424)),
      Arc(
        Point(42.1788, -1.97424),
        Point(radius, radius),
        0.0,
        False,
        True,
        Point(44.6542, -3.0),
      ),
      Line(Point(44.6542, -3.0), Point(49.6542, -3.0)),
    ])
  let _ = echo offset.subpath(source, -1.0, offset.Round, offset.Butt)
  Nil
}
