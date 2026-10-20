import gleam/float
import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/arrangement
import svg_path/measure
import svg_path/offset
import svg_path/point

fn near_semicircle() -> svg_path.Segment {
  Arc(
    Point(66.48121035659938, 6559.430109164913),
    Point(81.0, 81.0),
    0.0,
    False,
    False,
    Point(70.02488902419492, 6397.468872007683),
  )
}

pub fn progressive_arc_split_preserves_source_geometry_in_both_orders_test() {
  let arc = near_semicircle()
  let assert Ok(cut) = svg_path.segment_point(arc, 0.00000003011885532211048)
  let assert Ok(cross) = svg_path.segment_point(arc, 0.2841409618472)
  let assert Ok(data) = svg_path.arc_center_data(arc)
  let center = data.center
  let chord = Line(svg_path.segment_start(arc), cut)
  let crossing =
    Line(
      Point(center.x, center.y),
      Point(2.0 *. cross.x -. center.x, 2.0 *. cross.y -. center.y),
    )
  list.each([[arc, chord, crossing], [arc, crossing, chord]], fn(segments) {
    list.each([False, True], fn(reverse) {
      let segments = case reverse {
        True -> list.map(segments, svg_path.segment_reverse)
        False -> segments
      }
      let assert Ok(build) =
        arrangement.build_with(segments, 1.0e-9, 1.0e-9, 1.0e-8)
      assert list.length(build.segment_images) == 3
      list.each(build.segment_images, fn(image) {
        let assert Ok(source) =
          list.first(list.drop(segments, image.segment_index))
        assert !list.is_empty(image.edges)
        list.each(image.edges, fn(reference) {
          let assert Ok(edge) =
            list.find(build.graph.edges, fn(edge) {
              edge.id == reference.edge_id
            })
          list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
            let parameter =
              reference.ta +. t *. { reference.tb -. reference.ta }
            let assert Ok(expected) = svg_path.segment_point(source, parameter)
            let local = case reference.reversed {
              True -> 1.0 -. t
              False -> t
            }
            let assert Ok(actual) = svg_path.segment_point(edge.segment, local)
            assert point.distance(expected, actual) <=. 4.0e-9
          })
        })
      })
    })
  })
}

pub fn untouched_near_semicircle_does_not_gain_vertices_test() {
  let arc = near_semicircle()
  let assert Ok(build) = arrangement.build_with([arc], 1.0e-9, 1.0e-9, 1.0e-8)
  let assert [edge] = build.graph.edges
  assert edge.segment == arc
  assert list.length(build.graph.vertices) == 2
}

// Cavalier CC01301: construction regression, not an assertion of matching
// Cavalier's additional fragment or trimming policy.
pub fn short_reversal_offset_constructs_after_arc_subdivision_test() {
  let assert Ok(source) =
    svg_path.subpath([
      Line(
        Point(68.25293808952344, 6478.449488144498),
        Point(68.25294877264348, 6478.449488378243),
      ),
      Line(
        Point(68.25294877264348, 6478.449488378243),
        Point(68.2530460022322, 6478.449490505602),
      ),
      Arc(
        Point(68.2530460022322, 6478.449490505602),
        Point(81.00000006547448, 81.00000006547448),
        0.0,
        False,
        False,
        Point(68.25303273506862, 6478.449490215318),
      ),
      Arc(
        Point(68.25303273506862, 6478.449490215318),
        Point(223.56718275549048, 223.56718275549048),
        0.0,
        False,
        False,
        Point(68.25305743646584, 6478.449490755781),
      ),
      Arc(
        Point(68.25305743646584, 6478.449490755781),
        Point(6480.018556730979, 6480.018556730979),
        0.0,
        False,
        False,
        Point(130.82875758123276, 6479.516333367319),
      ),
      Line(
        Point(130.82875758123276, 6479.516333367319),
        Point(130.82888192355495, 6479.516334886616),
      ),
      Line(
        Point(130.82888192355495, 6479.516334886616),
        Point(130.82891523733778, 6479.516335293666),
      ),
    ])
  let assert Ok(result) =
    offset.subpath(source, -81.0, offset.Round, offset.Butt)
  let assert [path] = svg_path.path_subpaths(result)
  let assert Ok(length) = measure.subpath_length(path)
  assert float.absolute_value(length -. 63.367633966914624) <. 0.000001
}
