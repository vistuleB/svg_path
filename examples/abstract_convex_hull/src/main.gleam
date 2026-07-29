import abstract_union
import convex_loop
import convex_polygon_loop
import cubic_convex_pieces
import face_polygon_loop
import face_union
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import new_hull_experiment/fixtures
import polygon_loop
import segment_hull_loop
import svg_path
import svg_path/convex_hull
import svg_path/svg

const run_slow_cubic_comparison = False

pub fn main() -> Nil {
  io.println("abstract convex loop union experiment")
  io.println("")
  polygon_demo()
  io.println("")
  segment_demo()
  io.println("")
  cubic_split_stress_demo()
  io.println("")
  face_support_demo()
  io.println("")
  explicit_loop_model_demo()
  case run_slow_cubic_comparison {
    True -> {
      io.println("")
      cubic_algorithm_comparison_demo()
    }
    False -> Nil
  }
}

fn polygon_demo() -> Nil {
  let left =
    polygon_loop.loop("left rectangle", [
      svg_path.Point(10.0, 20.0),
      svg_path.Point(70.0, 20.0),
      svg_path.Point(70.0, 70.0),
      svg_path.Point(10.0, 70.0),
    ])

  let right =
    polygon_loop.loop("tilted quadrilateral", [
      svg_path.Point(55.0, 5.0),
      svg_path.Point(125.0, 35.0),
      svg_path.Point(105.0, 95.0),
      svg_path.Point(45.0, 82.0),
    ])

  let pieces = abstract_union.union(left, right, sample_count: 180)
  io.println("polygon pieces:")
  io.println(describe_polygon_pieces(pieces))
  case abstract_union.union_subpath(pieces, left, right) {
    Error(error) -> {
      io.println("")
      io.println("polygon subpath failed:")
      echo error
      Nil
    }
    Ok(subpath) -> {
      io.println("")
      io.println("polygon svg:")
      io.println(render_demo("polygon union", [svg_path.Path([subpath])]))
      print_support_report(
        "polygon support",
        left,
        right,
        svg_path.subpath_segments(subpath),
        tolerance: 0.000001,
      )
    }
  }
}

fn segment_demo() -> Nil {
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.Point(10.0, 80.0),
      control1: svg_path.Point(45.0, -10.0),
      control2: svg_path.Point(105.0, 120.0),
      end: svg_path.Point(135.0, 20.0),
    )

  let arc =
    svg_path.Arc(
      start: svg_path.Point(35.0, 55.0),
      radius: svg_path.Point(46.0, 30.0),
      x_axis_rotation: 15.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(130.0, 78.0),
    )

  case
    segment_hull_loop.loop("cubic", cubic),
    segment_hull_loop.loop("arc", arc)
  {
    Error(error), _ | _, Error(error) -> {
      io.println("segment demo failed:")
      echo error
      Nil
    }
    Ok(cubic_loop), Ok(arc_loop) -> {
      let pieces = abstract_union.union(cubic_loop, arc_loop, sample_count: 360)
      case abstract_union.union_subpath(pieces, cubic_loop, arc_loop) {
        Error(error) -> {
          io.println("segment demo subpath failed:")
          echo error
          Nil
        }
        Ok(subpath) -> {
          io.println("segment-hull pieces:")
          io.println(describe_segment_pieces(pieces))
          io.println("")
          io.println("segment svg:")
          io.println(
            render_demo("segment hull union", [svg_path.Path([subpath])]),
          )
          print_support_report(
            "segment support",
            cubic_loop,
            arc_loop,
            svg_path.subpath_segments(subpath),
            tolerance: 0.02,
          )
        }
      }
    }
  }
}

fn print_support_report(
  label: String,
  loop_a: abstract_union.Loop(a),
  loop_b: abstract_union.Loop(b),
  segments: List(svg_path.Segment),
  tolerance tolerance: Float,
) -> Nil {
  case support_mismatch_report(loop_a, loop_b, segments, tolerance:) {
    Ok(Nil) -> io.println(label <> ": ok")
    Error(report) -> {
      io.println(label <> ": mismatch")
      io.println(report)
    }
  }
}

