import gleam/list
import svg_path

fn line(a: Float, b: Float) -> svg_path.Segment {
  svg_path.Line(svg_path.Point(a, 0.0), svg_path.Point(b, 0.0))
}

pub fn endpoint_context_two_segments_first_and_last_test() {
  let segments = [line(0.0, 1.0), line(1.0, 2.0)]
  let assert Ok(path) =
    svg_path.subpath_with(
      segments,
      policy: svg_path.Custom(fn(previous, next, context) {
        assert context == svg_path.EndpointPolicyContext(True, True, False)
        [previous, next]
      }),
    )
  assert svg_path.subpath_segments(path) == segments
}

pub fn endpoint_context_tracks_input_when_replacements_expand_test() {
  let segments = [
    line(0.0, 1.0),
    line(1.0, 2.0),
    line(2.0, 3.0),
    line(3.0, 4.0),
  ]
  let assert Ok(path) =
    svg_path.subpath_with(
      segments,
      policy: svg_path.Custom(fn(previous, next, context) {
        let x = svg_path.segment_start(next).x
        assert context
          == svg_path.EndpointPolicyContext(x == 1.0, x == 3.0, False)
        [previous, line(x, x), next]
      }),
    )
  assert list.length(svg_path.subpath_segments(path)) == 7
}

pub fn endpoint_context_first_does_not_repeat_after_pair_deletion_test() {
  let segments = [
    line(0.0, 1.0),
    line(1.0, 2.0),
    line(2.0, 3.0),
    line(3.0, 4.0),
  ]
  let assert Ok(path) =
    svg_path.subpath_with(
      segments,
      policy: svg_path.Custom(fn(previous, next, context) {
        case svg_path.segment_start(next).x == 1.0 {
          True -> {
            assert context == svg_path.EndpointPolicyContext(True, False, False)
            []
          }
          False -> {
            assert context == svg_path.EndpointPolicyContext(False, True, False)
            [previous, next]
          }
        }
      }),
    )
  assert svg_path.subpath_segments(path) == [line(2.0, 3.0), line(3.0, 4.0)]
}

pub fn endpoint_context_coalescing_keeps_last_flag_test() {
  let segments = [line(0.0, 1.0), line(1.0, 2.0), line(2.0, 3.0)]
  let assert Ok(path) =
    svg_path.subpath_with(
      segments,
      policy: svg_path.Custom(fn(previous, next, context) {
        let last = svg_path.segment_end(next).x == 3.0
        assert context == svg_path.EndpointPolicyContext(!last, last, False)
        [
          svg_path.Line(
            svg_path.segment_start(previous),
            svg_path.segment_end(next),
          ),
        ]
      }),
    )
  assert svg_path.subpath_segments(path) == [line(0.0, 3.0)]
}

pub fn set_closed_reapplies_policy_only_at_closing_boundary_test() {
  let assert Ok(closed) =
    svg_path.subpath_close(
      svg_path.subpath_assert([line(0.0, 1.0), line(1.0, 0.0)]),
    )
  let assert Ok(reclosed) =
    svg_path.subpath_close_with(
      closed,
      policy: svg_path.Custom(fn(previous, next, context) {
        assert context == svg_path.EndpointPolicyContext(False, False, True)
        assert previous == line(1.0, 0.0)
        assert next == line(0.0, 1.0)
        [line(1.0, 0.5), line(0.5, 0.0)]
      }),
    )
  assert svg_path.subpath_is_closed(reclosed)
  assert svg_path.subpath_segments(reclosed)
    == [line(0.0, 1.0), line(1.0, 0.5), line(0.5, 0.0)]
}

pub fn closed_singleton_rebuild_calls_policy_once_test() {
  let only = line(0.0, 0.0)
  let assert Ok(closed) =
    svg_path.subpath_close(svg_path.subpath_assert([only]))
  let assert Ok(rebuilt) =
    svg_path.subpath_rebuild_with(
      closed,
      policy: svg_path.Custom(fn(previous, next, context) {
        assert previous == only
        assert next == only
        assert context == svg_path.EndpointPolicyContext(False, False, True)
        [line(0.0, 1.0), line(1.0, 0.0)]
      }),
    )
  assert svg_path.subpath_is_closed(rebuilt)
  assert svg_path.subpath_segments(rebuilt) == [line(0.0, 1.0), line(1.0, 0.0)]
}

pub fn empty_closure_and_rebuild_do_not_call_policy_test() {
  let empty = svg_path.subpath_empty(at: svg_path.Point(3.0, 4.0))
  let policy =
    svg_path.Custom(fn(_, _, _) { panic as "empty subpath has no pair" })
  let assert Ok(closed) = svg_path.subpath_close_with(empty, policy:)
  let assert Ok(reclosed) = svg_path.subpath_close_with(closed, policy:)
  let assert Ok(rebuilt) = svg_path.subpath_rebuild_with(closed, policy:)
  assert svg_path.subpath_is_closed(closed)
  assert svg_path.subpath_is_empty(closed)
  assert svg_path.subpath_start(closed) == svg_path.subpath_start(empty)
  assert reclosed == closed
  assert rebuilt == closed
}

pub fn open_singleton_rebuild_does_not_call_policy_test() {
  let only = svg_path.subpath_assert([line(0.0, 1.0)])
  let assert Ok(rebuilt) =
    svg_path.subpath_rebuild_with(
      only,
      policy: svg_path.Custom(fn(_, _, _) {
        panic as "singleton has no forward pair"
      }),
    )
  assert rebuilt == only
}

pub fn closed_rebuild_distinguishes_last_forward_pair_from_closure_test() {
  let segments = [line(0.0, 1.0), line(1.0, 0.0)]
  let assert Ok(closed) =
    svg_path.subpath_close(svg_path.subpath_assert(segments))
  let assert Ok(rebuilt) =
    svg_path.subpath_rebuild_with(
      closed,
      policy: svg_path.Custom(fn(previous, next, context) {
        case svg_path.segment_start(previous).x == 0.0 {
          True -> {
            assert context == svg_path.EndpointPolicyContext(True, True, False)
            [previous, next]
          }
          False -> {
            assert context == svg_path.EndpointPolicyContext(False, False, True)
            [previous]
          }
        }
      }),
    )
  assert rebuilt == closed
}
