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

// This probe compares command choices using one shared encoder. It does not
// reproduce arc-flag packing or promise the library's exact numeric spelling.
function encode(commands, search) {
  let states = [{ text: '', previous: '' }];
  for (const c of commands) {
    const candidates = [c];
    if (search && c.command === 'h') candidates.push({command:'l', args:[c.args[0],0]});
    if (search && c.command === 'v') candidates.push({command:'l', args:[0,c.args[0]]});
    const next = new Map();
    for (const state of states) for (const candidate of candidates) {
      const name = candidate.command;
      let chunk = name === state.previous && !/[mz]/i.test(name) ? '' : name;
      for (const n of candidate.args) {
        const token = String(n).replace(/^(-?)0\./, '$1.');
        // Conservative separators shared by both sides of this experiment.
        if ((chunk || state.text) && !/[a-z]$/i.test(chunk || state.text) && !token.startsWith('-')) chunk += ' ';
        chunk += token;
      }
      const previous = name === 'm' ? 'l' : name;
      const value = {text:state.text + chunk, previous};
      if (!next.has(previous) || value.text.length < next.get(previous).text.length) next.set(previous,value);
    }
    states = [...next.values()];
  }
  return states.reduce((a,b) => a.text.length <= b.text.length ? a:b).text;
}
const results = [];
for (const fixture of baseline.results) {
  const options = serialize.minifying_options(fixtures.find(f => f.file === fixture.file).params.floatPrecision ?? 3);
  for (const entry of fixture.cases) {
    if (entry.actual === undefined) continue;
    let geometry = parse.path(entry.source)[0];
    if (entry.flattenedTransform) geometry = transform.path(path.path_normalize_svg_arcs(geometry), transformParse.attribute(entry.flattenedTransform)[0])[0];
    const relative = serialize.path_with(geometry, options);
    const absolute = serialize.path_with(geometry, {...options, relative:false});
    assert(parse.path(absolute).isOk());
    const absoluteExpanded = parsePathData(absolute).map(c => c.command + c.args.join(' ')).join(' ');
    equivalent(parse.path(absolute), parse.path(absoluteExpanded), fixture.file);
    const commands = parsePathData(relative);
    const original = encode(commands, false), optimized = encode(commands, true);
    equivalent(parse.path(relative), parse.path(original), fixture.file);
    equivalent(parse.path(original), parse.path(optimized), fixture.file);
    const expanded = parsePathData(optimized).map(c => c.command + c.args.join(' ')).join(' ');
    equivalent(parse.path(original), parse.path(expanded), fixture.file);
    results.push({fixture:fixture.file, number:entry.number, relativeBytes:relative.length,
      absoluteBytes:absolute.length, wholePathSaved:Math.max(0,relative.length-absolute.length),
      runSaved:original.length-optimized.length,
      ...(original !== optimized ? {original,optimized}: {})});
  }
}
const summary = { checked:results.length,
  wholePathSaved:results.reduce((n,r)=>n+r.wholePathSaved,0),
  wholePathImproved:results.filter(r=>r.wholePathSaved>0).length,
  runSaved:results.reduce((n,r)=>n+r.runSaved,0),
  runImproved:results.filter(r=>r.runSaved>0).length };
fs.writeFileSync(new URL('policy-experiments.json',import.meta.url),JSON.stringify({summary,results},null,2)+'\n');
console.log(summary);
