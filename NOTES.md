# Notes

## Test Speed

`gleeunit.main()` discovers every public function ending in `_test` under
`test/`, so running one test module through Gleam does not restrict discovery
to that module.

Use these local helpers when iterating:

```sh
scripts/test-fast
scripts/test-all
```

`scripts/test-fast` temporarily moves `test/svg_path_convex_hull_test.gleam`
out of `test/`, runs `gleam test`, and restores the file before exiting.

`scripts/test-all` restores `test/svg_path_convex_hull_test.gleam` if needed
and runs the full `gleam test` suite.
