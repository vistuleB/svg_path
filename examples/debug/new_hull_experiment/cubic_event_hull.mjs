// Scratch-only cubic event hull sketch.
//
// This tries a deliberately small decision tree:
//
// - collinear cubic: two lines between scalar min/max extrema
// - otherwise find the one-sided endpoint tangent from t=0 and from t=1
// - if endpoint chord B(0)-B(1) is one-sided, include that chord
// - otherwise wrap curve pieces around the endpoints

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

function sideScore(c, a, b) {
  const chord = sub(evalC(c, b), evalC(c, a));
  const anchor = evalC(c, a);
  let min = Infinity;
  let max = -Infinity;
  for (let i = 0; i <= 400; i += 1) {
    const u = i / 400;
    const value = cross(chord, sub(evalC(c, u), anchor));
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

function endpointRoots(c, anchor) {
  const found = [];
  let previousT = 1e-5;
  let previous = endpointEquation(c, anchor, previousT);
  for (let i = 1; i <= 400; i += 1) {
    const t = i / 400;
    if (t >= 1 - 1e-5) continue;
    const value = endpointEquation(c, anchor, t);
    if ((previous < 0 && value > 0) || (previous > 0 && value < 0)) {
      pushUnique(found, bisect(c, anchor, previousT, t));
    }
    previousT = t;
    previous = value;
  }
  return found.filter((t) => sideScore(c, anchor, t).oneSided);
}

function pushUnique(values, t) {
  for (const value of values) {
    if (Math.abs(value - t) < 1e-5) return;
  }
  values.push(t);
}

function piece(kind, a, b) {
  return `${kind}(${round(a)}, ${round(b)})`;
}

function round(x) {
  return Number(x).toFixed(9);
}

function eventHull(c) {
  const fromStart = endpointRoots(c, 0);
  const fromEnd = endpointRoots(c, 1);
  if (fromStart.length !== 1 || fromEnd.length !== 1) {
    return [`needs fallback: start roots=${fromStart.length}, end roots=${fromEnd.length}`];
  }

  const a = fromStart[0];
  const b = fromEnd[0];
  if (sideScore(c, 0, 1).oneSided) {
    return [
      piece("Curve", b, a),
      piece("Line", a, 0),
      piece("Line", 0, 1),
      piece("Line", 1, b),
    ];
  }

  return [
    piece("Curve", 0, b),
    piece("Line", b, 1),
    piece("Curve", 1, a),
    piece("Line", a, 0),
  ];
}

const specimens = [
  [
    "far_control_cubic",
    cubic(point(0, 0), point(1000, 600), point(-900, 700), point(100, 0)),
    "[Curve(0.128835693, 0.866363395), Line(0.866363395, 0), Line(0, 1), Line(1, 0.128835693)]",
  ],
  [
    "opposite_far_controls_cubic",
    cubic(point(-20, -10), point(500, -450), point(-520, 470), point(30, 20)),
    "[Curve(0, 0.236182062), Line(0.236182062, 1), Curve(1, 0.733671132), Line(0.733671132, 0)]",
  ],
  [
    "wide_loop_cubic",
    cubic(point(-80, 0), point(180, 160), point(-180, 160), point(80, 0)),
    "[Line(1, 0.359210722), Curve(0.359210722, 0.640789286), Line(0.640789286, 0), Line(0, 1)]",
  ],
  [
    "narrow_loop_cubic",
    cubic(point(-5, 0), point(95, 120), point(-95, 120), point(5, 0)),
    "[Curve(0.131306627, 0.868693377), Line(0.868693377, 0), Line(0, 1), Line(1, 0.131306627)]",
  ],
];

for (const [name, c, current] of specimens) {
  console.log(name);
  console.log(`  event:   [${eventHull(c).join(", ")}]`);
  console.log(`  current: ${current}`);
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

let handled = 0;
let fallback = 0;
const fallbackNames = [];
for (let i = 1; i <= 35; i += 1) {
  const c = generatedCubic(i);
  const fromStart = endpointRoots(c, 0);
  const fromEnd = endpointRoots(c, 1);
  if (fromStart.length === 1 && fromEnd.length === 1) {
    handled += 1;
  } else {
    fallback += 1;
    fallbackNames.push(`generated_cubic_${i}(start=${fromStart.length},end=${fromEnd.length})`);
  }
}

console.log("generated cubic endpoint-root applicability");
console.log(`  handled=${handled} fallback=${fallback}`);
console.log(`  fallback names=${fallbackNames.join(", ")}`);
