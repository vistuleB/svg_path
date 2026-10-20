import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/offset

pub fn main() {
  list.each([False, True], fn(reversed) {
    let #(start, end, sweep, sign) = case reversed {
      False -> #(Point(230.0, 0.0), Point(320.0, 0.0), True, -1.0)
      True -> #(Point(320.0, 0.0), Point(230.0, 0.0), False, 1.0)
    }
    let arc = Arc(start, Point(45.0, 45.0), 0.0, False, sweep, end)
    list.each([44.999, 45.0, 45.001], fn(distance) {
      let result = offset.segment(arc, sign *. distance, offset.Round)
      echo #(reversed, distance, case result {
        Ok(_) -> Ok(Nil)
        Error(error) -> Error(error)
      })
    })
  })
  let assert Ok(source) =
    svg_path.subpath([
      Arc(
        Point(100.0, 100.0),
        Point(13.975424859373685, 13.975424859373685),
        0.0,
        False,
        False,
        Point(80.0, 90.0),
      ),
      Arc(
        Point(80.0, 90.0),
        Point(120.28207587906756, 120.28207587906756),
        0.0,
        False,
        True,
        Point(210.0, 0.0),
      ),
      Line(Point(210.0, 0.0), Point(230.0, 0.0)),
      Arc(
        Point(230.0, 0.0),
        Point(45.0, 45.0),
        0.0,
        False,
        True,
        Point(320.0, 0.0),
      ),
      Arc(
        Point(320.0, 0.0),
        Point(25.0, 25.0),
        0.0,
        False,
        False,
        Point(280.0, 0.0),
      ),
      Arc(
        Point(280.0, 0.0),
        Point(148.1658698891212, 148.1658698891212),
        0.0,
        False,
        True,
        Point(390.0, 210.0),
      ),
      Line(Point(390.0, 210.0), Point(280.0, 120.0)),
    ])
  echo #("CC01475", offset.subpath(source, -45.0, offset.Round, offset.Butt))

  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(280.0, 120.0), Point(390.0, 210.0)),
      Arc(
        Point(390.0, 210.0),
        Point(148.1658698891212, 148.1658698891212),
        0.0,
        False,
        False,
        Point(280.0, 0.0),
      ),
      Arc(
        Point(280.0, 0.0),
        Point(25.0, 25.0),
        0.0,
        False,
        True,
        Point(320.0, 0.0),
      ),
      Arc(
        Point(320.0, 0.0),
        Point(45.0, 45.0),
        0.0,
        False,
        False,
        Point(230.0, 0.0),
      ),
      Line(Point(230.0, 0.0), Point(210.0, 0.0)),
      Arc(
        Point(210.0, 0.0),
        Point(120.28207587906756, 120.28207587906756),
        0.0,
        False,
        False,
        Point(80.0, 90.0),
      ),
      Arc(
        Point(80.0, 90.0),
        Point(13.975424859373685, 13.975424859373685),
        0.0,
        False,
        True,
        Point(100.0, 100.0),
      ),
    ])
  echo #("CC01479", offset.subpath(source, 45.0, offset.Round, offset.Butt))
}
