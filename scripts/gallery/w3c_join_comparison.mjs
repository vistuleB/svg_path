// Reproduce W3C source geometry through the public stroke API.
// Reference SVGs are unchanged downloads; only their display IDs are prefixed.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import * as s from '../../examples/public_api_smoke/build/dev/javascript/svg_path/svg_path.mjs';
import * as parse from '../../examples/public_api_smoke/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as stroke from '../../examples/public_api_smoke/build/dev/javascript/svg_path/svg_path/stroke.mjs';
import * as serialize from '../../examples/public_api_smoke/build/dev/javascript/svg_path/svg_path/serialize.mjs';
const outputDir=pathToFileURL(resolve(process.argv[2] ?? 'test/generated/gallery')+'/');
await mkdir(outputDir,{recursive:true});
const ok=r=>{if(!r.isOk()) throw r; return r[0];};
const source=d=>[...s.path_subpaths(ok(parse.path(d)))][0];
const fmt=serialize.decimal_options(10);
const draw=(p,transform='')=>`<path transform="${transform}" d="${serialize.path_with(p,fmt)}" fill="none" stroke="#1565ff" stroke-width="1.4"/>`;
const output=(sub,width,join)=>ok(stroke.subpath(sub,width,join,new stroke.Butt()));
function reference(raw,prefix,w,h,x,y,width,height,opacity=1){
  let body=raw.replace(/^[\s\S]*?<svg\b[^>]*>/,'').replace(/<\/svg>\s*$/,'');
  const ids=[...body.matchAll(/id="([^"]+)"/g)].map(m=>m[1]);
  for(const id of ids) body=body.replaceAll(`id="${id}"`,`id="${prefix}${id}"`).replaceAll(`#${id}"`,`#${prefix}${id}"`).replaceAll(`#${id})`,`#${prefix}${id})`);
  // Avoid reference style sheets affecting the surrounding comparison labels.
  body=body.replace(/text \{/g,`.${prefix} text {`).replace(/circle \{/g,`.${prefix} circle {`);
  return `<svg x="${x}" y="${y}" width="${width}" height="${height}" viewBox="0 0 ${w} ${h}" opacity="${opacity}" xmlns:xlink="http://www.w3.org/1999/xlink"><g class="${prefix}">${body}</g></svg>`;
}
const records=[];
for(const [file,title] of [['linejoin-construction-fallback.svg','Arcs: nested continuation circles'],['linejoin-construction-fallback2.svg','Arcs: disjoint continuation circles'],['linejoin-construction-fallback3.svg','Arcs: parallel tangents (intentional Round fallback)']]){
  const raw=await readFile(new URL(`w3c-join-reference/${file}`,import.meta.url),'utf8');
  const d=raw.match(/<path style="fill:none;stroke:#444;stroke-width:40px"\s+d="([^"]+)"/)[1];
  // The illustration draws the two pieces separately. Join their coincident
  // endpoints by removing the zero-displacement moveto, changing no coordinates.
  const sub=source(d.replace(/m\s+0,0/g,''));
  const result=output(sub,40,new stroke.Arcs(file.includes('fallback3')?5:100));
  records.push({file,subpaths:[...s.path_subpaths(result)].length,bounds:ok(s.path_bounding_box(result))});
  const panels=reference(raw,'left',500,250,10,70,500,250)+reference(raw,'right',500,250,530,70,500,250,0.45)+`<svg x="530" y="70" width="500" height="250" viewBox="0 0 500 250">${draw(result)}</svg>`;
  await writeFile(new URL(`w3c-${file}`,outputDir),`<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="360" viewBox="0 0 1040 360"><rect x="0" y="0" width="1040" height="360" fill="white"/><g font-family="sans-serif" fill="#333"><text x="20" y="25" font-size="18">${title}</text><text x="20" y="55">W3C illustration</text><text x="540" y="55">Same illustration + computed outline (blue)</text>${panels}<text x="20" y="345" font-size="12">Original W3C viewport retained; width 40, Butt caps. Pink reference outlines and circle guides are rounded approximations.</text></g></svg>`);
}
const raw=await readFile(new URL('w3c-join-reference/miter-limit.svg',import.meta.url),'utf8');
const sub=source('M25,60 L175,90 L25,120');
const miter=output(sub,35,new stroke.Miter(3));
const clip=output(sub,35,new stroke.MiterClip(3));
const maxX=ok(s.path_bounding_box(clip)).max.x;
assert(Math.abs(maxX-227.5)<1e-9);
records.push({file:'miter-limit.svg',expectedMaxX:227.5,actualMaxX:maxX});
await writeFile(new URL('w3c-miter-limit.svg',outputDir),`<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="690" viewBox="0 0 1000 690"><rect x="0" y="0" width="1000" height="690" fill="white"/><text x="20" y="25" font-family="sans-serif" font-size="18">Miter limit 3 — W3C reference (top), computed blue overlay (bottom)</text>${reference(raw,'top',600,180,20,40,960,288)}${reference(raw,'bottom',600,180,20,360,960,288,0.45)}<svg x="20" y="360" width="960" height="288" viewBox="0 0 600 180">${draw(miter)}${draw(clip,'translate(300 0)')}</svg></svg>`);
console.log(JSON.stringify(records,null,2));
