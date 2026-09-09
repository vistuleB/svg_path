// Run after: (cd examples/public_api_smoke && gleam build --target javascript)
// Exercise private production helpers without adding public API or modifying
// the generated module. The two modes differ only in the private switch.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';
const url = new URL('../public_api_smoke/build/dev/javascript/svg_path/svg_path/intersections.mjs', import.meta.url);
const source = (await readFile(url, 'utf8')).replace(/from "([^"]+)"/g,
  (_, specifier) => `from "${new URL(specifier, url).href}"`);
async function load(boxes) {
  const text = boxes ? source.replace('const window_bounds = WindowBounds$EnclosingPolygons$const;',
    'const window_bounds = new BoundingBoxes();') : source;
  return import('data:text/javascript;base64,' + Buffer.from(text +
    '\nexport {segment_enclosing_points, enclosing_points_disjoint, window_preserving_segment_with};').toString('base64'));
}
const polygon = await load(false), boxes = await load(true);
const p = (x,y) => new s.Point(x,y);
const ok = r => { assert(r.isOk(), JSON.stringify(r)); return r[0]; };
let checks = 0;
const separate = (a,b) => polygon.enclosing_points_disjoint(toList(a),toList(b));
assert(!separate([p(0,0)],[p(0,0)])); checks++;
assert(separate([p(0,0)],[p(1,0)])); checks++;
assert(!separate([p(0,0),p(1,0)],[p(1,0),p(2,0)])); checks++;
assert(separate([p(0,0),p(1,0)],[p(2,0),p(3,0)])); checks++;
// Overlapping axis-aligned boxes, but disjoint diagonal convex hulls.
assert(separate([p(0,0),p(2,2),p(1,1.01)], [p(0,.1),p(2,2.1),p(1,1.11)])); checks++;
assert(!separate([p(0,0),p(2,2)],[p(0,2),p(2,0)])); checks++;
// Every sampled curve point must lie inside its enclosure. These samples
// test implementation, not the mathematical proof of enclosure.
const curves = [new s.Line(p(0,0),p(2,3)),
  new s.QuadraticBezier(p(0,0),p(3,-2),p(1,4)),
  new s.CubicBezier(p(0,0),p(3,-2),p(-4,2),p(1,4))];
for (const sweep of [false,true]) for (const large of [false,true])
  curves.push(new s.Arc(p(1,2),p(5,3),37,large,sweep,p(4,-1)));
for (const curve of curves) for (const [a,b] of [[0,1],[.2,.8],[.5,.50000001]]) {
  const points = [...ok(polygon.segment_enclosing_points(curve,a,b))];
  for(let i=0;i<=100;i++) {
    const point = ok(s.segment_point(curve,a+(b-a)*i/100));
    assert(!separate(points,[point]), JSON.stringify({curve,a,b,i,point,points})); checks++;
  }
}
console.log(`Enclosure helper checks: ${checks} passed`);
const arcA=new s.Arc(p(82.60920101224798,220.34092587189474),p(20.01,20.01),0,false,true,p(43.21295323581002,213.39430445023285));
const arcB=new s.Arc(p(43.190371867436326,213.5338826899446),p(210,210),0,false,true,p(454.61771360489934,202.76027858778826));
const fixtures = [['loop8 cubics',[...s.segment_arcs_to_cubic_beziers(arcA)].at(-1),[...s.segment_arcs_to_cubic_beziers(arcB)][0]],
 ['kissing quadratics',new s.QuadraticBezier(p(-1,1),p(0,-1),p(1,1)),new s.QuadraticBezier(p(-1,-1),p(0,1),p(1,-1))],
 ['elliptical arcs',curves[3],new s.Arc(p(1,2.1),p(5,3),37,false,false,p(4,-.9))]];
for(const [name,a,b] of fixtures) for(const [mode,m] of [['boxes',boxes],['polygons',polygon]]) {
 const r=m.window_preserving_segment_with(a,b,1e-9,48);
 console.log(JSON.stringify({name,mode,result:r.isOk()?[...r[0]]:r}));
}
