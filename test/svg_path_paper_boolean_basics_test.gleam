// Generated from Paper.js's pinned non-crossing Boolean fixtures.
// Copyright 2011–2020 Jürg Lehni & Jonathan Puckey, MIT.
// See scripts/paperjs/upstream/LICENSE.txt and generate-boolean-basics.py.
import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/containment
import svg_path/csg
import svg_path/parse

fn check(actual: svg_path.Path, expected: svg_path.Path) {
  assert float.absolute_value(
      float.absolute_value(area.signed_path(actual))
      -. float.absolute_value(area.signed_path(expected)),
    )
    <. 0.0000001
  list.each(svg_path.path_subpaths(actual), fn(p) {
    svg_path.subpath_is_closed(p) |> should.be_true
  })
  // One sample in every rectangular cell induced by all input boundaries,
  // including cells outside both shapes. Compare fill, not traversal order.
  list.each(
    [-10.0, 25.0, 75.0, 125.0, 175.0, 225.0, 275.0, 325.0, 375.0],
    fn(x) {
      list.each([-10.0, 25.0, 75.0, 125.0, 175.0, 225.0], fn(y) {
        let p = svg_path.Point(x, y)
        let assert Ok(want) =
          containment.path_containment(p, expected, svg_path.Nonzero)
        let assert Ok(got) =
          containment.path_containment(p, actual, svg_path.Nonzero)
        got |> should.equal(want)
      })
    },
  )
}

pub fn paper_boolean_00_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.union_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M0,200v-200h200v200z")
  check(actual, expected)
}

pub fn paper_boolean_01_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.union_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M0,200v-200h200v200z")
  check(actual, expected)
}

pub fn paper_boolean_02_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM150,150v-100h-100v100z")
  check(actual, expected)
}

pub fn paper_boolean_03_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("")
  check(actual, expected)
}

pub fn paper_boolean_04_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.intersection_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M50,150v-100h100v100z")
  check(actual, expected)
}

pub fn paper_boolean_05_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.intersection_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M50,150v-100h100v100z")
  check(actual, expected)
}

pub fn paper_boolean_06_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) =
    csg.symmetric_difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM150,150v-100h-100v100z")
  check(actual, expected)
}

pub fn paper_boolean_07_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) =
    csg.symmetric_difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM150,150v-100h-100v100z")
  check(actual, expected)
}

pub fn paper_boolean_08_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.union_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM250,150v-100h100v100z")
  check(actual, expected)
}

pub fn paper_boolean_09_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.union_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM250,150v-100h100v100z")
  check(actual, expected)
}

pub fn paper_boolean_10_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M0,200v-200h200v200z")
  check(actual, expected)
}

pub fn paper_boolean_11_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("M350,150v-100h-100v100z")
  check(actual, expected)
}

pub fn paper_boolean_12_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.intersection_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("")
  check(actual, expected)
}

pub fn paper_boolean_13_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) = csg.intersection_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) = parse.path("")
  check(actual, expected)
}

pub fn paper_boolean_14_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) =
    csg.symmetric_difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM250,150v-100h100v100z")
  check(actual, expected)
}

pub fn paper_boolean_15_test() {
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 50.0),
          svg_path.Point(250.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 50.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 150.0),
          svg_path.Point(350.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 0.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(0.0, 200.0),
          svg_path.Point(0.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let assert Ok(actual) =
    csg.symmetric_difference_path(left, right, svg_path.Nonzero)
  let assert Ok(expected) =
    parse.path("M0,200v-200h200v200zM250,150v-100h100v100z")
  check(actual, expected)
}
