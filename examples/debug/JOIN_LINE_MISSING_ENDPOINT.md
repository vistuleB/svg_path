# Join/line shared endpoint omitted by intersection solver

Captured from the isolated recursive-dash stroke, outer offset +3, before caps.
The exact source segments and intersection options are in
`join_line_missing_endpoint.term`. This fixture does not need gallery generation.

Run from the repository root after an Erlang build:

```sh
escript examples/debug/join_line_missing_endpoint.escript
```

`intersections.segment_with` currently returns one intersection:

- Join parameter: `0.999895513484253`
- Line parameter: `7.905709238521863e-7`
- Point: `(430.6702027471619, 178.6947740775757)`

The join's end and line's start are exactly the same stored point:
`(430.670203101245, 178.69477431938788)`. Thus `(1, 0)` is also an exact
intersection, but is absent from the result. The two reported/geometric
locations are approximately `4.29e-7` apart, versus a `1e-9` intersection
tolerance. Investigate candidate collection, endpoint preference, and
deduplication before deciding on a fix; no cause has yet been established.

This is saved diagnostic geometry, not an approved expected-result test.
No solver changes were made when saving it.
