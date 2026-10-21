import * as g from '/tmp/csg-affine-focused/build/dev/javascript/svg_path/svg_path.mjs';
import {adjust_with_tolerance} from '/tmp/csg-affine-focused/build/dev/javascript/svg_path/svg_path/internal/arc_reconstruction.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]},dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const rows=[];
for(const [rx,ry] of [[100,100],[100,1],[1,100]])for(const sweep of [0.00001,90,179.99999,180,270,359.99999])for(const angle of [0,37])for(const displacement of [1e-7,-1e-7]){
 const rad=x=>x*Math.PI/180,a=rad(angle);
 const p=t=>new g.Point(rx*Math.cos(rad(t))*Math.cos(a)-ry*Math.sin(rad(t))*Math.sin(a),rx*Math.cos(rad(t))*Math.sin(a)+ry*Math.sin(rad(t))*Math.cos(a));
 const source=new g.Arc(p(0),new g.Point(rx,ry),angle,sweep>180,true,p(sweep));
 const start=new g.Point(source.start.x+displacement,source.start.y-displacement),end=new g.Point(source.end.x-displacement,source.end.y+displacement);
 const out=new g.Arc(start,source.radius,angle,source.large_arc,true,end);
 globalThis.arcChecks=[];
 const row={rx,ry,sweep,angle,displacement};
 try{
  const pieces=Array.from(ok(adjust_with_tolerance(source,start,end,1e-6)));
  row.pieces=pieces.length;
  row.outerEndpointsExact=pieces[0].start===start&&pieces.at(-1).end===end;
  row.joinsExact=pieces.every((p,i)=>i===0||(p.start.x===pieces[i-1].end.x&&p.start.y===pieces[i-1].end.y));
 }catch(e){row.error=String(e)}
 row.checks=globalThis.arcChecks;
 rows.push(row);
}
console.log(JSON.stringify(rows,null,2));
