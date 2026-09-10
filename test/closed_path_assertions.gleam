import gleam/list
import gleam/string
import svg_path
import svg_path/parse
import svg_path/serialize

// Loop enumeration may rotate a closed walk or reorder independent contours.
// Keep checking every serialized segment, its direction, and multiplicity.
// Reversals, splitting, removed segments and geometry changes are not ignored.
pub fn assert_equivalent(actual: svg_path.Path, expected_data: String) -> Nil {
  let assert Ok(expected) = parse.path(expected_data)
  assert canonical(actual) == canonical(expected)
}

fn canonical(path: svg_path.Path) -> List(String) {
  path
  |> svg_path.path_subpaths
  |> list.map(fn(subpath) {
    assert svg_path.subpath_is_closed(subpath)
    let segments =
      svg_path.subpath_segments(subpath) |> list.map(serialize.segment)
    case segments {
      [] -> ""
      _ -> {
        let rotations =
          segments
          |> list.index_map(fn(_, i) {
            list.append(list.drop(segments, i), list.take(segments, i))
            |> string.join("|")
          })
          |> list.sort(string.compare)
        let assert [first, ..] = rotations
        first
      }
    }
  })
  |> list.sort(string.compare)
}
