import fs from 'node:fs';
import * as g from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path.mjs';
import * as off from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/offset.mjs';
import {toList} from '/tmp/cavalier-near-tangent-offset-trace/prelude.mjs';
const encode=x=>x===null||typeof x!=='object'?x:Array.isArray(x)?x.map(encode):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))};
const c=JSON.parse(fs.readFileSync(new URL('./near-tangent-offset-cases.json',import.meta.url))).find(c=>c.id===(process.env.AUDIT_CASE_ID??'CC01267'));
const vs=c.input.vertices,segments=vs.slice(0,-1).map((a,i)=>{const b=vs[i+1],p=new g.Point(a[0],a[1]),q=new g.Point(b[0],b[1]);if(!a[2])return new g.Line(p,q);const r=Math.hypot(q.x-p.x,q.y-p.y)*(1+a[2]*a[2])/(4*Math.abs(a[2]));return new g.Arc(p,new g.Point(r,r),0,Math.abs(a[2])>1,a[2]>0,q);});
const source=g.subpath(toList(segments))[0],rows=[];
for(const mode of (process.env.AUDIT_ONE_MODE ? [process.env.AUDIT_ONE_MODE] : ['untrimmed','none','cusp','in-band'])){
 globalThis.auditErrors=[];globalThis.auditArcs=[];globalThis.auditBetween=[];globalThis.auditVertexTrace=[];
 const r=mode==='untrimmed'?off.subpath_untrimmed(source,-c.offset,new off.Round()):off.subpath_with(source,-c.offset,new off.Round(),new off.Butt(),off.default_options(),new off.SingleOffsetTrimming(false,mode==='none'?new off.NoTrimming():mode==='cusp'?new off.CuspTrimming():new off.InBandTrimming()));
 rows.push({mode,result:r.isOk()?{ok:true}:{ok:false,error:encode(r[0])},trace:encode(globalThis.auditErrors),arcs:encode(globalThis.auditArcs),between:encode(globalThis.auditBetween),vertices:encode(globalThis.auditVertexTrace)});
}
console.log(JSON.stringify(rows,null,2));
