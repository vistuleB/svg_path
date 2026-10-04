//// Bounding boxes and conservative bounding polygons for path geometry.

import svg_path
import svg_path/internal/query

/// Return the width of a bounding box.
pub fn bounding_box_width(box: svg_path.BoundingBox) -> Float {
  svg_path.bounding_box_width(box)
}

/// Return the height of a bounding box.
pub fn bounding_box_height(box: svg_path.BoundingBox) -> Float {
  svg_path.bounding_box_height(box)
}

/// Return the center point of a bounding box.
pub fn bounding_box_center(box: svg_path.BoundingBox) -> svg_path.Point {
  query.bounding_box_center(box)
}

/// Return the taxicab diameter of a bounding box.
///
/// This is the box width plus the box height.
pub fn bounding_box_taxicab_diameter(box: svg_path.BoundingBox) -> Float {
  svg_path.bounding_box_taxicab_diameter(box)
}

/// Return the smallest axis-aligned bounding box containing both boxes.
pub fn bounding_box_union(
  first: svg_path.BoundingBox,
  second: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.bounding_box_union(first, second)
}

/// Return the smallest axis-aligned bounding box containing every box.
pub fn bounding_box_union_many(
  boxes: List(svg_path.BoundingBox),
) -> Result(svg_path.BoundingBox, Nil) {
  query.bounding_box_union_many(boxes)
}

/// Return the smallest axis-aligned bounding box containing every point.
pub fn points_bounding_box(
  points: List(svg_path.Point),
) -> Result(svg_path.BoundingBox, Nil) {
  query.points_bounding_box(points)
}

/// Return a segment's exact axis-aligned bounding box.
pub fn segment_bounding_box(
  segment: svg_path.Segment,
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  svg_path.segment_bounding_box(segment)
}

/// Return a convex polygon enclosing the segment, in visual clockwise order.
///
/// The first vertex is the segment start when it is a hull vertex; otherwise
/// it is the lexicographically smallest vertex (x, then y). The first vertex
/// is not repeated at the end. Point and line degeneracies return one or two
/// vertices. Beziers use their control-point hull; arcs use tangent triangles
/// spanning at most 90 degrees on the corrected ellipse, then their hull.
/// This is an ordinary floating-point bound, not outward-rounded arithmetic.
/// Arcs rejected by `arc_center_data` return `DegenerateArc`; see that function
/// for endpoint and radius restrictions.
pub fn segment_bounding_polygon(
  segment: svg_path.Segment,
) -> Result(List(svg_path.Point), svg_path.Error) {
  query.segment_bounding_polygon(segment)
}

/// Enclose the segment portion between `from` and `to`, both in `0.0..1.0`.
///
/// Reversed intervals are allowed. The boundary remains visually clockwise;
/// its preferred first vertex is the point at `from`, when that is a hull
/// vertex. Equal parameters return one point. Other conventions are those of
/// `segment_bounding_polygon`. Out-of-range parameters return
/// `SplitOutsideSegment`.
pub fn segment_bounding_polygon_between(
  segment: svg_path.Segment,
  from from: Float,
  to to: Float,
) -> Result(List(svg_path.Point), svg_path.Error) {
  query.segment_bounding_polygon_between(segment, from: from, to: to)
}

/// Return a non-empty subpath's exact axis-aligned bounding box.
pub fn subpath_bounding_box(
  subpath: svg_path.Subpath,
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  svg_path.subpath_bounding_box(subpath)
}

/// Return the exact axis-aligned bounding box of all non-empty subpaths.
pub fn path_bounding_box(
  path: svg_path.Path,
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  svg_path.path_bounding_box(path)
}
