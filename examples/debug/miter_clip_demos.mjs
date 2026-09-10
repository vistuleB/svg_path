// Run after: (cd examples/public_api_smoke && gleam build --target javascript)
// All outlines come from the public stroke API. No SVG stroke-linejoin is used
// to stand in for computed geometry.
import {writeFile} from 'node:fs/promises';
import * as s from '../public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import * as stroke from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/stroke.mjs';
import * as serialize from '../public_api_smoke/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import {toList} from '../public_api_smoke/build/dev/javascript/gleam_stdlib/gleam.mjs';

const ok = r => {if (!r.isOk()) throw r; return r[0];};
const source = s.subpath_assert_polyline(toList([
  new s.Point(-6,10), new s.Point(0,0), new s.Point(6,10),
]));
const fmt = serialize.decimal_options(10);
const sourceData = serialize.subpath_with(source, fmt);
const width = 2;

async function figure(filename, title, cases) {
  const results = cases.map(([label, join]) => {
    const path = ok(stroke.subpath(source, width, join, new stroke.Butt()));
    return {label, path, box:ok(s.path_bounding_box(path))};
  });
  // One common scale, but recenter each panel from its actual geometry bounds.
  const maxWidth = Math.max(...results.map(({box:b})=>b.max.x-b.min.x));
  const maxHeight = Math.max(...results.map(({box:b})=>b.max.y-b.min.y));
  const cell = 320, H = 430, W = cell * cases.length;
  const scale = Math.min((cell-42)/maxWidth, (H-120)/maxHeight);
  const drawing = results.map(({label,path,box:b},i)=> {
    const cx=(b.min.x+b.max.x)/2, cy=(b.min.y+b.max.y)/2;
    return `<text x="${cell*(i+.5)}" y="80" text-anchor="middle">${label}</text>
<g transform="translate(${cell*(i+.5)} 250) scale(${scale}) translate(${-cx} ${-cy})">
<path d="${serialize.path_with(path,fmt)}" fill="#9573dc" fill-opacity="0.3" stroke="#7343de" stroke-width="${1/scale}"/>
<path d="${sourceData}" fill="none" stroke="#666" stroke-width="${.85/scale}"/>
<circle cx="0" cy="0" r="${2/scale}" fill="#222"/>
</g>`;
  }).join('\n');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect x="0" y="0" width="${W}" height="${H}" fill="white"/>
<g font-family="sans-serif" font-size="15" fill="#333">
<text x="${W/2}" y="30" text-anchor="middle" font-size="19">${title}</text>
${drawing}
<text x="${W/2}" y="417" text-anchor="middle" font-size="12">Gray: source · purple: computed stroke outline · width 2 · Butt caps · common scale</text>
</g></svg>`;
  await writeFile(new URL(filename, import.meta.url),svg);
  console.log(filename, results.map(r=>({style:r.label,subpaths:[...s.path_subpaths(r.path)].length})));
}

await figure('miter_clip_comparison.svg','Miter versus clipped miter',[
  ['Miter(4)', new stroke.Miter(4)],
  ['Miter(1.5)', new stroke.Miter(1.5)],
  ['MiterClip(1.5)', new stroke.MiterClip(1.5)],
  ['Round', new stroke.Round()],
]);
await figure('miter_clip_limits.svg','MiterClip: varying the limit',[
  ['MiterClip(0.5)', new stroke.MiterClip(.5)],
  ['MiterClip(1)', new stroke.MiterClip(1)],
  ['MiterClip(1.5)', new stroke.MiterClip(1.5)],
  ['MiterClip(2)', new stroke.MiterClip(2)],
]);
