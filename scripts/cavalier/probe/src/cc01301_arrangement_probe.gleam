import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/arrangement

pub fn main() {
  let arc =
    Arc(
      Point(66.48121035659938, 6559.430109164913),
      Point(81.0, 81.0),
      0.0,
      False,
      False,
      Point(70.02488902419492, 6397.468872007683),
    )
  let assert Ok(cut) = svg_path.segment_point(arc, 0.00000003011885532211048)
  let assert Ok(cross) = svg_path.segment_point(arc, 0.2841409618472)
  let assert Ok(center) = svg_path.arc_center_data(arc)
  let center = center.center
  let chord = Line(svg_path.segment_start(arc), cut)
  let crossing =
    Line(
      Point(center.x, center.y),
      Point(2.0 *. cross.x -. center.x, 2.0 *. cross.y -. center.y),
    )
  list.each(
    [
      #("endpoint then crossing", [arc, chord, crossing]),
      #("crossing then endpoint", [arc, crossing, chord]),
    ],
    fn(item) {
      let #(label, segments) = item
      let result =
        arrangement.build_with(segments, 0.000000001, 0.000000001, 0.00000001)
      echo #(label, case result {
        Ok(build) -> Ok(list.length(build.graph.edges))
        Error(error) -> Error(error)
      })
    },
  )
}
