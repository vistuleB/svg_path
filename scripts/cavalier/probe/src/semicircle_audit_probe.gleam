import gleam/io
import gleam/string
import svg_path.{Arc, Point}

pub fn main() {
  io.println("CX00420")
  io.println(
    string.inspect(
      svg_path.arc_center_data(Arc(
        Point(-555.8531980329952, -831.2804714634476),
        Point(1000.0, 1000.0),
        0.0,
        False,
        True,
        Point(555.8531980329952, 831.2804714634476),
      )),
    ),
  )
  io.println("CX00622")
  io.println(
    string.inspect(
      svg_path.arc_center_data(Arc(
        Point(10_529.317836279792, -19_151.576386351677),
        Point(999.9999999999999, 999.9999999999999),
        0.0,
        False,
        False,
        Point(9470.682163720208, -20_848.423613648323),
      )),
    ),
  )
  io.println("CX00636")
  io.println(
    string.inspect(
      svg_path.arc_center_data(Arc(
        Point(10_529.317836279792, -19_151.576386351677),
        Point(999.9999999999999, 999.9999999999999),
        0.0,
        False,
        True,
        Point(9470.682163720208, -20_848.423613648323),
      )),
    ),
  )
}
