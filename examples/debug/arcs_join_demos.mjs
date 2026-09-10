// Build examples/public_api_smoke for JavaScript, then run this file with Node.
// Every purple outline comes from stroke.subpath; no browser stroke join is used.
import {writeFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import * as stroke from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/stroke.mjs';
import * as serialize from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';
const ok = r => {if (!r.isOk()) throw r; return r[0];};
const P = (x,y)=>new s.Point(x,y);
const fmt = serialize.decimal_options(10);
const cases = [['MiterClip(4)',new stroke.MiterClip(4)],['Round',new stroke.Round()],['Arcs(4)',new stroke.Arcs(4)],['Arcs(1.1)',new stroke.Arcs(1.1)]];
const sources = [
  ['Unequal source curvatures',s.subpath_assert(toList([
    new s.Arc(P(-3,3),P(3,3),0,false,true,P(0,0)),
    new s.Arc(P(0,0),P(5,5),0,false,true,P(-1,3)),
  ]))],
  ['Continuation circles initially disjoint',s.subpath_assert(toList([
    new s.Arc(P(-3,-3),P(3,3),0,false,false,P(0,0)),
    new s.Arc(P(0,0),P(3,3),0,false,false,P(3,3)),
  ]))],
  ['Unequal source curvatures — original self-intersecting example',s.subpath_assert(toList([
    new s.Arc(P(-3,3),P(3,3),0,false,true,P(0,0)),
    new s.Arc(P(0,0),P(5,5),0,false,true,P(-5,5)),
  ]))],
];
for (const [row,[title,source]] of sources.entries()) {
  const results = cases.map(([label,join])=> {
    const path=ok(stroke.subpath(source,2,join,new stroke.Butt()));
    return {label,path,b:ok(s.path_bounding_box(path))};
  });
  const sourceBox=ok(s.subpath_bounding_box(source));
  // Include source and resulting geometry in each independently centered panel.
  for(const r of results) r.b={min:P(Math.min(r.b.min.x,sourceBox.min.x),Math.min(r.b.min.y,sourceBox.min.y)),max:P(Math.max(r.b.max.x,sourceBox.max.x),Math.max(r.b.max.y,sourceBox.max.y))};
  const scale=Math.min(270/Math.max(...results.map(r=>r.b.max.x-r.b.min.x)),290/Math.max(...results.map(r=>r.b.max.y-r.b.min.y)));
  const panels=results.map(({label,path,b},i)=>`<text x="${320*i+160}" y="75" text-anchor="middle">${label}</text><g transform="translate(${320*i+160} 245) scale(${scale}) translate(${-0.5*(b.min.x+b.max.x)} ${-0.5*(b.min.y+b.max.y)})"><path d="${serialize.path_with(path,fmt)}" fill="#9573dc" fill-opacity="0.3" stroke="#7343de" stroke-width="${1/scale}"/><path d="${serialize.subpath_with(source,fmt)}" fill="none" stroke="#666" stroke-width="${0.85/scale}"/><circle cx="0" cy="0" r="${2/scale}" fill="#222"/></g>`).join('\n');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="430" viewBox="0 0 1280 430"><rect x="0" y="0" width="1280" height="430" fill="white"/><g font-family="sans-serif" font-size="15" fill="#333"><text x="640" y="30" text-anchor="middle" font-size="19">${title}</text>${panels}<text x="640" y="418" font-size="12" text-anchor="middle">Gray: source · purple: computed stroke · width 2 · Butt caps · common scale</text></g></svg>`;
  const file=row===2 ? 'arcs_join_self_intersection.svg' : `arcs_join_comparison_${row+1}.svg`;
  await writeFile(new URL(file,import.meta.url),svg);
  console.log(file,results.map(r=>({join:r.label,subpaths:[...s.path_subpaths(r.path)].length})));
}
