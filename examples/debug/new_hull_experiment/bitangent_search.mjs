// Scratch-only bitangent search for cubic Beziers.
//
// This is intentionally not part of the Gleam package. It tries to solve the
// self-bitangent equations:
//
//   cross(B'(s), B(t) - B(s)) = 0
//   cross(B'(t), B(t) - B(s)) = 0
//
// from many grid seeds using Newton iterations.

const EPS = 1e-9;

function point(x, y) {
  return { x, y };
}

function add(a, b) {
  return point(a.x + b.x, a.y + b.y);
}

function sub(a, b) {
  return point(a.x - b.x, a.y - b.y);
}

function scale(a, k) {
  return point(a.x * k, a.y * k);
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y;
}

function cross(a, b) {
  return a.x * b.y - a.y * b.x;
}

function cubic(p0, p1, p2, p3) {
  return { p0, p1, p2, p3 };
}

function controlPolygonAreaScale(c) {
  const chord = sub(c.p3, c.p0);
  const area1 = Math.abs(cross(chord, sub(c.p1, c.p0)));
  const area2 = Math.abs(cross(chord, sub(c.p2, c.p0)));
  const chordLength = Math.hypot(chord.x, chord.y);
  return Math.max(area1, area2) / Math.max(chordLength, EPS);
}

function evalC(c, t) {
  const mt = 1 - t;
  return add(
    add(scale(c.p0, mt * mt * mt), scale(c.p1, 3 * mt * mt * t)),
    add(scale(c.p2, 3 * mt * t * t), scale(c.p3, t * t * t)),
  );
}

function derivC(c, t) {
  const mt = 1 - t;
  return add(
    add(scale(sub(c.p1, c.p0), 3 * mt * mt), scale(sub(c.p2, c.p1), 6 * mt * t)),
    scale(sub(c.p3, c.p2), 3 * t * t),
  );
}

function equations(c, s, t) {
  const chord = sub(evalC(c, t), evalC(c, s));
  return [cross(derivC(c, s), chord), cross(derivC(c, t), chord)];
}

function newton(c, s, t) {
  for (let i = 0; i < 30; i += 1) {
    if (s <= 0 || s >= 1 || t <= 0 || t >= 1 || Math.abs(s - t) < 1e-5) return null;
    const [f, g] = equations(c, s, t);
    if (Math.hypot(f, g) < 1e-6) return normalizePair(s, t);

    const h = 1e-5;
    const [fs, gs] = equations(c, s + h, t);
    const [ft, gt] = equations(c, s, t + h);
    const a = (fs - f) / h;
    const b = (ft - f) / h;
    const cc = (gs - g) / h;
    const d = (gt - g) / h;
    const det = a * d - b * cc;
    if (Math.abs(det) < 1e-12) return null;

    const ds = (-f * d + b * g) / det;
    const dt = (cc * f - a * g) / det;
    s += ds;
    t += dt;
  }
  return null;
}

function normalizePair(s, t) {
  return s < t ? [s, t] : [t, s];
}

function sideScore(c, s, t) {
  const a = evalC(c, s);
  const chord = sub(evalC(c, t), a);
  let min = Infinity;
  let max = -Infinity;
  for (let i = 0; i <= 200; i += 1) {
    const u = i / 200;
    const value = cross(chord, sub(evalC(c, u), a));
    min = Math.min(min, value);
    max = Math.max(max, value);
  }
  return { min, max, oneSided: min >= -1e-5 || max <= 1e-5 };
}

function uniquePush(pairs, pair) {
  if (!pair) return;
  const [s, t] = pair;
  if (s < 0 || s > 1 || t < 0 || t > 1 || Math.abs(s - t) < 1e-4) return;
  for (const [a, b] of pairs) {
    if (Math.abs(a - s) < 1e-5 && Math.abs(b - t) < 1e-5) return;
  }
  pairs.push(pair);
}

function bitangents(c) {
  const pairs = [];
  for (let i = 1; i < 24; i += 1) {
    for (let j = 1; j < 24; j += 1) {
      if (Math.abs(i - j) < 2) continue;
      uniquePush(pairs, newton(c, i / 24, j / 24));
    }
  }
  return pairs
    .map(([s, t]) => ({ s, t, side: sideScore(c, s, t) }))
    .filter((candidate) => candidate.side.oneSided)
    .sort((a, b) => a.s - b.s || a.t - b.t);
}

function transform(c, m) {
  const apply = (p) => point(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f);
  return cubic(apply(c.p0), apply(c.p1), apply(c.p2), apply(c.p3));
}

const rotate37 = (() => {
  const r = 37 * Math.PI / 180;
  return { a: Math.cos(r), b: Math.sin(r), c: -Math.sin(r), d: Math.cos(r), e: 0, f: 0 };
})();

const specimens = [
  ["endpoint_control_cubic", cubic(point(0, 0), point(0, 0), point(100, 0), point(100, 0))],
  ["endpoint_control_cubic_rotated", transform(cubic(point(0, 0), point(0, 0), point(100, 0), point(100, 0)), rotate37)],
  ["near_cusp_cubic", cubic(point(0, 0), point(100, 0), point(-100, 0), point(0.001, 0))],
  ["near_cusp_cubic_scaled", cubic(point(0, 0), point(170, 0), point(-170, 0), point(0.0017, 0))],
  ["wide_loop_cubic", cubic(point(-80, 0), point(180, 160), point(-180, 160), point(80, 0))],
  ["narrow_loop_cubic", cubic(point(-5, 0), point(95, 120), point(-95, 120), point(5, 0))],
];

for (const [name, c] of specimens) {
  console.log(name);
  const flatness = controlPolygonAreaScale(c);
  if (flatness < 1e-8) {
    console.log(`  near-collinear control polygon; isolated bitangent equations are degenerate (flatness=${flatness})`);
    continue;
  }

  const found = bitangents(c);
  if (found.length === 0) {
    console.log("  no interior one-sided bitangents found");
  } else {
    console.log(`  ${found.length} interior one-sided bitangent candidate(s)`);
    for (const candidate of found.slice(0, 8)) {
      console.log(
        `  s=${candidate.s.toFixed(9)} t=${candidate.t.toFixed(9)} ` +
          `side=[${candidate.side.min.toExponential(3)}, ${candidate.side.max.toExponential(3)}]`,
      );
    }
    if (found.length > 8) console.log("  ...");
  }
}
