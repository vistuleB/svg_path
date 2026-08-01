# README ArrangementGraph Figures

This example regenerates the ArrangementGraph and CSG illustrations used by
the README. Graph construction and graph-side rendering go through the public
`svg_path/arrangement_graph` and `svg_path/arrangement_graph/drawing` APIs.

Run it from this directory:

```sh
gleam run
gleam run -m arrangement_csg_figures
```

Preview output is written to `../debug/`. After review, follow
`../../COMMIT_CYCLE.md` to promote selected SVGs to the README asset branch.
