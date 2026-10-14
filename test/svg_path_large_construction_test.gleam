import gleam/int
import gleam/list
import svg_path

fn point(i: Int) {
  svg_path.Point(int.to_float(i), 0.0)
}

fn lines(count: Int) {
  list.repeat(Nil, count)
  |> list.index_map(fn(_, i) { svg_path.Line(point(i), point(i + 1)) })
}

fn count(subpath) {
  list.length(svg_path.subpath_segments(subpath))
}

fn check_order(subpath, expected) {
  let actual = svg_path.subpath_segments(subpath)
  assert list.length(actual) == list.length(expected)
  list.each(list.zip(actual, expected), fn(pair) {
    assert pair.0 == pair.1
  })
}

pub fn hundred_thousand_point_polylines_test() {
  let points =
    list.repeat(Nil, 100_000) |> list.index_map(fn(_, i) { point(i) })
  let assert Ok(path) = svg_path.subpath_polyline(points)
  assert count(path) == 99_999
  check_order(path, lines(99_999))
  let assert Ok(repeated) =
    svg_path.subpath_polyline(list.repeat(point(0), 100_000))
  assert count(repeated) == 99_999
  assert svg_path.subpath_start(repeated) == point(0)
  assert svg_path.subpath_end(repeated) == point(0)
}

pub fn long_path_all_endpoint_policies_test() {
  let source = lines(10_000)
  let custom =
    svg_path.Custom(fn(previous, next, context) {
      assert context.first == { svg_path.segment_start(previous) == point(0) }
      assert context.last == { svg_path.segment_end(next) == point(10_000) }
      assert !context.closing
      [previous, next]
    })
  list.each(
    [
      svg_path.Strict,
      svg_path.Bridge,
      svg_path.Wiggle,
      svg_path.WiggleWith(0.01),
      svg_path.WiggleElseBridge,
      svg_path.WiggleElseBridgeWith(0.01),
      custom,
    ],
    fn(policy) {
      let assert Ok(path) = svg_path.subpath_with(source, policy:)
      check_order(path, source)
    },
  )
}

pub fn long_path_late_error_indices_test() {
  let prefix = lines(9999)
  let bad = svg_path.Line(point(-1), point(-2))
  let assert Error(svg_path.Discontinuous(
    previous_index:,
    next_index:,
    expected:,
    got:,
    ..,
  )) = svg_path.subpath(list.append(prefix, [bad]))
  assert previous_index == 9998
  assert next_index == 9999
  assert expected == point(9999)
  assert got == point(-1)
  let policy =
    svg_path.Custom(fn(previous, next, context) {
      case context.last {
        True -> [svg_path.Line(point(-1), svg_path.segment_end(next))]
        False -> [previous, next]
      }
    })
  let assert Error(svg_path.Discontinuous(
    previous_index:,
    next_index:,
    expected:,
    got:,
    ..,
  )) = svg_path.subpath_with(lines(10_000), policy:)
  assert previous_index == 9997
  assert next_index == 9998
  assert expected == point(9998)
  assert got == point(-1)
}

pub fn long_custom_replacements_and_deletions_test() {
  let source =
    list.repeat(Nil, 10_000)
    |> list.index_map(fn(_, i) { svg_path.Line(point(2 * i), point(2 * i + 1)) })
  let policy =
    svg_path.Custom(fn(previous, next, _) {
      [
        previous,
        svg_path.Line(
          svg_path.segment_end(previous),
          svg_path.segment_start(next),
        ),
        next,
      ]
    })
  let assert Ok(path) = svg_path.subpath_with(source, policy:)
  check_order(path, lines(19_999))
  let assert Ok(empty) =
    svg_path.subpath_with(
      lines(10_000),
      policy: svg_path.Custom(fn(_, _, _) { [] }),
    )
  assert count(empty) == 0
  assert svg_path.subpath_start(empty) == point(0)
}

pub fn hundred_thousand_edge_polygon_and_rebuild_test() {
  let points =
    list.repeat(Nil, 100_001) |> list.index_map(fn(_, i) { point(i) })
  let assert Ok(polygon) = svg_path.subpath_polygon(points)
  let expected =
    list.append(lines(100_000), [svg_path.Line(point(100_000), point(0))])
  check_order(polygon, expected)
  assert svg_path.subpath_is_closed(polygon)
  let assert Ok(rebuilt) =
    svg_path.subpath_rebuild_with(
      polygon,
      policy: svg_path.Custom(fn(previous, next, context) {
        case context.closing {
          True -> {
            assert !context.first && !context.last
            assert svg_path.segment_end(previous)
              == svg_path.segment_start(next)
            [previous]
          }
          False -> [previous, next]
        }
      }),
    )
  check_order(rebuilt, expected)
  assert svg_path.subpath_is_closed(rebuilt)
}
