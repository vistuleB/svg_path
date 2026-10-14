import fs from 'node:fs';
import * as p from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import * as t from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
import * as tp from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/parse.mjs';
const root = new URL('./', import.meta.url);
const fixtures = JSON.parse(fs.readFileSync(new URL('fixtures.json', root)));
function distance(a, b) {
  let maximum = 0;
  const aa = [...p.path_subpaths(a)], bb = [...p.path_subpaths(b)];
  if (aa.length !== bb.length) throw Error('Subpath mismatch');
  for (let i = 0; i < aa.length; i++) {
    const sa = [...p.subpath_segments(aa[i])], sb = [...p.subpath_segments(bb[i])];
    if (sa.length !== sb.length) throw Error('Segment mismatch');
    for (let j = 0; j < sa.length; j++) for (let k = 0; k <= 512; k++) {
      const x = p.segment_point(sa[j], k / 512), y = p.segment_point(sb[j], k / 512);
      if (!x.isOk() || !y.isOk()) throw Error('Evaluation failed');
      maximum = Math.max(maximum, Math.hypot(x[0].x - y[0].x, x[0].y - y[0].y));
    }
  }
  return maximum;
}
const rows = [];
for (const n of [18, 19, 21, 22, 24]) {
  const fixture = fixtures[10], input = fixture.inputs[n - 1];
  const original = parse.path(input.d)[0];
  const matrix = tp.attribute(input.transform)[0];
  const result = t.path(original, matrix);
  if (!result.isOk()) throw Error('Transform failed');
  const transformed = result[0];
  const variants = [];
  for (const precision of [3, 5, 8, 12]) {
    const options = s.minifying_options(precision);
    const output = s.path_with(transformed, options);
    const reparsed = parse.path(output);
    if (!reparsed.isOk()) throw Error('Parse failed');
    variants.push({ precision, output, maximumSampledParameterDifference: distance(transformed, reparsed[0]) });
  }
  rows.push({ case: `11:${n}`, variants });
}
fs.writeFileSync(new URL('numerical-probes.json', root), JSON.stringify(rows, null, 2) + '\n');
console.log(JSON.stringify(rows, null, 2));
