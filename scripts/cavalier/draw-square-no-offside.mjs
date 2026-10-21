// Recompute the four Gallery square offsets with only offside trimming disabled.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]};
const source=ok(g.subpath_polygon(toList([[-1,-1],[1,-1],[1,1],[-1,1]].map(([x,y])=>new g.Point(x,y)))));
const trimming=new off.SingleOffsetTrimming(false,new off.InBandTrimming());
const svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="380" viewBox="0 0 1120 380">','<rect x="0" y="0" width="1120" height="380" fill="white"/>','<text x="560" y="28" text-anchor="middle" font-family="sans-serif" font-size="21">Square inward offsets — offside disabled, in-band enabled</text>'];
const rows=[];
const far = process.argv.includes('--2.5');
if(far) svg.splice(0,svg.length,
 '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="430" viewBox="0 0 800 430">',
 '<rect x="0" y="0" width="800" height="430" fill="white"/>',
 '<text x="400" y="30" text-anchor="middle" font-family="sans-serif" font-size="21">Square inward offset — distance 2.5</text>');
for(const [i,distance] of (far ? [2.5,2.5] : [.5,1,1.5,2]).entries()){
 const raw=ok(off.subpath_untrimmed(source,-distance,new off.Round()));
 const result=ok(off.subpath_with(source,-distance,new off.Round(),new off.Butt(),off.default_options(),far && i===0 ? new off.SingleOffsetTrimming(true,new off.InBandTrimming()) : trimming));
 const baseline=ok(off.subpath(source,-distance,new off.Round(),new off.Butt()));
 const d=serialize.path(result),baselineD=serialize.path(baseline);
 rows.push({distance,subpaths:Array.from(result.subpaths).length,svg:d,identicalToDefault:d===baselineD});
 const center=far ? 200+400*i : 140+280*i;
 svg.push(`<text x="${center}" y="64" text-anchor="middle" font-family="sans-serif" font-size="18">${far ? (i===0 ? "Offside + in-band" : "In-band only") : "Inward distance "+distance}</text>`,`<g transform="translate(${center} ${far ? 220 : 197}) scale(${far ? 82 : 85})">`,`<path d="${serialize.subpath(source)}" fill="none" stroke="#94a3b8" stroke-width="0.015"/>`,`<path d="${serialize.subpath(raw)}" fill="none" stroke="#e2a665" stroke-width="0.016"/>`,`<path d="${d}" fill="none" stroke="#164eae" stroke-width="0.04"/>`,'</g>',`<text x="${center}" y="${far ? 376 : 323}" text-anchor="middle" font-family="sans-serif" font-size="14">${Array.from(result.subpaths).length} output contour(s)</text>`);
}
svg.push(`<text x="${far ? 400 : 560}" y="${far ? 412 : 357}" text-anchor="middle" font-family="sans-serif" font-size="15">Gray: source square · Orange: raw offset · Blue: in-band-only trimmed output</text>`,'</svg>');
fs.writeFileSync(new URL(far ? '../../examples/debug/square-inward-2-5.svg' : '../../examples/debug/square-inward-no-offside.svg',import.meta.url),svg.join('\n')+'\n');
fs.writeFileSync(new URL(far ? './square-2-5-preview.json' : './square-no-offside-preview.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
console.log(JSON.stringify(rows,null,2));
