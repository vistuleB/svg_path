import fs from 'node:fs';
import * as g from '/tmp/cavalier-tangent-instrumented/svg_path/svg_path.mjs';
import * as off from '/tmp/cavalier-tangent-instrumented/svg_path/svg_path/offset.mjs';
import {toList} from '/tmp/cavalier-tangent-instrumented/prelude.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./remaining-construction-cases.json',import.meta.url)));
const c=cases.find(c=>c.id==='CC01645');
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const vertices=c.input.vertices;
const lines=vertices.map((v,i)=>new g.Line(new g.Point(v[0],v[1]),new g.Point(...vertices[(i+1)%vertices.length].slice(0,2))));
const source=unwrap(g.subpath_close(unwrap(g.subpath(toList(lines)))));
const started=performance.now();
const result=unwrap(off.path(new g.Path(toList([source])),-c.offset,new off.Round(),new off.Butt()));
const encode=x=>x===null||typeof x!=='object'?x:Array.isArray(x)?x.map(encode):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))};
console.log(JSON.stringify({id:c.id,milliseconds:performance.now()-started,source:c.input,offset:c.offset,contours:[...result.subpaths].map(s=>({closed:g.subpath_is_closed(s),segments:[...g.subpath_segments(s)].map(seg=>({segment:encode(seg),center:seg instanceof g.Arc?encode(unwrap(g.arc_center_data(seg))):null}))}))},null,2));

console.error(JSON.stringify({timing:globalThis.auditTiming,slowPairs:globalThis.auditSlowPairs},null,2));
