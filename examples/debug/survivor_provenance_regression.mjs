// Build first: (cd examples/public_api_smoke && gleam build --target javascript)
// Expose private production helpers in memory without changing their bodies.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';
import {None, Some} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const url = new URL('../public_api_smoke/build/dev/javascript/svg_path/svg_path/offset.mjs', import.meta.url);
const source = (await readFile(url, 'utf8')).replace(/from "([^"]+)"/g,
  (_, specifier) => `from "${new URL(specifier, url).href}"`);
const off = await import('data:text/javascript;base64,' + Buffer.from(source + `
export {reverse_survivor_chain, traced_subpath_from_survivor_chain,
  cusp_trim_subpath_from_chain, traced_subpath_from_cusp_trimmed, interval_parameter,
  SurvivorEdge, SurvivorChain, ArrangementSplitTracedSegment, ICulledOffsetSegment,
  HPreimageSegment, JoinPreimage, Outer};`).toString('base64'));
const ok = r => { assert(r.isOk(), JSON.stringify(r)); return r[0]; };
let checks = 0;
for (const geometricallyReversed of [false, true]) {
  const h = new off.HPreimageSegment(new s.Line(new s.Point(0,0), new s.Point(10,0)),
    new off.JoinPreimage(0, new off.Outer(), 0, geometricallyReversed));
  const geometry = new s.Line(new s.Point(2,0), new s.Point(7,0));
  const i = new off.ICulledOffsetSegment(geometry, h, .2, .7);
  const split = new off.ArrangementSplitTracedSegment(geometry, i, .2, .7, 42, 2, 7,
    geometricallyReversed, false);
  const edge = new off.SurvivorEdge(42, false, 2, 7, geometry, new Some(split));
  const chain = new off.SurvivorChain(2, 7, toList([edge]), false);
  const reversed = off.reverse_survivor_chain(chain);
  const checkTrace = traced => {
    const [segment] = traced.segments;
    assert.deepEqual(segment.segment, s.segment_reverse(geometry));
    assert.equal(segment.preimage, h);
    assert.equal(segment.preimage_from, .7);
    assert.equal(segment.preimage_to, .2);
    assert.equal(segment.reversed, geometricallyReversed);
    // A later local cut must still map back to the same H geometry.
    const hParameter = off.interval_parameter(segment.preimage_from, segment.preimage_to, .25);
    const localPoint = ok(s.segment_point(segment.segment, .25));
    const sourcePoint = ok(s.segment_point(h.segment, hParameter));
    assert(Math.abs(localPoint.x-sourcePoint.x) < 1e-12);
    checks++;
  };
  checkTrace(ok(off.traced_subpath_from_survivor_chain(reversed, new off.Outer(), 0)));
  const cusp = ok(off.cusp_trim_subpath_from_chain(reversed, false, 7, 2));
  checkTrace(off.traced_subpath_from_cusp_trimmed(cusp, 0, new off.Outer()));
  assert.deepEqual(off.reverse_survivor_chain(reversed), chain);
  checks++;
}
// Ordinary final-trim edges have no traced preimage and must still reverse.
const plain = new off.SurvivorChain(0, 1, toList([
  new off.SurvivorEdge(0, false, 0, 1, new s.Line(new s.Point(0,0), new s.Point(1,0)), new None()),
]), false);
assert.deepEqual(off.reverse_survivor_chain(off.reverse_survivor_chain(plain)), plain);
checks++;
console.log(`Survivor provenance regression: ${checks} cases passed`);
