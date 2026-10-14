import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { optimize } from 'svgo';
import { parsePathData } from './node_modules/svgo/lib/path.js';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import * as transform from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
import * as transformParse from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/parse.mjs';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';

const root = new URL('./', import.meta.url);
const fixtures = JSON.parse(fs.readFileSync(new URL('fixtures.json', root)));
const provenance = JSON.parse(fs.readFileSync(new URL('provenance.json', root)));
for (const file of provenance.files) {
  const bytes = fs.readFileSync(new URL(`upstream/${file.path}`, root));
  if (createHash('sha256').update(bytes).digest('hex') !== file.sha256) throw Error(`Source hash mismatch: ${file.path}`);
}
for (const file of ['plugins/convertPathData.js', 'plugins/_path.js']) {
  if (!fs.readFileSync(new URL(`upstream/${file}`, root)).equals(fs.readFileSync(new URL(`node_modules/svgo/${file}`, root)))) throw Error(`Installed SVGO source mismatch: ${file}`);
}
const results = [];
const review = JSON.parse(fs.readFileSync(new URL('review.json', root)));
// Parameter-matched sampling is only used when subpath and segment counts match.
// It is a diagnostic, not a Hausdorff bound or a proof of geometric equivalence.
function sampleDifference(a, b) {
  const aa = [...path.path_subpaths(path.path_normalize_svg_arcs(a))], bb = [...path.path_subpaths(path.path_normalize_svg_arcs(b))];
  if (aa.length !== bb.length) return null;
  let maximum = 0;
  for (let i = 0; i < aa.length; i++) {
    const as = [...path.subpath_segments(aa[i])], bs = [...path.subpath_segments(bb[i])];
    if (as.length !== bs.length || path.subpath_is_closed(aa[i]) !== path.subpath_is_closed(bb[i])) return null;
    const startA = path.subpath_start(aa[i]), startB = path.subpath_start(bb[i]);
    maximum = Math.max(maximum, Math.hypot(startA.x - startB.x, startA.y - startB.y));
    for (let j = 0; j < as.length; j++) for (let k = 0; k <= 16; k++) {
      const pa = path.segment_point(as[j], k / 16), pb = path.segment_point(bs[j], k / 16);
      if (!pa.isOk() || !pb.isOk()) throw Error('Sample evaluation failed');
      maximum = Math.max(maximum, Math.hypot(pa[0].x - pb[0].x, pa[0].y - pb[0].y));
    }
  }
  return maximum;
}
function transformedDifference(source, target, matrix) {
  const a = [...path.path_subpaths(source)], b = [...path.path_subpaths(target)];
  if (a.length !== b.length) throw Error('Transformed subpath count differs');
  let maximum = 0;
  for (let i = 0; i < a.length; i++) {
    const sa = [...path.subpath_segments(a[i])], sb = [...path.subpath_segments(b[i])];
    if (sa.length !== sb.length) throw Error('Transformed segment count differs');
    for (let j = 0; j < sa.length; j++) for (let k = 0; k <= 16; k++) {
      const pa = path.segment_point(sa[j], k / 16), pb = path.segment_point(sb[j], k / 16);
      if (!pa.isOk() || !pb.isOk()) throw Error('Transform sampling failed');
      const mapped = transform.point(pa[0], matrix);
      maximum = Math.max(maximum, Math.hypot(mapped.x - pb[0].x, mapped.y - pb[0].y));
    }
  }
  return maximum;
}
for (const fixture of fixtures) {
  let input = fixture.original;
  const passes = [];
  for (let pass = 0; pass < 2; pass++) {
    input = optimize(input, { plugins: [{ name: 'convertPathData', params: fixture.params }], js2svg: { pretty: true } }).data;
    passes.push(input.trim() === fixture.expected.trim());
  }
  if (passes.some(ok => !ok)) throw Error(`Upstream fixture mismatch: ${fixture.file}`);
  if (fixture.inputs.length !== fixture.outputs.length) throw Error('Path count changed');
  const options = serialize.minifying_options(fixture.params.floatPrecision ?? 3);
  const cases = fixture.inputs.map((attributes, i) => {
    const source = attributes.d, expected = fixture.outputs[i].d;
    const parsed = parse.path(source);
    if (!parsed.isOk() && !(fixture.file === 'convertPathData.01.svg.txt' && i === 14)) throw Error(`Unexpected parse failure: ${fixture.file}:${i + 1}`);
    if (!parsed.isOk()) return { number: i + 1, source, expected, attributes, classification: 'invalid-input-pass-through', parseError: parsed[0].constructor.name };
    // Follow the fixture's flatten/retain decision, not a new SVG-style policy.
    const flattenedTransform = attributes.transform && !fixture.outputs[i].transform ? attributes.transform : null;
    let geometry = parsed[0];
    let transformSampledDifference = null;
    if (flattenedTransform) {
      const matrix = transformParse.attribute(flattenedTransform);
      if (!matrix.isOk()) throw Error('Transform parse failed');
      const normalized = path.path_normalize_svg_arcs(geometry);
      const transformed = transform.path(normalized, matrix[0]);
      if (!transformed.isOk()) throw Error(`Transform failed ${fixture.file}:${i + 1}: ${JSON.stringify(transformed)}`);
      geometry = transformed[0];
      transformSampledDifference = transformedDifference(normalized, geometry, matrix[0]);
    }
    const actual = serialize.path_with(geometry, options);
    const reparsed = parse.path(actual), expectedParsed = parse.path(expected);
    if (!reparsed.isOk() || !expectedParsed.isOk()) throw Error('Valid output failed parsing');
    // A second parser expands compact tokens into explicit commands/numbers.
    // Compare complete parsed geometry, not merely whether a prefix was accepted.
    const expanded = parsePathData(actual).map(item => item.command + item.args.join(' ')).join(' ');
    const independentlyParsed = parse.path(expanded);
    const independentParserMatches = independentlyParsed.isOk() && JSON.stringify(independentlyParsed[0]) === JSON.stringify(reparsed[0]);
    if (!independentParserMatches) throw Error(`Independent parser mismatch ${fixture.file}:${i + 1}`);
    return { number: i + 1, source, expected, actual, attributes, flattenedTransform, transformSampledDifference, independentParserMatches,
      inputBytes: Buffer.byteLength(source), svgoBytes: Buffer.byteLength(expected), ourBytes: Buffer.byteLength(actual),
      sameText: actual === expected,
      stable: serialize.path_with(reparsed[0], options) === actual,
      ourSampledDifference: sampleDifference(geometry, reparsed[0]),
      svgoSampledDifference: sampleDifference(geometry, expectedParsed[0]),
      classification: review[`${fixture.file.slice(16,18)}:${i + 1}`] ?? (actual === expected ? 'identical' : actual.slice(1) === expected.slice(1) ? 'initial-move-case-only' : 'UNREVIEWED') };
  });
  results.push({ file: fixture.file, upstreamPasses: passes, cases });
}
if (!process.argv.includes('--explore') && results.some(f => f.cases.some(c => c.classification === 'UNREVIEWED'))) throw Error('Unreviewed difference');
fs.writeFileSync(new URL('all-fixtures.json', root), JSON.stringify({ version: provenance.version, revision: provenance.revision, results }, null, 2) + '\n');
fs.writeFileSync(new URL('first-batch.json', root), JSON.stringify({ version: provenance.version, revision: provenance.revision, results: results.slice(0, 5) }, null, 2) + '\n');
for (const fixture of results) for (const c of fixture.cases) console.log(`${fixture.file.slice(16,18)}:${c.number} ${c.ourBytes ?? '-'} / ${c.svgoBytes ?? '-'} ${c.sameText ? 'SAME' : 'DIFF'}\n  ours ${c.actual ?? c.parseError}\n  svgo ${c.expected}\n  sampled ${c.ourSampledDifference} / ${c.svgoSampledDifference}; stable ${c.stable}`);
