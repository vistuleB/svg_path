import svg_path
import svg_path/svg

pub fn document_renders_a_complete_svg_document_test() {
  let path =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(1.0, 2.0),
          end: svg_path.point(11.0, 2.0),
        ),
      ]),
    ])
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(0.0, -5.0),
      max: svg_path.point(20.0, 15.0),
    )

  assert svg.document(
      [
        svg.StyledPath(path, "fill: none; stroke: red; stroke-width: 0.25"),
        svg.Text(
          "start",
          "fill: black; font-family: sans-serif",
          svg_path.point(1.0, 2.0),
          4,
        ),
      ],
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 -5 20 20\">\n"
    <> "  <path d=\"M 1 2 H 11\" style=\"fill: none; stroke: red; stroke-width: 0.25\" />\n"
    <> "  <text x=\"1\" y=\"2\" font-size=\"4\" style=\"fill: black; font-family: sans-serif\">start</text>\n"
    <> "</svg>"
}

pub fn paths_delegates_to_document_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(1.0, 1.0),
    )
  let things = [svg.StyledPath(svg_path.empty_path(), "fill: none")]

  assert svg.paths(things, view_box: box) == svg.document(things, view_box: box)
}

pub fn paths_escapes_path_style_and_text_values_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(1.0, 1.0),
    )

  assert svg.paths(
      [
        svg.StyledPath(
          svg_path.empty_path(),
          "stroke: \"red\"; marker: url(a&b<c>d)",
        ),
        svg.Text(
          "\"a\" & <b>",
          "font-family: \"serif\"; fill: a&b<c>d",
          svg_path.point(0.5, 1.0),
          12,
        ),
      ],
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1 1\">\n"
    <> "  <path d=\"\" style=\"stroke: &quot;red&quot;; marker: url(a&amp;b&lt;c&gt;d)\" />\n"
    <> "  <text x=\"0.5\" y=\"1\" font-size=\"12\" style=\"font-family: &quot;serif&quot;; fill: a&amp;b&lt;c&gt;d\">\"a\" &amp; &lt;b&gt;</text>\n"
    <> "</svg>"
}

pub fn labeled_point_draws_marker_and_label_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(20.0, 20.0),
    )

  assert svg.paths(
      svg.labeled_point("p0", "red", svg_path.point(10.0, 10.0), 4),
      view_box: box,
    )
    == "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 20 20\">\n"
    <> "  <path d=\"M 8 8 H 12 V 12 H 8 Z M 8 8 L 12 12 M 8 12 L 12 8\" style=\"fill: none; stroke: red; stroke-width: 1; stroke-linecap: square; stroke-linejoin: miter\" />\n"
    <> "  <text x=\"14\" y=\"12\" font-size=\"4\" style=\"fill: red; font-family: system-ui, sans-serif\">p0</text>\n"
    <> "</svg>"
}
