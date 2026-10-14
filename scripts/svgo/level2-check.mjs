// Compare level 2 compact policies with the preserved pre-change audit.
// Run after scripts/test-portable all fast has built the JavaScript target.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { parsePathData } from './node_modules/svgo/lib/path.js';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import * as transform from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
import * as transformParse from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/parse.mjs';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
const read = name => JSON.parse(fs.readFileSync(new URL(name, import.meta.url)));
const fixtures = read('fixtures.json');
const baseline = read('all-fixtures.json');
function equivalent(a, b, label) {
  if (typeof a === 'number' && typeof b === 'number') {
    assert(Math.abs(a-b) <= 1e-12 * Math.max(1, Math.abs(a), Math.abs(b)), label);
    return;
  }
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    assert.equal(a.constructor.name, b.constructor.name, label);
    assert.deepEqual(Object.keys(a), Object.keys(b), label);
    for (const key of Object.keys(a)) equivalent(a[key], b[key], label);
    return;
  }
  assert.equal(a,b,label);
}
let checked = 0, before = 0, after = 0;
const improvements = [];
for (const fixture of baseline.results) {
  const options = serialize.minifying_options(fixtures.find(f => f.file === fixture.file).params.floatPrecision ?? 3);
  for (const entry of fixture.cases) {
    if (entry.actual === undefined) continue;
    let geometry = parse.path(entry.source)[0];
    if (entry.flattenedTransform) {
      const result = transform.path(path.path_normalize_svg_arcs(geometry), transformParse.attribute(entry.flattenedTransform)[0]);
      assert(result.isOk());
      geometry = result[0];
    }
    const actual = serialize.path_with(geometry, options);
    const label = `${fixture.file}:${entry.number}`;
    const parsed = parse.path(actual);
    assert(parsed.isOk(), label);
    equivalent(parsed, parse.path(entry.actual), label);
    const expanded = parsePathData(actual).map(c => c.command + c.args.join(' ')).join(' ');
    equivalent(parsed, parse.path(expanded), label);
    assert.equal(serialize.path_with(parsed[0], options), actual, label);
    assert(actual.length <= entry.actual.length, label);
    checked++;
    before += entry.actual.length;
    after += actual.length;
    if (actual !== entry.actual) improvements.push({ fixture: label, saved: entry.actual.length - actual.length, before: entry.actual, after: actual });
  }
}
const result = { checked, before, after, saved: before - after, improved: improvements.length, improvements };
fs.writeFileSync(new URL('level2-check.json', import.meta.url), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ checked, before, after, saved: before - after, improved: improvements.length }));
