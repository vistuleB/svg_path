import test from 'node:test';
import assert from 'node:assert/strict';
import * as svg from 'svg-path-geometry-preview';
import * as parsing from 'svg-path-geometry-preview/parse';
import { unwrap, SvgPathError } from 'svg-path-geometry-preview/result';

const {parse,serialize,measure,Point,Line,Nonzero,offset,stroke,csg,area,transform,affine,arrangement,distance} = svg;
const path = d => unwrap(parse.path(d));
const close = (a,b,epsilon=1e-7) => assert.ok(Math.abs(a-b)<=epsilon, `${a} != ${b}`);

test('README recipe works through installed ESM exports', () => {
  const p=unwrap(parsing.path('M0 0 L3 4'));
  assert.equal(unwrap(measure.pathLength(p)),5);
  assert.equal(serialize.path(p),'M 0 0 L 3 4');
  assert.ok(Array.isArray(p.subpaths));
});
test('constructors and plain records interoperate; input records are not mutated', () => {
  const start=Object.freeze({x:0,y:0}),end=Object.freeze(Point(3,4));
  const line=Object.freeze(Line(start,end));
  assert.deepEqual(unwrap(svg.segmentPoint(line,.5)),{x:1.5,y:2});
  const mapped=unwrap(svg.segmentMapPoints(line,p=>Point(p.x+10,p.y)));
  assert.equal(mapped.start.x,10);assert.equal(start.x,0);
});
test('structured parse errors and optional throwing retain payloads', () => {
  const result=parse.path('M nope');assert.equal(result.ok,false);
  assert.equal(result.error.reason.kind,'UnsupportedCommand');
  assert.throws(()=>unwrap(result),e=>e instanceof SvgPathError && e.detail===result.error);
});
test('generic callback errors preserve arbitrary JavaScript payload identity', () => {
  const sentinel={reason:'user',nested:new Map([['x',42]])};
  const result=svg.pathTryMapPoints(path('M0 0 L3 4'),()=>({ok:false,error:sentinel}));
  assert.equal(result.ok,false);assert.equal(result.error.kind,'PointMapFunctionError');
  assert.equal(result.error.error,sentinel);
});
test('callbacks receive native objects and may return native Result objects', () => {
  const p=unwrap(svg.pathTryMapPoints(path('M0 0 L3 4'),p=>({ok:true,value:Point(p.x*2,p.y*2)})));
  close(unwrap(measure.pathLength(p)),10);
  const sentinel=new Error('callback');assert.throws(()=>svg.pathMapPoints(p,()=>{throw sentinel;}),e=>e===sentinel);
  assert.throws(()=>svg.pathMapPoints(p,async p=>p),/synchronous/);
});
test('opaque handles are reusable and reject forged or wrong-kind handles', () => {
  const p=path('M0 0 L3 4'), sub=p.subpaths[0];
  assert.ok(Object.isFrozen(sub));assert.equal(Object.keys(sub).length,0);
  assert.deepEqual(svg.pathMapSubpaths(p,s=>s),p);
  assert.throws(()=>svg.subpathSegments({}),/opaque/);
  assert.throws(()=>svg.subpathSegments(transform.identity()),/opaque/);
});
test('numeric domain failures are Results; malformed JS input is TypeError', () => {
  assert.throws(()=>svg.segmentPoint(Line({x:'zero',y:0},Point(1,0)),.5),TypeError);
  assert.throws(()=>parse.path(),/expects 1/);
  const p=path('M0 0 L3 4');
  assert.throws(()=>measure.pathLengthWith(p,{}),/Missing/);
  const result=measure.pathLengthWith(p,{...measure.defaultLengthOptions(),tolerance:-1});
  assert.equal(result.ok,false);
});
test('nested options with None and Some cross the boundary', () => {
  const p=path('M0 0 L10 0 L10 10');
  const defaults=offset.defaultOptions();assert.equal(defaults.innerJoin,null);
  const result=offset.pathWith(p,1,offset.Round(),offset.Butt(),{...defaults,innerJoin:offset.InnerRound()},offset.defaultSingleOffsetTrimming());
  assert.equal(result.ok,true);
});
test('intersections expose lists and labeled fields', () => {
  const hits=unwrap(svg.intersections.segment(Line(Point(0,0),Point(10,10)),Line(Point(0,10),Point(10,0))));
  assert.equal(hits.length,1);close(hits[0].point.x,5);close(hits[0].point.y,5);
});
test('projection substitutes concrete generic address types', () => {
  const p=path('M0 0 L10 0');const hit=unwrap(distance.pathProjection(Point(5,3),p));
  close(hit.distance,3);assert.equal(typeof hit.at.subpathIndex,'number');close(hit.at.at.t,.5);
});
test('Boolean output and arrangement graph round-trip into validation', () => {
  const a=path('M0 0 H10 V10 H0 Z'),b=path('M5 0 H15 V10 H5 Z');
  const combined=unwrap(csg.union(a,b,Nonzero()));close(unwrap(area.path(combined.path,Nonzero())),150);
  const graph=unwrap(arrangement.build([a,b],1e-6,1e-5)).graph;
  assert.ok(Array.isArray(graph.vertices));assert.ok(Array.isArray(graph.cyclicOrders));
  assert.deepEqual(arrangement.validateRepresentation(graph,1e-6,1e-5),{ok:true,value:undefined});
});
test('offset and stroke return serializable geometry', () => {
  const p=path('M0 0 H10 V10 H0 Z');
  assert.ok(serialize.path(unwrap(offset.path(p,1,offset.Round(),offset.Butt()))).length>0);
  const outlined=unwrap(stroke.path(path('M0 0 L10 0'),2,offset.Round(),offset.Butt()));
  close(unwrap(area.path(outlined,Nonzero())),20);
});
test('affine factorization and tuple conversion preserve coefficients', () => {
  const matrix=affine.matrix(2,.5,.2,3,7,11);
  const factors=unwrap(affine.decompose(matrix));
  affine.toTuple(affine.recompose(factors)).forEach((v,i)=>close(v,affine.toTuple(matrix)[i]));
  const opaque=transform.fromTuple([1,0,0,1,5,7]);
  assert.deepEqual(transform.toTuple(opaque),[1,0,0,1,5,7]);
});
test('SVG arc normalization stays explicit', () => {
  const p=path('M0 0 A0 5 0 0 0 10 0');
  assert.equal(measure.pathLength(p).ok,false);
  const normalized=svg.pathNormalizeSvgArcs(p);close(unwrap(measure.pathLength(normalized)),10);
});
test('internal modules are not public package exports', async () => {
  await assert.rejects(import('svg-path-geometry-preview/lib/registry.mjs'),{code:'ERR_PACKAGE_PATH_NOT_EXPORTED'});
});
