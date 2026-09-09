// Build first: (cd examples/public_api_smoke && gleam build --target javascript)
// Resume a controlled late-stage circle-width search. Expose private helpers
// in memory without replacing any production algorithm or constant.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import * as trig from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/trig.mjs';
import {Some} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam/option.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';
const url = new URL('../public_api_smoke/build/dev/javascript/svg_path/svg_path/convex_hull.mjs', import.meta.url);
const source = (await readFile(url, 'utf8')).replace(/from "([^"]+)"/g,
  (_, specifier) => `from "${new URL(specifier, url).href}"`);
const hull = await import('data:text/javascript;base64,' + Buffer.from(source +
  '\nexport {minimum_width_optimization_loop, WidthSample, WidthInterval, width_lower_bound_roundoff};').toString('base64'));
let checks = 0;
for (const radius of [1, 1000]) {
  const diameter = 2 * radius;
  const roundoff = hull.width_lower_bound_roundoff(diameter);
  let calls = 0;
  const support = angle => {
    calls++;
    const x = radius * trig.cos_degrees(angle), y = radius * trig.sin_degrees(angle);
    return new hull.DirectionalSupport(new s.Point(-x,-y), new s.Point(x,y), diameter);
  };
  const from = new hull.WidthSample(0, support(0));
  const to = new hull.WidthSample(1e-12, support(1e-12));
  const run = accuracy => hull.minimum_width_optimization_loop(
    toList([from,to]), toList([new hull.WidthInterval(from,to)]), support,
    diameter, accuracy, 0, 1, new Some(diameter), roundoff);
  // The raw bound is close enough to discard this interval, but its rounded
  // lower bound is not. Exhausting the interval list must not invent certainty.
  calls = 0;
  const strict = run(roundoff / 4);
  assert.equal(strict.converged, false);
  assert(calls > 0, 'The unresolved interval must be refined, not discarded');
  assert(strict.upper_bound - strict.lower_bound > roundoff / 4);
  checks++;
  // A request wider than the allowance can still converge without refinement.
  calls = 0;
  const coarse = run(roundoff * 4);
  assert.equal(coarse.converged, true);
  assert.equal(calls, 0);
  checks++;
}
console.log(`Width pruning roundoff regression: ${checks} cases passed`);
