// Historical diagnostic reductions, now also covered by the portable
// svg_path_csg_face_winding_test module.
import gleam/float
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/area
import svg_path/arrangement
import svg_path/csg

fn triangle(a: svg_path.Point, b: svg_path.Point, c: svg_path.Point) {
  svg_path.subpath_assert([
    svg_path.Line(a, b),
    svg_path.Line(b, c),
    svg_path.Line(c, a),
  ])
  |> svg_path.subpath_assert_close
  |> svg_path.subpath_as_path
}

fn check_union(name, left, right, expected_area) {
  let assert Ok(build) =
    arrangement.build([left, right], tolerance: 1.0e-6, minimum_length: 1.0e-5)
  let assert Ok(Nil) =
    arrangement.validate_closed_boundaries(
      build.graph,
      tolerance: 1.0e-6,
      minimum_length: 1.0e-5,
    )
  let assert Ok(dual) = arrangement.dual(build.graph)
  let per_operand =
    list.map([0, 1], fn(operand) {
      let changes =
        list.map(build.graph.edges, fn(edge) {
          let change =
            list.fold(build.segment_images, 0, fn(total, image) {
              case image.path_index == operand {
                False -> total
                True ->
                  list.fold(image.edges, total, fn(total, reference) {
                    case reference.edge_id == edge.id, reference.reversed {
                      True, True -> total - 1
                      True, False -> total + 1
                      False, _ -> total
                    }
                  })
              }
            })
          arrangement.EdgeWindingChange(edge.id, change)
        })
      let assert Ok(windings) = arrangement.face_windings(dual, changes)
      windings
    })
  let dual_area =
    list.fold(dual.edge_faces, 0.0, fn(total, faces) {
      let filled = fn(face) {
        list.any(per_operand, fn(windings) {
          let assert Ok(winding) =
            list.find(windings, fn(w) { w.face_id == face })
          winding.value != 0
        })
      }
      let assert Ok(edge) =
        list.find(build.graph.edges, fn(e) { e.id == faces.edge_id })
      case filled(faces.left_face), filled(faces.right_face) {
        True, False -> total -. area.signed_segment(edge.segment)
        False, True -> total +. area.signed_segment(edge.segment)
        _, _ -> total
      }
    })
    |> float.absolute_value
  assert float.absolute_value(dual_area -. expected_area) <. 1.0e-12
  io.println("Dual/provenance union area " <> float.to_string(dual_area))
  let actual = csg.union_path(left, right, using: svg_path.Nonzero)
  let correct = case actual {
    Error(_) -> False
    Ok(path) ->
      float.absolute_value(
        float.absolute_value(area.signed_path(path)) -. expected_area,
      )
      <. 1.0e-12
  }
  io.println(name <> ": " <> string.inspect(actual))
  io.println(
    "Expected union area "
    <> float.to_string(expected_area)
    <> "; passed="
    <> string.inspect(correct),
  )
  correct
}

pub fn main() {
  let origin = svg_path.Point(0.0, 0.0)
  let top = svg_path.Point(0.0, 2.0)
  let nested =
    check_union(
      "nested triangles",
      triangle(origin, svg_path.Point(1.0, 1.0), top),
      triangle(origin, svg_path.Point(1.00004, 1.0), top),
      1.00004,
    )
  let short = svg_path.Point(0.0, -0.00004)
  let thin =
    check_union(
      "thin triangles",
      triangle(origin, short, svg_path.Point(-1.0, -1.0)),
      triangle(short, origin, svg_path.Point(1.0, -1.0)),
      0.00004,
    )
  assert nested && thin
}