fn cubic_split_stress_demo() -> Nil {
  let specimens = fixtures.cubic_specimens()
  let results =
    specimens
    |> list.map(fn(specimen) {
      let #(name, segment) = specimen
      stress_cubic(name, segment)
    })

  let failures =
    results
    |> list.filter_map(fn(result) {
      case result {
        Ok(_) -> Error(Nil)
        Error(report) -> Ok(report)
      }
    })

  io.println(
    "cubic split stress: "
    <> int.to_string(list.length(results) - list.length(failures))
    <> "/"
    <> int.to_string(list.length(results))
    <> " ok",
  )

  case failures {
    [] -> Nil
    _ -> {
      io.println("cubic split stress failures:")
      failures
      |> list.take(8)
      |> string.join("\n")
      |> io.println
    }
  }
}

type ErrorStats {
  ErrorStats(name: String, max: Float, average: Float)
}

fn cubic_algorithm_comparison_demo() -> Nil {
  let specimens = fixtures.cubic_specimens()
  let comparison_angles = degree_range(step: 1)

  let reports =
    specimens
    |> list.map(fn(specimen) {
      let #(name, segment) = specimen
      #(
        production_error_stats(name, segment, comparison_angles),
        split_error_stats(name, segment, comparison_angles),
      )
    })

  let production = collect_ok_reports(reports, fn(pair) { pair.0 })
  let split = collect_ok_reports(reports, fn(pair) { pair.1 })
  let failures = collect_failures(reports)

  io.println("cubic support error comparison over 1-degree directions:")
  io.println("production segment_hull: " <> summarize_stats(production))
  io.println("inflection split union:  " <> summarize_stats(split))

  io.println("worst production cases:")
  production
  |> sort_stats
  |> list.take(5)
  |> list.map(format_stats)
  |> string.join("\n")
  |> io.println

  io.println("worst inflection-split cases:")
  split
  |> sort_stats
  |> list.take(5)
  |> list.map(format_stats)
  |> string.join("\n")
  |> io.println

  case failures {
    [] -> Nil
    _ -> {
      io.println("comparison failures:")
      failures
      |> list.take(8)
      |> string.join("\n")
      |> io.println
    }
  }
}

