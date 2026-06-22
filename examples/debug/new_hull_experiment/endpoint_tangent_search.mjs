// Scratch-only endpoint tangent event search for cubic Beziers.
//
// A hull line often connects an endpoint to an interior point where the chord is
// tangent to the curve. This searches roots of:
//
//   cross(B'(t), B(t) - B(0)) = 0
//   cross(B'(t), B(t) - B(1)) = 0

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

function sideScore(c, anchor, t) {
  const a = anchor === 0 ? c.p0 : c.p3;
  const chord = sub(evalC(c, t), a);
  let min = Infinity;
  let max = -Infinity;
  for (let i = 0; i <= 400; i += 1) {
    const u = i / 400;
    const value = cross(chord, sub(evalC(c, u), a));
    min = Math.min(min, value);
    max = Math.max(max, value);
  }
  return { min, max, oneSided: min >= -1e-6 || max <= 1e-6 };
}

function endpointEquation(c, anchor, t) {
  const a = anchor === 0 ? c.p0 : c.p3;
  return cross(derivC(c, t), sub(evalC(c, t), a));
}

function bisect(c, anchor, left, right) {
  let fl = endpointEquation(c, anchor, left);
  for (let i = 0; i < 60; i += 1) {
    const mid = (left + right) / 2;
    const fm = endpointEquation(c, anchor, mid);
    if (Math.abs(fm) < 1e-9 || Math.abs(right - left) < 1e-10) return mid;
    if ((fl < 0 && fm < 0) || (fl > 0 && fm > 0)) {
      left = mid;
      fl = fm;
    } else {
      right = mid;
    }
  }
  return (left + right) / 2;
}

function roots(c, anchor) {
  const found = [];
  let previousT = 1e-5;
  let previous = endpointEquation(c, anchor, previousT);
  for (let i = 1; i <= 400; i += 1) {
    const t = i / 400;
    if (t >= 1 - 1e-5) continue;
    const value = endpointEquation(c, anchor, t);
    if (Math.abs(value) < 1e-8) pushUnique(found, t);
    if ((previous < 0 && value > 0) || (previous > 0 && value < 0)) {
      pushUnique(found, bisect(c, anchor, previousT, t));
    }
    previousT = t;
    previous = value;
  }
  return found
    .map((t) => ({ t, side: sideScore(c, anchor, t) }))
    .filter((candidate) => candidate.t > 1e-5 && candidate.t < 1 - 1e-5 && candidate.side.oneSided);
}

function pushUnique(values, t) {
  for (const value of values) {
    if (Math.abs(value - t) < 1e-5) return;
  }
  values.push(t);
}

const specimens = [
  ["far_control_cubic", cubic(point(0, 0), point(1000, 600), point(-900, 700), point(100, 0))],
  ["opposite_far_controls_cubic", cubic(point(-20, -10), point(500, -450), point(-520, 470), point(30, 20))],
  ["wide_loop_cubic", cubic(point(-80, 0), point(180, 160), point(-180, 160), point(80, 0))],
  ["narrow_loop_cubic", cubic(point(-5, 0), point(95, 120), point(-95, 120), point(5, 0))],
];

for (const [name, c] of specimens) {
  console.log(name);
  for (const anchor of [0, 1]) {
    const found = roots(c, anchor);
    const label = anchor === 0 ? "from t=0" : "from t=1";
    if (found.length === 0) {
      console.log(`  ${label}: none`);
    } else {
      for (const candidate of found) {
        console.log(
          `  ${label}: t=${candidate.t.toFixed(12)} ` +
            `side=[${candidate.side.min.toExponential(3)}, ${candidate.side.max.toExponential(3)}]`,
        );
      }
    }
  }
}
