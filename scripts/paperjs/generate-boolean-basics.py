"""Portable adaptation of upstream's 16 nested/disjoint rectangle assertions."""
import json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/booleans.json').read_text())['fixtures'][:16]
def point(p):return 'svg_path.Point('+', '.join(repr(float(x)) for x in p)+')'
def path(g):
 return 'svg_path.path_combine(['+','.join('svg_path.subpath_assert(['+','.join('svg_path.CubicBezier('+','.join(point(c[i:i+2]) for i in [0,2,4,6])+')' for c in p['curves'])+']) |> svg_path.subpath_assert_close |> svg_path.subpath_as_path' for p in g['subpaths'])+'])'
s='''// Generated from Paper.js's pinned non-crossing Boolean fixtures.
// Copyright 2011–2020 Jürg Lehni & Jonathan Puckey, MIT.
// See scripts/paperjs/upstream/LICENSE.txt and generate-boolean-basics.py.
import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/containment
import svg_path/csg
import svg_path/parse

fn check(actual: svg_path.Path, expected: svg_path.Path) {
  assert float.absolute_value(float.absolute_value(area.signed_path(actual))
    -. float.absolute_value(area.signed_path(expected))) <. 0.0000001
  list.each(svg_path.path_subpaths(actual), fn(p) {
    svg_path.subpath_is_closed(p) |> should.be_true
  })
  // One sample in every rectangular cell induced by all input boundaries,
  // including cells outside both shapes. Compare fill, not traversal order.
  list.each([-10.0, 25.0, 75.0, 125.0, 175.0, 225.0, 275.0, 325.0, 375.0], fn(x) {
    list.each([-10.0, 25.0, 75.0, 125.0, 175.0, 225.0], fn(y) {
      let p = svg_path.Point(x, y)
      let assert Ok(want) = containment.path_containment(p, expected, svg_path.Nonzero)
      let assert Ok(got) = containment.path_containment(p, actual, svg_path.Nonzero)
      got |> should.equal(want)
    })
  })
}
'''
ops={'unite':'union_path','subtract':'difference_path','intersect':'intersection_path','exclude':'symmetric_difference_path'}
for f in fixtures:
 assert f['title']=='Boolean operations without crossings' and not f['derivedLeft'] and not f['derivedRight']
 s+=f'''\npub fn paper_boolean_{f['id']:02}_test() {{
 let left = {path(f['left'])}
 let right = {path(f['right'])}
 let assert Ok(actual) = csg.{ops[f['op']]}(left, right, svg_path.Nonzero)
 let assert Ok(expected) = parse.path({json.dumps(f['expectedPathData'])})
 check(actual, expected)
}}
'''
p=root/'test/svg_path_paper_boolean_basics_test.gleam';p.write_text(s)
subprocess.run(['gleam','format',str(p)],check=True)
