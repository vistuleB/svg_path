# New Hull Experiment Gleam Sources

These files were moved out of `src/` when the production convex hull API was
pared down. They are reference material for the old analytical and trace-heavy
hull experiments, not package modules.

Some code here may refer to older public APIs such as `convex_hull.HullPiece`.
That is intentional: the folder preserves the intellectual scaffolding for a
possible future `hull_trace_` design without exposing those ideas to package
users today.
