# Debug Drawings

Generated SVG debug drawings live here.

- `debug_drawing.*`: leaf/stem renderer smoke test
- `convex_hull_stem.*`: convex hull overlay for the first cubic stem segment
- `convex_hull_horseshoe.*`: convex hull overlay for the horseshoe cubic segment
- `convex_hull_horseshoe_wide.*`: convex hull overlay for a wider horseshoe cubic segment
- `convex_hull_diagonal_line.*`: convex hull overlay for a diagonal line segment
- `convex_hull_reverse_diagonal_line.*`: convex hull overlay for an opposite-slope diagonal line segment
- `convex_hull_horizontal_line.*`: convex hull overlay for a horizontal line segment
- `convex_hull_vertical_line.*`: convex hull overlay for a vertical line segment
- `convex_hull_snake_cubic.*`: convex hull overlay for a crossing snake-shaped cubic
- `convex_hull_fish_cubic.*`: convex hull overlay for a crossing fish-shaped cubic
- `convex_hull_del_cubic.*`: convex hull overlay for the del cubic
- `convex_hull_flourish_cubic.*`: convex hull overlay for the flourish cubic
- `convex_hull_left_hook_cubic.*`: convex hull overlay for the left-hook cubic
- `convex_hull_half_circle_arc_reverse.*`: convex hull overlay for a reverse-sweep half-circle arc
- `convex_hull_rotated_arc_reverse.*`: convex hull overlay for a reverse-sweep rotated arc

The convex hull segment drawings are generated from
`src/svg_path_convex_hull_debug.gleam`. Toggle `selected_segment` in that file
while experimenting.
