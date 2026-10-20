import svg_path/ellipse

pub fn main() {
  echo ellipse.endpoint_to_center(ellipse.EndpointArcData(
    ellipse.EllipsePoint(-193.78556423268984, -666.4658569031494),
    ellipse.EllipsePoint(1000.0, 500.0),
    37.0,
    False,
    True,
    ellipse.EllipsePoint(193.78556423268984, 666.4658569031494),
  ))
  echo ellipse.endpoint_to_center(ellipse.EndpointArcData(
    ellipse.EllipsePoint(1427.399189714887, -1017.6508339851933),
    ellipse.EllipsePoint(1000.0, 2000.0),
    73.0,
    False,
    True,
    ellipse.EllipsePoint(-1427.399189714887, 1017.6508339851933),
  ))
}
