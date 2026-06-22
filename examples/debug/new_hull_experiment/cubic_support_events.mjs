// Scratch-only support-event discovery for cubic Beziers.
//
// This uses exact cubic support roots for each direction, then compresses the
// resulting t-sequence into exposed intervals and chords. It is intentionally
// close in spirit to the existing algorithm, but replaces numeric minimization
// with closed-form cubic support and makes the compression easier to inspect.

const T_CLOSE = 0.08;
const SAME_T = 1e-6;

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

function support(c, degrees) {
  const r = degrees * Math.PI / 180;
  const dir = point(Math.cos(r), Math.sin(r));
  const p0 = dot(c.p0, dir);
  const p1 = dot(c.p1, dir);
  const p2 = dot(c.p2, dir);
  const p3 = dot(c.p3, dir);
  const a = -p0 + 3 * p1 - 3 * p2 + p3;
  const b = 3 * p0 - 6 * p1 + 3 * p2;
  const cc = -3 * p0 + 3 * p1;
  const candidates = [0, 1, ...roots(3 * a, 2 * b, cc).filter((t) => t >= 0 && t <= 1)];
  let bestT = candidates[0];
  let bestValue = scalarValue(p0, p1, p2, p3, bestT);
  for (const t of candidates.slice(1)) {
    const value = scalarValue(p0, p1, p2, p3, t);
    if (value > bestValue) {
      bestT = t;
      bestValue = value;
    }
  }
  return { angle: degrees, t: bestT, value: bestValue };
}

function supportOnInterval(c, degrees, from, to) {
  const r = degrees * Math.PI / 180;
  const dir = point(Math.cos(r), Math.sin(r));
  const p0 = dot(c.p0, dir);
  const p1 = dot(c.p1, dir);
  const p2 = dot(c.p2, dir);
  const p3 = dot(c.p3, dir);
  const a = -p0 + 3 * p1 - 3 * p2 + p3;
  const b = 3 * p0 - 6 * p1 + 3 * p2;
  const cc = -3 * p0 + 3 * p1;
  const lo = Math.min(from, to);
  const hi = Math.max(from, to);
  const candidates = [from, to, ...roots(3 * a, 2 * b, cc).filter((t) => t >= lo && t <= hi)];
  return Math.max(...candidates.map((t) => scalarValue(p0, p1, p2, p3, t)));
}

function lineSupport(c, degrees, from, to) {
  const r = degrees * Math.PI / 180;
  const dir = point(Math.cos(r), Math.sin(r));
  return Math.max(dot(evalC(c, from), dir), dot(evalC(c, to), dir));
}

function hullSupport(c, pieces, degrees) {
  return Math.max(...pieces.map((p) => {
    if (p.kind === "Curve") return supportOnInterval(c, degrees, p.a, p.b);
    return lineSupport(c, degrees, p.a, p.b);
  }));
}

function maxSupportError(c, pieces) {
  let worst = 0;
  for (let i = 0; i < 3600; i += 1) {
    const degrees = i * 360 / 3600;
    worst = Math.max(worst, Math.abs(support(c, degrees).value - hullSupport(c, pieces, degrees)));
  }
  for (let i = 0; i < 720; i += 1) {
    const degrees = ((Math.sin(i * 78.233) * 43758.5453123) % 1 + 1) % 1 * 360;
    worst = Math.max(worst, Math.abs(support(c, degrees).value - hullSupport(c, pieces, degrees)));
  }
  return worst;
}

