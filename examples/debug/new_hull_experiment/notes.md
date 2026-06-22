# New Hull Experiment Notes

This folder is scratch space for experiments that may not compile. Compiling
experiment modules live under `src/new_hull_experiment`.

Initial experiment:

- cubic-only analytic support primitive
- solve `dot(B'(t), direction) = 0`
- compare against the package's generic `segment_minimize` support primitive

Result:

- after fixing the cubic power-basis coefficient, analytic support agrees with
  generic minimization to floating-point noise on the cubic adversarial set
- transformed `endpoint_control_cubic` and `near_cusp_cubic` support values also
  agree, so their hull failures are not explained by support-minimizer jitter

Bitangent scratch:

- a naive Newton/grid solve for interior self-bitangents works on loop-like
  cubics, finding the obvious one-sided chord
- the known hard base cubics are collinear, so the isolated bitangent equations
  become degenerate and produce a continuum of meaningless tangent chords
- this is already a warning that a "proper" root-based algorithm still needs
  explicit degenerate/flat curve classification before solving roots

Collinear cubic branch:

- for collinear cubics, project the curve onto its line and solve the scalar
  cubic derivative
- the hull should be two line pieces between the min/max scalar extrema
- this looks directly relevant to `endpoint_control_cubic_*` and
  `near_cusp_cubic_*`, which are exactly the currently pinned transformed
  failures

Observed results:

- `endpoint_control_cubic`: `HullLine(0, 1)`, `HullLine(1, 0)`
- `near_cusp_cubic`:
  - min at `t = 0.7886733390136226`
  - max at `t = 0.21132499432248847`
  - suggested pieces:
    `HullLine(0.7886733390136226, 0.21132499432248847)` and
    `HullLine(0.21132499432248847, 0.7886733390136226)`
- `near_cusp_cubic_scaled` has the same extrema t-values

Endpoint tangent branch:

- many non-collinear hull lines connect an endpoint to an interior tangent
  point
- the relevant scalar equation is
  `cross(B'(t), B(t) - B(endpoint)) = 0`
- this is easier and more stable than solving full two-variable self-bitangents
  for common hull edges

Observed roots compared with current hull pieces:

- `far_control_cubic`
  - from `t=0`: `0.866363580041`
  - from `t=1`: `0.128835542612`
  - current hull had corresponding boundaries near `0.8663633945` and
    `0.1288356932`
- `opposite_far_controls_cubic`
  - from `t=0`: `0.733670655899`
  - from `t=1`: `0.236182341389`
  - current hull had corresponding boundaries near `0.7336711323` and
    `0.2361820619`
- `wide_loop_cubic`
  - from `t=0`: `0.640789395981`
  - from `t=1`: `0.359210604019`
  - current hull had corresponding boundaries near `0.6407892861` and
    `0.3592107224`
- `narrow_loop_cubic`
  - from `t=0`: `0.868693567105`
  - from `t=1`: `0.131306432895`
  - current hull had corresponding boundaries near `0.8686933775` and
    `0.1313066268`

This suggests a realistic root/event replacement might be decomposed into
smaller cases rather than one grand bitangent solve:

- classify collinear cubics and solve scalar extrema
- solve endpoint tangent chords
- reserve two-variable self-bitangents for genuine loop/interior cases
- validate every proposed line by one-sidedness/support checks

Tiny event-hull decision tree:

- using only the two endpoint tangent roots plus a one-sidedness check for the
  endpoint chord reproduced the current hull topology for:
  - `far_control_cubic`
  - `opposite_far_controls_cubic`
  - `wide_loop_cubic`
  - `narrow_loop_cubic`
- the numeric roots were within about `1e-6` of current support-sampling
  boundaries
- this is not yet general, but it is a much smaller and less mystical core than
  the full support-sampling purifier

Generated cubic endpoint-root applicability:

- checking `generated_cubic_1..35`, the endpoint-root decision tree applied
  directly to 9 out of 35
- most generated cubics had zero one-sided endpoint tangent roots on at least
  one side, which means they need other cases:
  - whole-curve exposed plus one closing chord
  - one endpoint tangent plus another kind of event
  - genuine interior bitangent
  - degenerate/flat handling
- so the endpoint-root branch is useful, but not remotely the whole algorithm

Transfer plan:

- `Line`, `QuadraticBezier`, and ordinary `Arc` do not need the general support
  sampler. Their hull topology is the original segment plus the endpoint chord:
  `HullCurve(0, 1)` and `HullLine(1, 0)`, with degenerate/near-zero cases
  handled by a small collapse policy.
- `CubicBezier` is the only segment type that needs the new solver machinery:
  sampled support topology, analytic support candidates, and root-refined
  curve-line boundaries.
- The current production support-sampling purifier should be moved to a private
  freezer rather than deleted immediately. It is useful as a behavioral oracle
  and as a source of adversarial fixtures, but it should stop being the default
  path for simple segment types.
- The shallow hybrid-support experiment in `src/svg_path/convex_hull.gleam`
  was informative but not a destination: trying both analytic cubic support and
  numeric minimization removed one pinned endpoint-control failure but introduced
  a `nearly_straight_cubic_translated` consecutive-curve failure.
