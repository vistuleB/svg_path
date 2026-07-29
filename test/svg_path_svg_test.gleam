import svg_path
import svg_path/svg

pub fn document_renders_a_complete_svg_document_test() {
  let path =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(1.0, 2.0),
          end: svg_path.Point(11.0, 2.0),
        ),
      ]),
    ])
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, -5.0),
      max: svg_path.Point(20.0, 15.0),
    )

  assert svg.document(
      [
        svg.StyledPath(path, "fill: none; stroke: red; stroke-width: 0.25"),
        svg.Text(
          "start",
          "fill: black; font-family: sans-serif",
          svg_path.Point(1.0, 2.0),
          4,
        ),
      ],
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 -5 20 20\" width=\"20\" height=\"20\">\n"
    <> "  <path d=\"M 1 2 H 11\" style=\"fill: none; stroke: red; stroke-width: 0.25\" />\n"
    <> "  <text x=\"1\" y=\"2\" font-size=\"4\" style=\"fill: black; font-family: sans-serif\">start</text>\n"
    <> "</svg>"
}

pub fn paths_delegates_to_document_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(1.0, 1.0),
    )
  let things = [svg.StyledPath(svg_path.path_empty(), "fill: none")]

  assert svg.paths(things, view_box: box) == svg.document(things, view_box: box)
}

pub fn document_renders_rectangles_circles_and_ellipses_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(20.0, 20.0),
    )

  assert svg.document(
      [
        svg.Rectangle(
          svg_path.Point(1.0, 2.0),
          10.0,
          5.0,
          "fill: white; stroke: black",
        ),
        svg.Circle(svg_path.Point(8.0, 9.0), 3.0, "fill: red; stroke: none"),
        svg.Ellipse(
          svg_path.Point(12.0, 13.0),
          svg_path.Point(4.0, 2.0),
          "fill: blue; stroke: none",
        ),
      ],
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\" width=\"20\" height=\"20\">\n"
    <> "  <rect x=\"1\" y=\"2\" width=\"10\" height=\"5\" style=\"fill: white; stroke: black\" />\n"
    <> "  <circle cx=\"8\" cy=\"9\" r=\"3\" style=\"fill: red; stroke: none\" />\n"
    <> "  <ellipse cx=\"12\" cy=\"13\" rx=\"4\" ry=\"2\" style=\"fill: blue; stroke: none\" />\n"
    <> "</svg>"
}

pub fn paths_escapes_path_style_and_text_values_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(1.0, 1.0),
    )

  assert svg.paths(
      [
        svg.StyledPath(
          svg_path.path_empty(),
          "stroke: \"red\"; marker: url(a&b<c>d)",
        ),
        svg.Rectangle(
          svg_path.Point(0.0, 0.0),
          1.0,
          1.0,
          "stroke: \"red\"; marker: url(a&b<c>d)",
        ),
        svg.Circle(
          svg_path.Point(0.5, 0.5),
          0.25,
          "stroke: \"red\"; marker: url(a&b<c>d)",
        ),
        svg.Ellipse(
          svg_path.Point(0.5, 0.5),
          svg_path.Point(0.25, 0.125),
          "stroke: \"red\"; marker: url(a&b<c>d)",
        ),
        svg.Text(
          "\"a\" & <b>",
          "font-family: \"serif\"; fill: a&b<c>d",
          svg_path.Point(0.5, 1.0),
          12,
        ),
      ],
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1 1\" width=\"1\" height=\"1\">\n"
    <> "  <path d=\"\" style=\"stroke: &quot;red&quot;; marker: url(a&amp;b&lt;c&gt;d)\" />\n"
    <> "  <rect x=\"0\" y=\"0\" width=\"1\" height=\"1\" style=\"stroke: &quot;red&quot;; marker: url(a&amp;b&lt;c&gt;d)\" />\n"
    <> "  <circle cx=\"0.5\" cy=\"0.5\" r=\"0.25\" style=\"stroke: &quot;red&quot;; marker: url(a&amp;b&lt;c&gt;d)\" />\n"
    <> "  <ellipse cx=\"0.5\" cy=\"0.5\" rx=\"0.25\" ry=\"0.125\" style=\"stroke: &quot;red&quot;; marker: url(a&amp;b&lt;c&gt;d)\" />\n"
    <> "  <text x=\"0.5\" y=\"1\" font-size=\"12\" style=\"font-family: &quot;serif&quot;; fill: a&amp;b&lt;c&gt;d\">\"a\" &amp; &lt;b&gt;</text>\n"
    <> "</svg>"
}

pub fn labeled_point_draws_marker_and_label_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(20.0, 20.0),
    )

  assert svg.paths(
      svg.labeled_point("p0", "red", svg_path.Point(10.0, 10.0), 4),
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\" width=\"20\" height=\"20\">\n"
    <> "  <path d=\"M 8 8 H 12 V 12 H 8 Z M 8 8 L 12 12 M 8 12 L 12 8\" style=\"fill: none; stroke: red; stroke-width: 1; stroke-linecap: square; stroke-linejoin: miter\" />\n"
    <> "  <text x=\"14\" y=\"12\" font-size=\"4\" style=\"fill: red; font-family: system-ui, sans-serif\">p0</text>\n"
    <> "</svg>"
}
