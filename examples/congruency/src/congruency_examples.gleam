import gleam/io
import svg_path
import svg_path/congruency
import svg_path/transform

const tolerance = 0.000001

pub fn main() -> Nil {
  io.println("semantic mismatch rejected: " <> bool_text(semantic_mismatch()))
  io.println(
    "transformed subpath recognized: " <> bool_text(transformed_subpath()),
  )
  io.println(
    "closed loop start order rejected: " <> bool_text(closed_loop_start_order()),
  )
}

fn semantic_mismatch() -> Bool {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  congruency.segment(source: line, target: curve, tolerance:) == Error(Nil)
}

fn transformed_subpath() -> Bool {
  let source =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(10.0, 0.0),
        control1: svg_path.point(14.0, 6.0),
        control2: svg_path.point(18.0, -6.0),
        end: svg_path.point(22.0, 0.0),
      ),
    ])
  let matrix =
    transform.translate(x: 12.0, y: -4.0)
    |> transform.chain(first: transform.rotate(degrees: 35.0), then: _)
    |> transform.chain(first: transform.scale(factor: 1.8), then: _)
  let assert Ok(target) = transform.subpath(source, by: matrix)

  case congruency.subpath(source:, target:, tolerance:) {
    Ok(found) -> {
      let assert Ok(mapped) = transform.subpath(source, by: found)
      mapped == target
    }
    Error(_) -> False
  }
}

fn closed_loop_start_order() -> Bool {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(15.0, 7.0)
  let d = svg_path.point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let source = closed_subpath([ab, bc, cd, da])
  let target = closed_subpath([bc, cd, da, ab])

  congruency.subpath(source:, target:, tolerance:) == Error(Nil)
}

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  let assert Ok(subpath) =
    svg_path.subpath(segments)
    |> result_try_set_closed

  subpath
}

fn result_try_set_closed(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result {
    Ok(subpath) -> svg_path.set_closed(subpath, closed: True)
    Error(error) -> Error(error)
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "yes"
    False -> "no"
  }
}