function scalarValue(p0, p1, p2, p3, t) {
  const mt = 1 - t;
  return p0 * mt * mt * mt + 3 * p1 * mt * mt * t + 3 * p2 * mt * t * t + p3 * t * t * t;
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

function rawSamples(c, n = 360) {
  const samples = [];
  for (let i = 0; i < n; i += 1) samples.push(support(c, i * 360 / n));
  return samples;
}

function collapseRuns(samples) {
  const runs = [];
  let current = { startAngle: samples[0].angle, endAngle: samples[0].angle, ts: [samples[0].t] };
  for (const sample of samples.slice(1)) {
    const previousT = current.ts[current.ts.length - 1];
    if (Math.abs(sample.t - previousT) <= T_CLOSE) {
      current.endAngle = sample.angle;
      current.ts.push(sample.t);
    } else {
      runs.push(current);
      current = { startAngle: sample.angle, endAngle: sample.angle, ts: [sample.t] };
    }
  }
  runs.push(current);

  // Merge first/last if the circular boundary cuts through one continuous run.
  if (runs.length > 1) {
    const first = runs[0];
    const last = runs[runs.length - 1];
    if (Math.abs(first.ts[0] - last.ts[last.ts.length - 1]) <= T_CLOSE) {
      runs[0] = {
        startAngle: last.startAngle,
        endAngle: first.endAngle,
        ts: [...last.ts, ...first.ts],
      };
      runs.pop();
    }
  }
  return runs;
}

function runEndpoint(run) {
  let min = Infinity;
  let max = -Infinity;
  for (const t of run.ts) {
    min = Math.min(min, t);
    max = Math.max(max, t);
  }
  if (max - min < SAME_T) return { kind: "point", t: average(run.ts) };
  return { kind: "curve", from: run.ts[0], to: run.ts[run.ts.length - 1], min, max };
}

function average(xs) {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

function piecesFromRuns(runs) {
  const endpoints = runs.map(runEndpoint);
  const pieces = [];
  for (let i = 0; i < endpoints.length; i += 1) {
    const current = endpoints[i];
    const next = endpoints[(i + 1) % endpoints.length];
    if (current.kind === "curve") pieces.push(piece("Curve", current.from, current.to));
    pieces.push(piece("Line", endT(current), startT(next)));
  }
  return pieces.filter((p) => Math.abs(p.a - p.b) > SAME_T || p.kind === "Line");
}

function refinePieces(c, pieces) {
  const refined = pieces.map((p) => ({ ...p }));
  for (let i = 0; i < refined.length; i += 1) {
    const piece = refined[i];
    if (piece.kind !== "Curve") continue;

    const previous = refined[(i + refined.length - 1) % refined.length];
    const next = refined[(i + 1) % refined.length];
    if (previous?.kind === "Line") {
      const t = refineChordTangent(c, piece.a, previous.a);
      piece.a = t;
      previous.b = t;
    }
    if (next?.kind === "Line") {
      const t = refineChordTangent(c, piece.b, next.b);
      piece.b = t;
      next.a = t;
    }
  }
  return refined.filter((p) => Math.abs(p.a - p.b) > SAME_T || p.kind === "Line");
}

function refineChordTangent(c, approximate, other) {
  if (approximate < SAME_T || approximate > 1 - SAME_T) return approximate;
  const f = (t) => cross(derivC(c, t), sub(evalC(c, other), evalC(c, t)));
  const initial = f(approximate);
  if (Math.abs(initial) < 1e-12) return approximate;

  let best = approximate;
  let bestValue = Math.abs(initial);
  const radius = 0.08;
  const steps = 64;
  let previousT = Math.max(0, approximate - radius);
  let previousValue = f(previousT);
  for (let i = 1; i <= steps; i += 1) {
    const t = Math.max(0, approximate - radius) + (Math.min(1, approximate + radius) - Math.max(0, approximate - radius)) * i / steps;
    const value = f(t);
    if (Math.abs(value) < bestValue) {
      best = t;
      bestValue = Math.abs(value);
    }
    if (previousValue === 0 || value === 0 || previousValue < 0 !== value < 0) {
      return bisectRoot(f, previousT, t);
    }
    previousT = t;
    previousValue = value;
  }
  return best;
}

function bisectRoot(f, left, right) {
  let fl = f(left);
  let fr = f(right);
  if (Math.abs(fl) < 1e-14) return left;
  if (Math.abs(fr) < 1e-14) return right;
  for (let i = 0; i < 80; i += 1) {
    const mid = (left + right) / 2;
    const fm = f(mid);
    if (Math.abs(fm) < 1e-14 || Math.abs(right - left) < 1e-12) return mid;
    if (fl < 0 === fm < 0) {
      left = mid;
      fl = fm;
    } else {
      right = mid;
      fr = fm;
    }
  }
  return (left + right) / 2;
}

function startT(endpoint) {
  return endpoint.kind === "curve" ? endpoint.from : endpoint.t;
}

function endT(endpoint) {
  return endpoint.kind === "curve" ? endpoint.to : endpoint.t;
}

function piece(kind, a, b) {
  return { kind, a, b };
}

function formatPieces(pieces) {
  return pieces.map((p) => `${p.kind}(${p.a.toFixed(9)}, ${p.b.toFixed(9)})`).join(", ");
}

function wave(i, salt) {
  return Math.sin(i * salt * 12.9898) * 50.0;
}

function generatedCubic(i) {
  const x = i;
  const scaleFactor = i % 4 === 0 ? 1.0 : i % 4 === 1 ? 0.01 : i % 4 === 2 ? 100.0 : 10.0;
  return cubic(
    point(scaleFactor * wave(x, 3.0), scaleFactor * wave(x, 11.0)),
    point(scaleFactor * 4.0 * wave(x, 17.0), scaleFactor * 3.0 * wave(x, 23.0)),
    point(scaleFactor * 4.0 * wave(x, 31.0), scaleFactor * 3.0 * wave(x, 41.0)),
    point(scaleFactor * wave(x, 47.0), scaleFactor * wave(x, 59.0)),
  );
}

const specimens = [
  ["endpoint_control_cubic", cubic(point(0, 0), point(0, 0), point(100, 0), point(100, 0))],
  ["near_cusp_cubic", cubic(point(0, 0), point(100, 0), point(-100, 0), point(0.001, 0))],
  ["far_control_cubic", cubic(point(0, 0), point(1000, 600), point(-900, 700), point(100, 0))],
  ["opposite_far_controls_cubic", cubic(point(-20, -10), point(500, -450), point(-520, 470), point(30, 20))],
  ["wide_loop_cubic", cubic(point(-80, 0), point(180, 160), point(-180, 160), point(80, 0))],
  ["narrow_loop_cubic", cubic(point(-5, 0), point(95, 120), point(-95, 120), point(5, 0))],
  ...Array.from({ length: 200 }, (_, i) => [`generated_cubic_${i + 1}`, generatedCubic(i + 1)]),
];

for (const [name, c] of specimens) {
  const runs = collapseRuns(rawSamples(c, 3600));
  const pieces = refinePieces(c, piecesFromRuns(runs));
  const consecutiveCurves = pieces.some((p, i) => p.kind === "Curve" && pieces[(i + 1) % pieces.length].kind === "Curve");
  const supportError = maxSupportError(c, pieces);
  console.log(`${name}: runs=${runs.length} pieces=${pieces.length} consecutiveCurves=${consecutiveCurves} supportError=${supportError}`);
  console.log(`  ${formatPieces(pieces)}`);
}
