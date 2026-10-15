import gleam/list
import svg_path.{type Point, Line, Point}
import svg_path/arrangement
import svg_path/point

// Reduced FL002/FL003 fans. Sampling in world coordinates reversed each
// nearly parallel pair, including a pair classified as separate groups.
pub fn fl002_large_coordinate_fan_test() {
  check_fan(
    Point(1_286_232_330.342853, 54_685_500.32193941),
    [
      Point(1_286_198_103.4762266, 54_821_391.148841284),
      Point(1_319_996_203.9438455, 457_619.7648851394),
      Point(1_319_996_203.9439175, 457_619.7647740394),
    ],
    [0, 1, 2],
  )
}

pub fn fl003_short_radius_fan_test() {
  check_fan(
    Point(976_070_000.0, 221_360_000.0),
    [
      Point(976_070_737.1913013, 221_360_000.0),
      Point(966_175_296.766696, 251_057_267.55705994),
      Point(961_030_000.0, 266_500_000.0),
    ],
    [0, 1, 2],
  )
}

pub fn fl003_separate_groups_fan_test() {
  check_fan(
    Point(975_897_619.6303852, 232_028_812.02494428),
    [
      Point(975_950_000.0, 231_876_924.60976407),
      Point(967_950_526.5044882, 255_073_006.67197832),
      Point(963_110_483.3545867, 269_107_685.0983405),
    ],
    [1, 2, 0],
  )
}

fn check_fan(center: Point, ends: List(Point), expected: List(Int)) {
  list.each([False, True], fn(centered) {
    let move = fn(p) {
      case centered {
        True -> point.subtract(p, center)
        False -> p
      }
    }
    list.each([False, True], fn(reversed) {
      let vertices =
        [center, ..ends]
        |> list.index_map(fn(p, id) {
          arrangement.ArrangementVertex(id, move(p), [move(p)])
        })
      let edges =
        list.index_map(ends, fn(end, id) {
          let segment = case reversed {
            True -> Line(move(end), move(center))
            False -> Line(move(center), move(end))
          }
          let assert Ok(bounds) = svg_path.segment_bounding_box(segment)
          arrangement.ArrangementEdge(
            id,
            segment,
            bounds,
            case reversed {
              True -> id + 1
              False -> 0
            },
            case reversed {
              True -> 0
              False -> id + 1
            },
            1,
            0,
          )
        })
      let graph = arrangement.ArrangementGraph(vertices, edges, [])
      let assert Ok(groups) =
        arrangement.vertex_cyclic_order_with(graph, 0, 0.000001, 3)
      assert groups |> list.flatten |> list.map(fn(edge) { edge.edge_id })
        == expected
    })
  })
}
