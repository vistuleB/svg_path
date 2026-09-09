// Run after: (cd examples/public_api_smoke && gleam build --target javascript)
// Exercise the private cusp finisher on a controlled post-classification state.
// Only expose helpers in memory; do not replace production logic or add API.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import * as ag from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';
import {None, Some} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const url = new URL('../public_api_smoke/build/dev/javascript/svg_path/svg_path/offset.mjs', import.meta.url);
const source = (await readFile(url, 'utf8')).replace(/from "([^"]+)"/g,
  (_, specifier) => `from "${new URL(specifier, url).href}"`);
const off = await import('data:text/javascript;base64,' + Buffer.from(source +
  '\nexport {finish_cusp_trim_with_parity, ArrangementSplitTracedSegment, ArrangementSplitTracedSubpath, OffsetArrangementBuild, ICulledOffsetSegment, HPreimageSegment, JoinPreimage, Outer};').toString('base64'));
const ok = r => { assert(r.isOk(), JSON.stringify(r)); return r[0]; };
const points = [[0,0],[10,0],[10,10],[0,10],[0,0]].map(([x,y]) => new s.Point(x,y));
const square = s.subpath_assert_set_closed(s.subpath_assert_polyline(toList(points)), true);
const built = ok(ag.build(toList([s.subpath_as_path(square)]), 1e-9, 1e-8));
const segments = [...built.graph.edges].map(edge => new off.ArrangementSplitTracedSegment(
  edge.segment,
  new off.ICulledOffsetSegment(edge.segment,
    new off.HPreimageSegment(edge.segment, new off.JoinPreimage(0, new off.Outer(), edge.id, false)), 0, 1),
  0, 1, edge.id, edge.start_vertex, edge.end_vertex, false, false));
const split = new off.ArrangementSplitTracedSubpath(toList(segments), true, new off.Outer());
const build = new off.OffsetArrangementBuild(built.graph, toList([]), toList([]), toList([]));
// No retained segments and a retained proper arc of the square must both be
// empty after parity. Test every position, not just the first edge.
let checks = 0;
for (const count of [0,1,2,3]) {
  for (let start = 0; start < 4; start++) {
    const retained = Array.from({length: count}, (_, i) => segments[(start+i)%4]);
    const result = ok(off.finish_cusp_trim_with_parity(split, toList(retained), build));
    assert(result instanceof None, `Expected no cusp survivor: start=${start}, count=${count}`);
    checks++;
  }
}
// A whole cycle must remain one closed survivor with all four occurrences.
const survivor = ok(off.finish_cusp_trim_with_parity(split, toList(segments), build));
assert(survivor instanceof Some);
assert.equal(survivor[0].closed, true);
assert.equal([...survivor[0].segments].length, 4);
checks++;
console.log(`Cusp empty-result regression: ${checks} cases passed`);
