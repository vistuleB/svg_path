//// Shared split-parameter normalization. Exact duplicate and endpoint rules.

import gleam/list
import svg_path/internal/number

@internal
pub fn normalize_splits(points: List(Float)) -> List(Float) {
  points
  |> list.map(number.normalize_zero)
  |> sort_unique_progresses
  |> trim_start_progress
  |> trim_end_progress
}

fn sort_unique_progresses(points: List(Float)) -> List(Float) {
  case points {
    [] -> []
    [first, ..rest] ->
      sort_unique_progresses(rest) |> insert_unique_progress(first)
  }
}

fn trim_start_progress(points: List(Float)) -> List(Float) {
  case points {
    [0.0, ..rest] -> trim_start_progress(rest)
    _ -> points
  }
}

fn trim_end_progress(points: List(Float)) -> List(Float) {
  points
  |> list.reverse
  |> trim_reversed_end_progress
  |> list.reverse
}

fn trim_reversed_end_progress(points: List(Float)) -> List(Float) {
  case points {
    [1.0, ..rest] -> trim_reversed_end_progress(rest)
    _ -> points
  }
}

fn insert_unique_progress(sorted: List(Float), point: Float) -> List(Float) {
  case sorted {
    [] -> [point]
    [first, ..rest] -> {
      case point == first {
        True -> sorted
        False -> {
          case point <=. first {
            True -> [point, ..sorted]
            False -> [first, ..insert_unique_progress(rest, point)]
          }
        }
      }
    }
  }
}
