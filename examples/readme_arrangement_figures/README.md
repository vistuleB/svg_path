# README ArrangementGraph Figures

This example regenerates the ArrangementGraph and CSG illustrations used by
the README. Graph construction and graph-side rendering go through the public
`svg_path/arrangement` and `svg_path/arrangement/drawing` APIs.

Run it from this directory:

```sh
gleam run
gleam run -m arrangement_csg_figures
```

Preview output is written to `../../test/generated/readme/`; the CSG module
also writes its twelve Gallery panels to `../../test/generated/gallery/`.
Normally run `../../scripts/generate-published-figures` from the repository
root to regenerate the complete README and Gallery figure set, validate all
expected outputs, and promote the Gallery copies to `../../docs/gallery/`.
