"""Preserve native diagnostic reproductions, without asserting errors as correct."""
from pathlib import Path
from decimal import Decimal
import json, math
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/booleans.json').read_text())['fixtures']
ids=[69,79,104,113,122,123,136,137,172]
def n(x):
 s=format(Decimal(repr(float(x))),'f');return s if '.' in s else s+'.0'
def path(g):
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
 f=fixtures[id];assert not f.get('derivedLeft') and not f.get('derivedRight');assert f['left']['fillRule']==f['right']['fillRule']
 for g in [f['left'],f['right']]:
  for p in g['subpaths']:
   assert p['closed']
   assert all(math.isfinite(value) for c in p['curves'] for value in c)
   for a,b in zip(p['curves'],p['curves'][1:]+p['curves'][:1]):assert a[6:]==b[:2]
 method={'unite':'union_path','intersect':'intersection_path','subtract':'difference_path'}[f['op']]
 out.extend([f'io.println("Fixture {id}")',f'let left = {path(f["left"])}',f'let right = {path(f["right"])}',f'csg.{method}(left,right,svg_path.'+('EvenOdd' if f['left']['fillRule']=='evenodd' else 'Nonzero')+') |> result.map(fn(_) { Nil }) |> string.inspect |> io.println'])
out.append('}')
(root/'test_paperjs/src/paper_boolean_failures.gleam').write_text('\n'.join(out))
print('Validated exact continuity and closure for nine pairs of source operands')
