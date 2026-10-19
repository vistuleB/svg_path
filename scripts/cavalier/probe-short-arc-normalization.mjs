import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as deg from '../../test_portable/build/dev/javascript/svg_path/svg_path/degeneracy.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const p=(x,y)=>new g.Point(x,y), rows=[];
const encode=r=>r.isOk()?{ok:true,segments:Array.from(g.subpath_segments(r[0]),s=>({type:s.constructor.name,...s}))}:{ok:false,error:{type:r[0].constructor.name,...r[0]}};
function check(name,arc){
 const alone=g.subpath(toList([arc]))[0];
 const source=g.subpath(toList([new g.Line(p(arc.start.x-1,arc.start.y),arc.start),arc,new g.Line(arc.end,p(arc.end.x,arc.end.y+1))]))[0];
 rows.push({name,arc:{...arc},alone:encode(deg.normalize_degenerate_segments(alone,.001)),short_run:encode(off.normalize_short_source_runs(source,.001)),offset:(()=>{const r=off.subpath(source,.1,new off.Round(),new off.Butt());return r.isOk()?{ok:true}:{ok:false,error:{type:r[0].constructor.name,...r[0]}}})()});
}
for(const radius of [1,10,100])check(`radius ${radius}`,new g.Arc(p(0,0),p(radius,radius),0,false,true,p(.00003,0)));
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
for(const id of ['CC01160','CC01292']){
 const c=cases.find(x=>x.id===id),a=c.input.vertices[1],b=c.input.vertices[2],r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+a[2]*a[2])/(4*Math.abs(a[2]));
 check(id,new g.Arc(p(...a),p(r,r),0,false,a[2]>0,p(...b)));
}
console.log(JSON.stringify(rows,null,2));