fn face_support_demo() -> Nil {
  let left =
    face_polygon_loop.loop("left square", [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let right =
    face_polygon_loop.loop("right square", [
      svg_path.Point(5.0, 0.0),
      svg_path.Point(15.0, 0.0),
      svg_path.Point(15.0, 10.0),
      svg_path.Point(5.0, 10.0),
    ])
  let touching =
    face_polygon_loop.loop("touching square", [
      svg_path.Point(10.0, 0.0),
      svg_path.Point(20.0, 0.0),
      svg_path.Point(20.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])
  let inner_square =
    face_polygon_loop.loop("inner square", [
      svg_path.Point(4.0, 0.0),
      svg_path.Point(8.0, 0.0),
      svg_path.Point(8.0, 10.0),
      svg_path.Point(4.0, 10.0),
    ])
  let wide_rectangle =
    face_polygon_loop.loop("wide rectangle", [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(12.0, 0.0),
      svg_path.Point(12.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let large_square =
    face_polygon_loop.loop("large square", [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(12.0, 0.0),
      svg_path.Point(12.0, 12.0),
      svg_path.Point(0.0, 12.0),
    ])
  let corner_square =
    face_polygon_loop.loop("corner square", [
      svg_path.Point(9.0, 9.0),
      svg_path.Point(12.0, 9.0),
      svg_path.Point(12.0, 12.0),
      svg_path.Point(9.0, 12.0),
    ])
  let diagonal_parallelogram =
    face_polygon_loop.loop("diagonal parallelogram", [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(8.0, 4.0),
      svg_path.Point(12.0, 12.0),
      svg_path.Point(4.0, 8.0),
    ])
  let half_cut_triangle =
    face_polygon_loop.loop("half-cut triangle", [
      svg_path.Point(-4.0, 2.0),
      svg_path.Point(16.0, 6.0),
      svg_path.Point(-4.0, 10.0),
    ])

  io.println("face-aware support cases:")
  [
    #("overlap right", face_union.union_support(left, right, angle: 0.0)),
    #("overlap top", face_union.union_support(left, right, angle: 90.0)),
    #(
      "touching vertical seam",
      face_union.union_support(left, touching, angle: 0.0),
    ),
    #(
      "touching shared top",
      face_union.union_support(left, touching, angle: 90.0),
    ),
    #(
      "square, rectangle right",
      face_union.union_support(inner_square, wide_rectangle, angle: 0.0),
    ),
    #(
      "square, rectangle left",
      face_union.union_support(inner_square, wide_rectangle, angle: 180.0),
    ),
    #(
      "square, rectangle top",
      face_union.union_support(inner_square, wide_rectangle, angle: 90.0),
    ),
    #(
      "square, rectangle bottom",
      face_union.union_support(inner_square, wide_rectangle, angle: 270.0),
    ),
    #(
      "rectangle, square right",
      face_union.union_support(wide_rectangle, inner_square, angle: 0.0),
    ),
    #(
      "rectangle, square left",
      face_union.union_support(wide_rectangle, inner_square, angle: 180.0),
    ),
    #(
      "rectangle, square top",
      face_union.union_support(wide_rectangle, inner_square, angle: 90.0),
    ),
    #(
      "rectangle, square bottom",
      face_union.union_support(wide_rectangle, inner_square, angle: 270.0),
    ),
    #(
      "corner square inside large NE",
      face_union.union_support(large_square, corner_square, angle: 45.0),
    ),
    #(
      "corner square inside large right",
      face_union.union_support(large_square, corner_square, angle: 0.0),
    ),
    #(
      "corner square inside large top",
      face_union.union_support(large_square, corner_square, angle: 90.0),
    ),
    #(
      "corner square first NE",
      face_union.union_support(corner_square, large_square, angle: 45.0),
    ),
    #(
      "corner square first right",
      face_union.union_support(corner_square, large_square, angle: 0.0),
    ),
    #(
      "corner square first top",
      face_union.union_support(corner_square, large_square, angle: 90.0),
    ),
    #(
      "parallelogram in square diagonal",
      face_union.union_support(
        large_square,
        diagonal_parallelogram,
        angle: 45.0,
      ),
    ),
    #(
      "parallelogram in square east",
      face_union.union_support(large_square, diagonal_parallelogram, angle: 0.0),
    ),
    #(
      "parallelogram first diagonal",
      face_union.union_support(
        diagonal_parallelogram,
        large_square,
        angle: 45.0,
      ),
    ),
    #(
      "triangle cuts square east",
      face_union.union_support(large_square, half_cut_triangle, angle: 0.0),
    ),
    #(
      "triangle cuts square west",
      face_union.union_support(large_square, half_cut_triangle, angle: 180.0),
    ),
    #(
      "triangle cuts square NE",
      face_union.union_support(large_square, half_cut_triangle, angle: 45.0),
    ),
  ]
  |> list.map(fn(case_) {
    let #(label, support) = case_
    label <> ": " <> describe_union_support(support)
  })
  |> string.join("\n")
  |> io.println
}

