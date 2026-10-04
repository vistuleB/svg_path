//// Parametric curve fitting, constrained cubic fitting, and scalar minimization.
//// Approximation controls and fitting diagnostics remain available to specialist callers.

import svg_path
import svg_path/internal/query

/// Return the default options for segment minimization.
pub fn default_minimize_options() -> svg_path.MinimizeOptions {
  query.default_minimize_options()
}

/// Return the default options for parametric subpath fitting.
pub fn default_parametric_options() -> svg_path.ParametricOptions {
  query.default_parametric_options()
}

/// Approximate a parametric curve with a sequence of cubic Bezier segments.
///
/// The parameter interval is split uniformly into
/// `default_parametric_options().initial_piece_count` pieces. Each piece is
/// fitted with a cubic, then recursively bisected in parameter space until the
/// maximum sampled fitting error is within tolerance.
/// `from` and `to` must be finite and unequal; descending intervals are allowed.
/// Otherwise returns `InvalidParametricInterval`. Fitting and construction
/// errors propagate; this function does not guarantee a successful fit.
pub fn subpath_from_parametric(
  from start: Float,
  to end: Float,
  point point_function: fn(Float) -> svg_path.Point,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_from_parametric(from: start, to: end, point: point_function)
}

/// Approximate a parametric curve with a sequence of cubic Bezier segments
/// using explicit options.
///
/// If `options.tangent` is `Some(tangent_function)`, each cubic is constrained
/// to match the endpoint tangent directions returned by that function. If it is
/// `None`, control points are fitted from samples while the endpoints are fixed.
/// The interval restrictions are the same as for `subpath_from_parametric`.
/// Options must satisfy the constraints documented on `ParametricOptions`;
/// invalid options, failed fits, and exhausted refinement return errors.
pub fn subpath_from_parametric_with(
  from start: Float,
  to end: Float,
  point point_function: fn(Float) -> svg_path.Point,
  options options: svg_path.ParametricOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_from_parametric_with(
    from: start,
    to: end,
    point: point_function,
    options: options,
  )
}

/// Fit a cubic Bezier segment with fixed endpoints and endpoint tangents.
///
/// This is a geometry-model convenience wrapper around
/// `bezier.fit_cubic_with_endpoint_tangents`. It accepts `svg_path.Point`
/// values, returns an `svg_path.CubicBezier` segment, and maps fit failures
/// into `svg_path.Error`.
pub fn fit_cubic_with_endpoint_tangents(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_tangent start_tangent: svg_path.Point,
  end_tangent end_tangent: svg_path.Point,
  samples samples: List(#(Float, svg_path.Point)),
) -> Result(#(svg_path.Segment, svg_path.CubicFitReport), svg_path.Error) {
  query.fit_cubic_with_endpoint_tangents(
    start: start,
    end: end,
    start_tangent: start_tangent,
    end_tangent: end_tangent,
    samples: samples,
  )
}

/// Fit a cubic Bezier segment with fixed endpoints and no tangent constraints.
///
/// This is a geometry-model convenience wrapper around
/// `bezier.fit_cubic_with_endpoints`. It accepts `svg_path.Point` values,
/// returns an `svg_path.CubicBezier` segment, and maps fit failures into
/// `svg_path.Error`.
pub fn fit_cubic_with_endpoints(
  start start: svg_path.Point,
  end end: svg_path.Point,
  samples samples: List(#(Float, svg_path.Point)),
) -> Result(#(svg_path.Segment, svg_path.CubicFitReport), svg_path.Error) {
  query.fit_cubic_with_endpoints(start: start, end: end, samples: samples)
}

/// Return the segment parameter where a scalar function is minimized.
///
/// This numerically minimizes `f(segment_point(t))` for `t` in `0.0..1.0`.
pub fn segment_minimize(
  segment: svg_path.Segment,
  measure f: fn(svg_path.Point) -> Float,
) -> Result(Float, svg_path.Error) {
  query.segment_minimize(segment, measure: f)
}

/// Return the segment parameter where a scalar function is minimized using
/// explicit options.
pub fn segment_minimize_with(
  segment: svg_path.Segment,
  measure f: fn(svg_path.Point) -> Float,
  options options: svg_path.MinimizeOptions,
) -> Result(Float, svg_path.Error) {
  query.segment_minimize_with(segment, measure: f, options: options)
}
