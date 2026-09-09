# Recursive-dash culling investigation

`recursive-dash-source.term` preserves the exact source and public stroke-call
arguments captured from the recursive-dashes fixture. It does not require the
original first-level stroke to be reconstructed for isolated work.

After an Erlang build, run from the repository root:

```sh
escript examples/debug/recursive_dash_isolated.escript current
escript examples/debug/recursive_dash_isolated.escript before-caps
escript examples/debug/recursive_dash_isolated.escript culling
```

These call the production pipeline and capture private function boundaries;
only display translation/scaling is implemented in the script. `current`
also regenerates the complete recursive-dashes picture through its fixture.
The saved `*-isolated-final.svg`, `*-band-wrapper.svg`, and
`*-highlighted-owner.svg` pictures record the original two-arc artifact.
The `*-current.svg` pictures show the corrected result. Earlier capture terms
and pictures remain useful historical comparison data.

The culler previously excluded an intersection close to either shared endpoint.
It now excludes it only when close to both, matching the AG. The short reversed
join and following line are shortened; the extra retraced two-arc contour no
longer appears in the final stroke.

`recursive_dash_owner.escript` locates the saved source dash in a fresh fixture
run and highlights its current stroke. Its circle marks the historical artifact
location, whether or not that artifact survives current logic.

The independent solver endpoint-omission question is recorded separately in
`JOIN_LINE_MISSING_ENDPOINT.md` and has not been fixed.
