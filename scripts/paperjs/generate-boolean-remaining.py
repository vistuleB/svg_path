"""Preserve native diagnostic reproductions, without asserting errors as correct."""
from pathlib import Path
from decimal import Decimal
import json, math
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/booleans.json').read_text())['fixtures']
screen=json.loads((root/'scripts/paperjs/boolean-screening-after-vertex-join.json').read_text())
ids=[x['id'] for x in screen['results'] if x['status']=='library-error']
def n(x):
 s=format(Decimal(repr(float(x))),'f');return s if '.' in s else s+'.0'
def path(g):
 if g is None:return 'svg_path.path_empty()'
 out=[]
 for p in g['subpaths']:
  if not p['curves']:continue
  curves=['svg_path.CubicBezier('+','.join(f'svg_path.Point({n(c[i])},{n(c[i+1])})' for i in [0,2,4,6])+')' for c in p['curves']]
  s='svg_path.subpath_assert(['+','.join(curves)+'])'
  if p['closed']:s+=' |> svg_path.subpath_assert_close'
  out.append(s+' |> svg_path.subpath_as_path')
 return 'svg_path.path_combine(['+','.join(out)+'])'
out=['''// Diagnostic inputs adapted from pinned Paper.js; MIT license in
// scripts/paperjs/upstream/LICENSE.txt. Errors are printed, not asserted correct.
import gleam/io
import gleam/result
import gleam/string
import svg_path
import svg_path/csg
pub fn main() {''']
for id in ids:
 f=fixtures[id];assert f['right'] is None or f['left']['fillRule']==f['right']['fillRule']
 for g in [f['left'],f['right']]:
  if g is None:continue
  for p in g['subpaths']:
   assert all(math.isfinite(value) for c in p['curves'] for value in c)
   for a,b in zip(p['curves'],p['curves'][1:]+(p['curves'][:1] if p['closed'] else [])):assert a[6:]==b[:2]
 method={'unite':'union_path','intersect':'intersection_path','subtract':'difference_path','exclude':'symmetric_difference_path','resolveCrossings':'union_path'}[f['op']]
 out.extend([f'io.println("Fixture {id}")',f'let left = {path(f["left"])}',f'let right = {path(f["right"])}',f'csg.{method}(left,right,svg_path.'+('EvenOdd' if f['left']['fillRule']=='evenodd' else 'Nonzero')+') |> result.map(fn(_) { Nil }) |> string.inspect |> io.println'])
out.append('}')
(root/'test_paperjs/src/paper_boolean_remaining_probe.gleam').write_text('\n'.join(out))
print(f'Validated finite controls and exact declared continuity/closure for {len(ids)} saved operand pairs')
