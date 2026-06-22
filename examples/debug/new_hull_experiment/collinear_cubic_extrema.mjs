// Scratch-only collinear cubic hull primitive.
//
// For a collinear cubic, the convex hull is just the line segment between the
// minimum and maximum projected scalar values reached by the cubic. This script
// solves the scalar derivative and reports the t-values for those extrema.

function point(x, y) {
  return { x, y };
}

function sub(a, b) {
  return point(a.x - b.x, a.y - b.y);
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y;
}

function cubic(p0, p1, p2, p3) {
  return { p0, p1, p2, p3 };
}

function evalC(c, t) {
  const mt = 1 - t;
  return point(
    c.p0.x * mt * mt * mt + 3 * c.p1.x * mt * mt * t + 3 * c.p2.x * mt * t * t + c.p3.x * t * t * t,
    c.p0.y * mt * mt * mt + 3 * c.p1.y * mt * mt * t + 3 * c.p2.y * mt * t * t + c.p3.y * t * t * t,
  );
}

function roots(a, b, c) {
  if (Math.abs(a) < 1e-12) {
    if (Math.abs(b) < 1e-12) return [];
    return [-c / b];
  }
  const d = b * b - 4 * a * c;
  if (d < 0) return [];
  const r = Math.sqrt(d);
  return [(-b - r) / (2 * a), (-b + r) / (2 * a)];
}

function scalarExtrema(c) {
  let axis = sub(c.p3, c.p0);
  if (Math.hypot(axis.x, axis.y) < 1e-12) axis = sub(c.p1, c.p0);
  if (Math.hypot(axis.x, axis.y) < 1e-12) axis = point(1, 0);

  const p0 = dot(c.p0, axis);
  const p1 = dot(c.p1, axis);
  const p2 = dot(c.p2, axis);
  const p3 = dot(c.p3, axis);
  const a = -p0 + 3 * p1 - 3 * p2 + p3;
  const b = 3 * p0 - 6 * p1 + 3 * p2;
  const cc = -3 * p0 + 3 * p1;
  const candidates = [0, 1, ...roots(3 * a, 2 * b, cc).filter((t) => t >= 0 && t <= 1)];
  const evaluated = candidates.map((t) => ({ t, value: dot(evalC(c, t), axis) }));
  evaluated.sort((left, right) => left.value - right.value);
  return { min: evaluated[0], max: evaluated[evaluated.length - 1] };
}

const specimens = [
  ["endpoint_control_cubic", cubic(point(0, 0), point(0, 0), point(100, 0), point(100, 0))],
  ["near_cusp_cubic", cubic(point(0, 0), point(100, 0), point(-100, 0), point(0.001, 0))],
  ["near_cusp_cubic_scaled", cubic(point(0, 0), point(170, 0), point(-170, 0), point(0.0017, 0))],
];

for (const [name, c] of specimens) {
  const extrema = scalarExtrema(c);
  console.log(name);
  console.log(`  min t=${extrema.min.t} value=${extrema.min.value}`);
  console.log(`  max t=${extrema.max.t} value=${extrema.max.value}`);
  console.log(`  suggested pieces: HullLine(${extrema.min.t}, ${extrema.max.t}), HullLine(${extrema.max.t}, ${extrema.min.t})`);
}
