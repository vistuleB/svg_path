import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import * as upstream from './node_modules/svgo/lib/path.js';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
const root = new URL('./', import.meta.url);
const rows = [];
let title, current;
const expanded = data => data.map(x => x.command + x.args.join(' ')).join(' ');
const normalize = x => JSON.stringify(path.path_normalize_svg_arcs(x));
function equalGeometry(a, b) {
  if (typeof a === 'number' && typeof b === 'number') {
    assert(Math.abs(a - b) <= 32 * Number.EPSILON * Math.max(Math.abs(a), Math.abs(b), Number.MIN_VALUE), `${a} vs ${b}`);
    return;
  }
  if (a === null || typeof a !== 'object') { assert.equal(a,b); return; }
  assert.deepEqual(Object.keys(a), Object.keys(b));
  for (const key of Object.keys(a)) equalGeometry(a[key], b[key]);
}
const context = {
 describe: (_name, fn) => fn(),
 it: (name, fn) => { title = name; fn(); },
 parsePathData: input => { current = { kind: 'parse', input }; return upstream.parsePathData(input); },
 stringifyPathData: options => { current = { kind: 'serialize', options }; return upstream.stringifyPathData(options); },
 expect: actual => {
   const check = expected => {
     assert.equal(JSON.stringify(actual), JSON.stringify(expected));
     const row = { test: title, ...current, expected };
     if (current.kind === 'parse') {
       const ours = parse.path(current.input);
       row.accepted = ours.isOk();
       if (!ours.isOk()) {
         row.classification = 'strict-error-versus-prefix-recovery';
         assert.match(title, /forbid|stop/);
       } else {
         const reference = parse.path(expanded(expected));
         assert(reference.isOk());
         assert.equal(normalize(ours[0]), normalize(reference[0]));
         row.classification = title.includes('signed arc') ? 'explicit-radius-normalization' : 'matching-geometry';
       }
     } else {
       const source = parse.path(expanded(current.options.pathData));
       assert(source.isOk());
       row.actual = serialize.path_with(source[0], serialize.minifying_options(current.options.precision ?? 3));
       const roundtrip = parse.path(row.actual);
       assert(roundtrip.isOk());
       const independentlyDecoded = parse.path(expanded(upstream.parsePathData(row.actual)));
       assert(independentlyDecoded.isOk());
       equalGeometry(JSON.parse(normalize(roundtrip[0])), JSON.parse(normalize(independentlyDecoded[0])));
       assert.equal(serialize.path_with(roundtrip[0], serialize.minifying_options(current.options.precision ?? 3)), row.actual);
       row.classification = 'geometry-model-versus-command-list-serialization';
     }
     rows.push(row);
   };
   return { toBe: check, toStrictEqual: check };
 }
};
const source = fs.readFileSync(new URL('upstream/lib/path.test.js', root), 'utf8').replace(/^import .*;\n/gm, '');
vm.runInNewContext(source, context, { timeout: 5000 });
fs.writeFileSync(new URL('path-units.json', root), JSON.stringify(rows, null, 2) + '\n');
console.log(`${new Set(rows.map(r => r.test)).size} tests; ${rows.length} assertions verified and adapted`);