fn explicit_loop_model_demo() -> Nil {
  let square =
    convex_polygon_loop.loop("explicit square", [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let shifted =
    convex_polygon_loop.loop("explicit shifted square", [
      svg_path.Point(5.0, 0.0),
      svg_path.Point(15.0, 0.0),
      svg_path.Point(15.0, 10.0),
      svg_path.Point(5.0, 10.0),
    ])

  io.println("explicit ConvexLoop support cases:")
  [
    #("right", convex_loop.union_support(square, shifted, angle: 0.0)),
    #("top", convex_loop.union_support(square, shifted, angle: 90.0)),
  ]
  |> list.map(fn(case_) {
    let #(label, support) = case_
    label <> ": " <> describe_explicit_union_support(support, square, shifted)
  })
  |> string.join("\n")
  |> io.println
}

fn describe_explicit_union_support(
  support: convex_loop.UnionSupport(Int, Int),
  loop_a: convex_loop.ConvexLoop(Int),
  loop_b: convex_loop.ConvexLoop(Int),
) -> String {
  case support {
    convex_loop.AWins(set) ->
      "A wins " <> describe_explicit_support_set(set, loop_a)
    convex_loop.BWins(set) ->
      "B wins " <> describe_explicit_support_set(set, loop_b)
    convex_loop.Tie(a, b) ->
      "tie A "
      <> describe_explicit_support_set(a, loop_a)
      <> " / B "
      <> describe_explicit_support_set(b, loop_b)
  }
}

fn describe_explicit_support_set(
  set: convex_loop.SupportSet(Int),
  loop: convex_loop.ConvexLoop(Int),
) -> String {
  case set {
    convex_loop.SupportPoint(point:) ->
      "point("
      <> loop.point_label(point)
      <> " "
      <> point_label(loop.point(point))
      <> ")"
    convex_loop.SupportFace(from:, to:) ->
      "face("
      <> loop.point_label(from)
      <> " "
      <> point_label(loop.point(from))
      <> " -> "
      <> loop.point_label(to)
      <> " "
      <> point_label(loop.point(to))
      <> ")"
  }
}

fn describe_union_support(
  support: face_union.UnionSupport(
    face_polygon_loop.Param,
    face_polygon_loop.Param,
  ),
) -> String {
  case support {
    face_union.AWins(set) -> "A wins " <> describe_face_set(set)
    face_union.BWins(set) -> "B wins " <> describe_face_set(set)
    face_union.Tie(a, b) ->
      "tie A "
      <> describe_face_set(a)
      <> " / B "
      <> describe_face_set(b)
      <> describe_face_tie(a, b)
  }
}

fn describe_face_tie(
  a: face_union.SupportSet(face_polygon_loop.Param),
  b: face_union.SupportSet(face_polygon_loop.Param),
) -> String {
  case a, b {
    face_union.SupportFace(..), face_union.SupportFace(..) ->
      " [" <> face_overlap_label(a, b) <> "]"
    _, _ -> ""
  }
}

fn face_overlap_label(
  a: face_union.SupportSet(face_polygon_loop.Param),
  b: face_union.SupportSet(face_polygon_loop.Param),
) -> String {
  let #(a0, a1) = face_union.support_set_points(a)
  let #(b0, b1) = face_union.support_set_points(b)
  let use_x =
    float.absolute_value(a0.x -. a1.x) >=. float.absolute_value(a0.y -. a1.y)
  let a_min = projection_min(a0, a1, use_x:)
  let a_max = projection_max(a0, a1, use_x:)
  let b_min = projection_min(b0, b1, use_x:)
  let b_max = projection_max(b0, b1, use_x:)
  let overlap_min = float.max(a_min, b_min)
  let overlap_max = float.min(a_max, b_max)

  case overlap_max <. overlap_min -. 0.0000001 {
    True -> "collinear faces disjoint"
    False ->
      case float.absolute_value(overlap_max -. overlap_min) <=. 0.0000001 {
        True ->
          "collinear faces touch at "
          <> projected_point_label(a0, a1, overlap_min, use_x:)
        False ->
          "collinear faces overlap "
          <> projected_point_label(a0, a1, overlap_min, use_x:)
          <> " -> "
          <> projected_point_label(a0, a1, overlap_max, use_x:)
      }
  }
}

fn projection_min(
  a: svg_path.Point,
  b: svg_path.Point,
  use_x use_x: Bool,
) -> Float {
  float.min(project(a, use_x:), project(b, use_x:))
}

fn projection_max(
  a: svg_path.Point,
  b: svg_path.Point,
  use_x use_x: Bool,
) -> Float {
  float.max(project(a, use_x:), project(b, use_x:))
}

fn project(point: svg_path.Point, use_x use_x: Bool) -> Float {
  case use_x {
    True -> point.x
    False -> point.y
  }
}

fn projected_point_label(
  a: svg_path.Point,
  b: svg_path.Point,
  value: Float,
  use_x use_x: Bool,
) -> String {
  case use_x {
    True -> {
      let fraction = case float.absolute_value(b.x -. a.x) <=. 0.0000001 {
        True -> 0.0
        False -> { value -. a.x } /. { b.x -. a.x }
      }
      point_label(svg_path.Point(value, a.y +. fraction *. { b.y -. a.y }))
    }
    False -> {
      let fraction = case float.absolute_value(b.y -. a.y) <=. 0.0000001 {
        True -> 0.0
        False -> { value -. a.y } /. { b.y -. a.y }
      }
      point_label(svg_path.Point(a.x +. fraction *. { b.x -. a.x }, value))
    }
  }
}

fn describe_face_set(
  set: face_union.SupportSet(face_polygon_loop.Param),
) -> String {
  case set {
    face_union.SupportPoint(param:, point:) ->
      "point(" <> face_param_label(param) <> " " <> point_label(point) <> ")"
    face_union.SupportFace(from:, to:, from_point:, to_point:) ->
      "face("
      <> face_param_label(from)
      <> " "
      <> point_label(from_point)
      <> " -> "
      <> face_param_label(to)
      <> " "
      <> point_label(to_point)
      <> ")"
  }
}

fn face_param_label(param: face_polygon_loop.Param) -> String {
  let face_polygon_loop.Vertex(index) = param
  "v" <> int.to_string(index)
}

fn point_label(point: svg_path.Point) -> String {
  "(" <> float.to_string(point.x) <> "," <> float.to_string(point.y) <> ")"
}

fn production_error_stats(
  name: String,
  segment: svg_path.Segment,
  angles: List(Float),
) -> Result(ErrorStats, String) {
  use hull <- result.try(
    convex_hull.segment_hull(segment)
    |> result.map_error(fn(error) {
      name <> " production hull failed " <> string.inspect(error)
    }),
  )
  error_stats(name, segment, svg_path.subpath_segments(hull), angles)
}

fn split_error_stats(
  name: String,
  segment: svg_path.Segment,
  angles: List(Float),
) -> Result(ErrorStats, String) {
  use segments <- result.try(
    cubic_convex_pieces.hull_segments(segment)
    |> result.map_error(fn(error) {
      name <> " split hull failed " <> string.inspect(error)
    }),
  )
  error_stats(name, segment, segments, angles)
}

fn error_stats(
  name: String,
  segment: svg_path.Segment,
  hull_segments: List(svg_path.Segment),
  angles: List(Float),
) -> Result(ErrorStats, String) {
  use errors <- result.try(
    angles
    |> list.try_map(fn(angle) {
      use expected <- result.try(
        original_support_value(segment, angle)
        |> result.map_error(fn(error) {
          name <> " original support errored " <> error
        }),
      )
      use actual <- result.try(
        path_support_value(hull_segments, angle)
        |> result.map_error(fn(error) {
          name <> " hull support errored " <> error
        }),
      )
      Ok(float.absolute_value(expected -. actual))
    }),
  )
  let assert [first, ..rest] = errors
  let #(max_error, sum_error) =
    rest
    |> list.fold(#(first, first), fn(acc, error) {
      #(float.max(acc.0, error), acc.1 +. error)
    })
  Ok(ErrorStats(
    name:,
    max: max_error,
    average: sum_error /. int.to_float(list.length(errors)),
  ))
}

fn collect_ok_reports(
  reports: List(#(Result(ErrorStats, String), Result(ErrorStats, String))),
  pick: fn(#(Result(ErrorStats, String), Result(ErrorStats, String))) ->
    Result(ErrorStats, String),
) -> List(ErrorStats) {
  reports
  |> list.filter_map(fn(report) {
    case pick(report) {
      Ok(stats) -> Ok(stats)
      Error(_) -> Error(Nil)
    }
  })
}

fn collect_failures(
  reports: List(#(Result(ErrorStats, String), Result(ErrorStats, String))),
) -> List(String) {
  reports
  |> list.flat_map(fn(report) {
    case report {
      #(Ok(_), Ok(_)) -> []
      #(Error(error), Ok(_)) -> [error]
      #(Ok(_), Error(error)) -> [error]
      #(Error(left), Error(right)) -> [left, right]
    }
  })
}

fn summarize_stats(stats: List(ErrorStats)) -> String {
  case stats {
    [] -> "no successful cases"
    [first, ..rest] -> {
      let totals =
        rest
        |> list.fold(#(first.max, first.average, 1), fn(acc, stats) {
          #(float.max(acc.0, stats.max), acc.1 +. stats.average, acc.2 + 1)
        })
      "global max "
      <> float.to_string(totals.0)
      <> ", mean average "
      <> float.to_string(totals.1 /. int.to_float(totals.2))
    }
  }
}

fn sort_stats(stats: List(ErrorStats)) -> List(ErrorStats) {
  list.sort(stats, by: fn(a, b) { float.compare(b.max, a.max) })
}

fn format_stats(stats: ErrorStats) -> String {
  stats.name
  <> ": max "
  <> float.to_string(stats.max)
  <> ", avg "
  <> float.to_string(stats.average)
}

fn stress_cubic(
  name: String,
  segment: svg_path.Segment,
) -> Result(Nil, String) {
  use hull_segments <- result.try(
    cubic_convex_pieces.hull_segments(segment)
    |> result.map_error(fn(error) {
      name <> ": hull construction failed " <> string.inspect(error)
    }),
  )

  support_mismatch_report_for_segment(
    name,
    segment,
    hull_segments,
    tolerance: segment_support_tolerance(segment),
  )
}

fn support_mismatch_report_for_segment(
  name: String,
  original: svg_path.Segment,
  hull_segments: List(svg_path.Segment),
  tolerance tolerance: Float,
) -> Result(Nil, String) {
  multiples_of_10_degrees()
  |> list.try_each(fn(angle) {
    use expected <- result.try(
      original_support_value(original, angle)
      |> result.map_error(fn(error) {
        name <> ": original support errored " <> error
      }),
    )
    use union_value <- result.try(
      path_support_value(hull_segments, angle)
      |> result.map_error(fn(error) {
        name <> ": hull support errored " <> error
      }),
    )
    let difference = float.absolute_value(expected -. union_value)
    case difference <=. tolerance {
      True -> Ok(Nil)
      False ->
        Error(
          name
          <> " angle "
          <> float.to_string(angle)
          <> ": expected "
          <> float.to_string(expected)
          <> ", got "
          <> float.to_string(union_value)
          <> ", difference "
          <> float.to_string(difference)
          <> ", tolerance "
          <> float.to_string(tolerance),
        )
    }
  })
}

fn support_mismatch_report(
  loop_a: abstract_union.Loop(a),
  loop_b: abstract_union.Loop(b),
  segments: List(svg_path.Segment),
  tolerance tolerance: Float,
) -> Result(Nil, String) {
  multiples_of_10_degrees()
  |> list.try_each(fn(angle) {
    use union_value <- result.try(path_support_value(segments, angle))
    let expected =
      float.max(loop_a.support(angle).value, loop_b.support(angle).value)
    let difference = float.absolute_value(expected -. union_value)
    case difference <=. tolerance {
      True -> Ok(Nil)
      False ->
        Error(
          "angle "
          <> float.to_string(angle)
          <> ": expected "
          <> float.to_string(expected)
          <> ", got "
          <> float.to_string(union_value)
          <> ", difference "
          <> float.to_string(difference)
          <> ", tolerance "
          <> float.to_string(tolerance),
        )
    }
  })
}

fn multiples_of_10_degrees() -> List(Float) {
  degree_range(step: 10)
}

fn degree_range(step step: Int) -> List(Float) {
  int.range(from: 0, to: 360 / step - 1, with: [], run: fn(angles, multiple) {
    [int.to_float(multiple * step), ..angles]
  })
  |> list.reverse
}

fn path_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(Float, String) {
  use point <- result.try(path_support_point(segments, angle))
  Ok(point_support(point, angle))
}

fn original_support_value(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(Float, String) {
  use point <- result.try(segment_support_point(segment, angle))
  Ok(point_support(point, angle))
}

fn path_support_point(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(svg_path.Point, String) {
  case segments {
    [] -> Error("empty path")
    [first, ..rest] -> {
      use point <- result.try(segment_support_point(first, angle))
      path_support_point_loop(rest, angle, point)
    }
  }
}

fn path_support_point_loop(
  segments: List(svg_path.Segment),
  angle: Float,
  best: svg_path.Point,
) -> Result(svg_path.Point, String) {
  case segments {
    [] -> Ok(best)
    [segment, ..rest] -> {
      use point <- result.try(segment_support_point(segment, angle))
      let best = case
        point_support(point, angle) >. point_support(best, angle)
      {
        True -> point
        False -> best
      }
      path_support_point_loop(rest, angle, best)
    }
  }
}

fn segment_support_point(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(svg_path.Point, String) {
  let direction = abstract_union.direction(angle)
  svg_path.segment_minimize(segment, measure: fn(point) {
    0.0 -. abstract_union.dot(point, direction)
  })
  |> result.map_error(fn(error) { string.inspect(error) })
  |> result.try(fn(t) {
    svg_path.segment_point(segment, at: t)
    |> result.map_error(fn(error) { string.inspect(error) })
  })
}

fn point_support(point: svg_path.Point, angle: Float) -> Float {
  abstract_union.dot(point, abstract_union.direction(angle))
}

fn segment_support_tolerance(segment: svg_path.Segment) -> Float {
  case svg_path.segment_bounding_box(segment) {
    Error(_) -> 0.000001
    Ok(box) ->
      float.max(0.000001, svg_path.bounding_box_diameter(box) *. 0.00000002)
  }
}

fn render_demo(label: String, paths: List(svg_path.Path)) -> String {
  let colors = ["#1d3557", "#e76f51", "#2a9d8f", "#7b2cbf"]
  let things =
    paths
    |> list.index_map(fn(path, index) {
      let color = case nth(colors, index) {
        Ok(color) -> color
        Error(_) -> "#111111"
      }
      svg.StyledPath(
        path,
        "fill: rgba(42, 157, 143, 0.08); stroke: "
          <> color
          <> "; stroke-width: 2; stroke-linejoin: round",
      )
    })

  svg.document(
    list.append(things, [
      svg.Text(
        label,
        "fill: #333; font-family: system-ui, sans-serif",
        svg_path.Point(0.0, -7.0),
        7,
      ),
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(-10.0, -15.0),
      max: svg_path.Point(150.0, 115.0),
    ),
  )
}

fn describe_polygon_pieces(
  pieces: List(
    abstract_union.UnionPiece(polygon_loop.Param, polygon_loop.Param),
  ),
) -> String {
  pieces
  |> list.map(fn(piece) {
    case piece {
      abstract_union.LoopPieceA(a, b) ->
        "LoopPieceA(" <> polygon_label(a) <> ", " <> polygon_label(b) <> ")"
      abstract_union.LoopPieceB(a, b) ->
        "LoopPieceB(" <> polygon_label(a) <> ", " <> polygon_label(b) <> ")"
      abstract_union.HullLineAB(a, b) ->
        "HullLineAB(" <> polygon_label(a) <> ", " <> polygon_label(b) <> ")"
      abstract_union.HullLineBA(a, b) ->
        "HullLineBA(" <> polygon_label(a) <> ", " <> polygon_label(b) <> ")"
    }
  })
  |> string.join("\n")
}

fn describe_segment_pieces(
  pieces: List(
    abstract_union.UnionPiece(segment_hull_loop.Param, segment_hull_loop.Param),
  ),
) -> String {
  pieces
  |> list.map(fn(piece) {
    case piece {
      abstract_union.LoopPieceA(a, b) ->
        "LoopPieceA(" <> segment_label(a) <> ", " <> segment_label(b) <> ")"
      abstract_union.LoopPieceB(a, b) ->
        "LoopPieceB(" <> segment_label(a) <> ", " <> segment_label(b) <> ")"
      abstract_union.HullLineAB(a, b) ->
        "HullLineAB(" <> segment_label(a) <> ", " <> segment_label(b) <> ")"
      abstract_union.HullLineBA(a, b) ->
        "HullLineBA(" <> segment_label(a) <> ", " <> segment_label(b) <> ")"
    }
  })
  |> string.join("\n")
}

fn polygon_label(param: polygon_loop.Param) -> String {
  let polygon_loop.Vertex(index) = param
  "v" <> int_to_string(index)
}

fn segment_label(param: segment_hull_loop.Param) -> String {
  "piece "
  <> int_to_string(param.segment_index)
  <> "@"
  <> float.to_string(param.t)
}

fn int_to_string(index: Int) -> String {
  int.to_string(index)
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
