# Explicit assertion/adaptation gaps

These are unimplemented comparisons or API scope differences, not confirmed failures. Each entry lists upstream filenames and test names; helper-call matches do not close these gaps.

## G01 — Boolean boundary topology

Status: `deferred-adaptation`. Area and a 13×13 grid do not validate every boundary, vertex/face count, edge ordering or zero-area contact.

- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, intersect
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, disjoint
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, 1 in 2
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, 2 in 1
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, 2 in 1 touching from inside, overlapping same
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons, 2 in 1 touching from outside, overlapping opposite
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons form cross-shape
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 disjoint polygons
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 1st polygon with one round hole, 2nd polygon partially intersect hole 
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 1st polygon with one round hole, 2nd polygon fully cover hole 
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. 2 polygons create one triangular hole after unify
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #53
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 0
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Not fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 1
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Fixed: Infinity Loop When unifying polygon Issue #82
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Fixed: Infinite Loop when calling unify on polygons #94
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Fixed: Infinite Loop when calling unify for multipolygon with touching faces #171
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Fixed: Infinite Loop when calling unify for multipolygon with touching faces #171: case 2 - self-touching face
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. 2 intersecting polygons
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. 1-face polygon split with 2nd to 2-faced polygon and vice a verse
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. 2 intersecting polygons produce 2-island result
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform (boolean) subtraction. First polygon inside the second
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract big polygon from smaller polygon and get empty result (Issue #4)
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can subtract one polygon from another and create a hole (Issue #7)
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Issue #55 case 0
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Issue #55 case 1
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Fixed: Infinite loop when subtracting polygons (v1.2.20) Issue #81
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed issue #76
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform (boolean) intersection. 2 intersecting polygons
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform (boolean) intersection. Other 2 intersecting polygons
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform (boolean) intersection. First polygon inside the second
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection issue #42 Intersect does not seem to work when a second is inside first
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Fixed: Issue #8
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Subtract bug from flatten-js/core 1.2 onwards #15
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform subtract without creating a degenerate sliver for partially overlapped polygon (#243)
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersection. Fixed: Issue #55 case 0
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersection. Fixed: Issue #55 case 1
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Fixed: Infinite Loop when intersecting Polygons (v1.3.4) #139
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Infinite Loop when intersecting Polygons (v1.3.4) #139 case 2
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations Boolean operations with empty polygon Can operate with empty polygon

## G02 — Polygon cutting and clip output lists

Status: `deferred-adaptation`. Cut/multiline partition outputs, innerClip/outerClip pieces and paired intersection ordering require dedicated geometry adapters; helper queries are not those assertions.

- `test/classes/polygon.js` — #Flatten.Polygon Can cut polygon with holes by line. Case 1. Line cuts edge not in vertex
- `test/classes/polygon.js` — #Flatten.Polygon Can cut polygon with holes by line. Case 2. Line is touching hole in vertex
- `test/classes/polygon.js` — #Flatten.Polygon Can cut polygon without holes by line. Line is touching concave vertex
- `test/classes/polygon.js` — #Flatten.Polygon Can cut polygon with MultiLine #159
- `test/classes/polygon.js` — #Flatten.Polygon Polygon.cut error #175
- `test/classes/polygon.js` — #Flatten.Polygon Polygon cut error #176
- `test/classes/polygon.js` — #Flatten.Polygon Self-intersecting output when cutting a multipolygon with a multiline #205
- `test/classes/polygon.js` — #Flatten.Polygon #Flatten.Polygon.cut(multiline) methods Can cut polygon with line. Case of non-intersection
- `test/classes/polygon.js` — #Flatten.Polygon #Flatten.Polygon.cut(multiline) methods Can cut polygon with multiline line. Case of touching in one point
- `test/classes/polygon.js` — #Flatten.Polygon #Flatten.Polygon.cut(multiline) methods Can cut polygon with line into 2 polygons
- `test/classes/polygon.js` — #Flatten.Polygon #Flatten.Polygon.cut(multiline) methods Can cut polygon with line into 3 polygons
- `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations Boolean operations with empty polygon Can operate with empty polygon

## G03 — Island extraction

Status: `deferred-adaptation`. Compare semantic grouping with csg.nested_contours, including the empty case; upstream island ordering and edge count need an explicit mapping.

- `test/classes/polygon.js` — #Flatten.Polygon Can split polygon into islands (issue #9 in @flatten-js/boolean-op)
- `test/classes/polygon.js` — #Flatten.Polygon splitToIslands should not fail if the polygon is empty

## G04 — Point-based chain splitting

Status: `deferred-adaptation`. Upstream vertex insertion and splitting take points and mutate edge lists; possible geometric adaptation through projection plus parameter splitting remains unimplemented.

- `test/classes/multiline.js` — #Flatten.Multiline May add vertex to polyline
- `test/classes/multiline.js` — #Flatten.Multiline May split polyline with intersections
- `test/classes/multiline.js` — #Flatten.Multiline May split polyline with array of points
- `test/classes/polygon.js` — #Flatten.Polygon Can add new vertex to face and split edge of polygon (segment)
- `test/classes/polygon.js` — #Flatten.Polygon Can add new vertex to face and split edge of polygon (arc)

## G05 — Distance witnesses

Status: `deferred-assertion`. Distance adapters compare scalar distance, not every witness coordinate, direction or choice among tied minima. Named tests may contain scalar-only assertions as well.

- `test/classes/arc.js` — #Flatten.Arc #Flatten.Arc.distanceTo distance to point on arc
- `test/classes/arc.js` — #Flatten.Arc #Flatten.Arc.distanceTo distance to point outside arc
- `test/classes/arc.js` — #Flatten.Arc #Flatten.Arc.distanceTo distance to point inside arc
- `test/classes/arc.js` — #Flatten.Arc #Flatten.Arc.distanceTo distance to point inside 3rd quadrant of the arc
- `test/classes/arc.js` — #Flatten.Arc #Flatten.Arc.distanceTo distance to box
- `test/classes/box.js` — #Flatten.Box Can measure distance to box
- `test/classes/box.js` — #Flatten.Box distanceTo(Box) (issue #210) returns zero for boxes with intersecting boundaries
- `test/classes/box.js` — #Flatten.Box distanceTo(Box) (issue #210) returns the boundary gap for disjoint boxes
- `test/classes/box.js` — #Flatten.Box distanceTo(Box) (issue #210) returns a shortest segment from the calling box to the other box
- `test/classes/box.js` — #Flatten.Box distanceTo(Box) (issue #210) supports Segment.distanceTo(Box)
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and point
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and circle
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and line
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and segment
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and arc
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and polygon
- `test/classes/circle.js` — #Flatten.Circle #Flatten.Circle.DistanceTo Can measure distance between circle and box
- `test/classes/line.js` — #Flatten.Line Can measure distance from line to box
- `test/classes/multiline.js` — #Flatten.Multiline May calculate distance between a point and a multiline
- `test/classes/multiline.js` — #Flatten.Multiline Can measure distance between multiline and box
- `test/classes/multiline.js` — #Flatten.Multiline Can measure distance between multiline and point
- `test/classes/point.js` — #Flatten.Point Can measure distance from point to box
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo return distance to other point 
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo calculates distance to given line
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo returns distance to segment
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo returns distance to circle
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo returns distance to arc
- `test/classes/point.js` — #Flatten.Point #Flatten.Point.Distance methods Method distanceTo returns distance to polygon
- `test/classes/polygon.js` — #Flatten.Polygon Can measure distance between circle and polygon
- `test/classes/polygon.js` — #Flatten.Polygon Can measure distance between two polygons
- `test/classes/polygon.js` — #Flatten.Polygon distanceTo between Polygons: First point of segment is not always on the this polygon #57
- `test/classes/polygon.js` — #Flatten.Polygon Can measure distance between polygon and box
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Segment Case 1 Intersected Segments
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Segment Case 2 Not Intersected Segments
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Line
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - touching
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - two points
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - one points
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 2 Projection
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 3 End point out of the circle
- `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 3 End point inside the circle
- `test/data_structures/planar_set.js` — #Data_structures.PlanarSet May calculate distance between shape and planar set

## G06 — Path-string outputs

Status: `deferred-adaptation`. Nonempty path-data/SVG strings need a parse/geometry round-trip adapter; element styling itself remains outside scope.

- `test/classes/face.js` — #Flatten.Face Method svg can return string to be used to generate svg path
- `test/classes/multiline.js` — #Flatten.Multiline May create svg path
- `test/classes/multiline.js` — #Flatten.Multiline May create dpath string to be inserted into "d" atrtibute
- `test/classes/multiline.js` — #Flatten.Multiline May create points string to be inserted into "points" atrtibute
- `test/classes/polygon.js` — #Flatten.Polygon #SVG output Can create path element
- `test/classes/polygon.js` — #Flatten.Polygon #SVG output Can create dpath string

## G07 — Whole-shape relations and validity

Status: `scope-or-api-idea`. No direct DE-9IM/whole-shape containment or polygon-validity Boolean API. Do not infer these predicates solely from sampled points or empty boundary intersections.

- `test/algorithms/relation.js` — #Algorithms.Relation Function relate defined
- `test/algorithms/relation.js` — #Algorithms.Relation Namespace Relations exist on Flatten
- `test/algorithms/relation.js` — #Algorithms.Relation Relations may be consumed from Flatten.Relations namespace
- `test/algorithms/relation.js` — #Algorithms.Relation Functions disjoint,equals,intersects,touches exist
- `test/algorithms/relation.js` — #Algorithms.Relation v1.4 Relations.intersect() doesnt allow Polygon argument #149
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Line Parallel case (disjoint)
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Line Equal case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Line Intersection case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Circle Disjoint case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Circle Touching case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Circle Intersection case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Box Intersection case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Polygon Disjoint case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Polygon Touching case - touch in one point
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Polygon Intersection case - 2 intersection point
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Polygon Can properly detect contains / covered relation. Issue #65
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Line2Polygon Can properly detect touch relation. Issue #65
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Circle2Circle Intersection case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Circle2Circle Disjoint case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Circle2Circle Touching case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Circle2Circle Contain case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Circle2Circle Inside case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon May calculate relations. Disjoint case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon May calculate relations. Touching from outside case
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon May calculate relations. Case of inclusion
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon May calculate relations. Case of covered
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon May calculate relations. Case of intersected polygons
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon Infinite loop error in Relations.relate()  issue #63
- `test/algorithms/relation.js` — #Algorithms.Relation #Algorithms.Relation.Polygon2Polygon Calculate contains relation for multipolygon. Issue #81
- `test/classes/polygon.js` — #Flatten.Polygon Can check if contour contains segment (issue #31)
- `test/classes/polygon.js` — #Flatten.Polygon Can calculate inclusion flag of the edge
- `test/classes/polygon.js` — #Flatten.Polygon Can check if polygon is valid
- `test/classes/polygon.js` — #Flatten.Polygon Can check if polygon is invalid if one of faces is not simple
