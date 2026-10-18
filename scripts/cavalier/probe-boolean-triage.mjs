import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as contain from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]},P=v=>new g.Point(v[0],v[1]);
function path(input){const vs=input.vertices;const ss=vs.map((a,i)=>{const b=vs[(i+1)%vs.length],bulge=a[2];if(!bulge)return new g.Line(P(a),P(b));const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+bulge*bulge)/(4*Math.abs(bulge));return new g.Arc(P(a),new g.Point(r,r),0,Math.abs(bulge)>1,bulge>0,P(b));});return new g.Path(toList([unwrap(g.subpath_close(unwrap(g.subpath(toList(ss)))))]));}
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const flags=JSON.parse(fs.readFileSync(new URL('./discrepancy-queue.json',import.meta.url)));
const ids=['CC00666','CC00685',...flags.filter(r=>r.kind==='boolean'&&r.status==='discrepancy'&&cases.find(c=>c.id===r.id)?.operation==='And').map(r=>r.id)];
const rows=[];
for(const c of cases.filter(c=>ids.includes(c.id))){
 const a=path(c.input),b=path(c.other),out=unwrap(c.operation==='Xor'?csg.symmetric_difference_path(a,b,new g.Nonzero()):csg.intersection_path(a,b,new g.Nonzero()));
 const signed=p=>Array.from(p.subpaths).map(s=>area.signed_subpath(s));
 const arcData=p=>Array.from(p.subpaths).flatMap(s=>Array.from(s.segments)).filter(s=>s instanceof g.Arc).map(s=>({start:s.start,end:s.end,radius:s.radius,center:unwrap(g.arc_center_data(s))}));
 const row={id:c.id,output_arcs:arcData(out),input_arcs:arcData(a),other_arcs:arcData(b),input_d:serialize.path(a),other_d:serialize.path(b),output_d:serialize.path(out),input_areas:signed(a),other_areas:signed(b),output_areas:signed(out)};
 if(c.operation==='And'){
  row.outside_input_witnesses=[];
  for(const sub of out.subpaths)for(const segment of sub.segments)for(const t of [.25,.5,.75]){
   const p=unwrap(g.segment_point(segment,t));
   const insideA=unwrap(contain.path_containment(p,a,new g.Nonzero())),insideB=unwrap(contain.path_containment(p,b,new g.Nonzero()));
   for(const [name,input,classification] of [['a',a,insideA],['b',b,insideB]])if(classification instanceof g.Outside){
    const d=unwrap(distance.path_distance(p,input));
    if(d>1e-6){
     const witness={t,point:p,outside:name,distance:d};
     if(name==='a' && c.input.vertices.length===4 && c.input.vertices.every((v,i)=>v[2]===(i%2?1:0))){
      // Input A is a straight capsule. Its region is independently the radius-r
      // neighborhood of the segment joining its two semicircle centers.
      const v=c.input.vertices;
      const c0=[(v[0][0]+v[3][0])/2,(v[0][1]+v[3][1])/2],c1=[(v[1][0]+v[2][0])/2,(v[1][1]+v[2][1])/2];
      const r=Math.hypot(v[1][0]-v[2][0],v[1][1]-v[2][1])/2;
      const dx=c1[0]-c0[0],dy=c1[1]-c0[1],u=Math.max(0,Math.min(1,((p.x-c0[0])*dx+(p.y-c0[1])*dy)/(dx*dx+dy*dy)));
      witness.analytic_capsule_excess=Math.hypot(p.x-c0[0]-u*dx,p.y-c0[1]-u*dy)-r;
      const norm=Math.hypot(p.x-c0[0]-u*dx,p.y-c0[1]-u*dy);
      const step=Math.min(1e-5,witness.analytic_capsule_excess/2);
      const q=new g.Point(p.x-step*(p.x-c0[0]-u*dx)/norm,p.y-step*(p.y-c0[1]-u*dy)/norm);
      witness.inset={point:q,output_classification:unwrap(contain.path_containment(q,out,new g.Nonzero())).constructor.name,input_classification:unwrap(contain.path_containment(q,a,new g.Nonzero())).constructor.name,analytic_capsule_excess:witness.analytic_capsule_excess-step};
     }
     row.outside_input_witnesses.push(witness);
    }
   }
  }
 }
 if(c.operation==='Xor'){
  const [cx,cy,r,x0,y0,x1,y1]=c.id==='CC00666'?[0,0,50,-50,0,50,50]:[5,1,5,3,-10,6,10];
  const minx=Math.min(cx-r,x0),maxx=Math.max(cx+r,x1),miny=Math.min(cy-r,y0),maxy=Math.max(cy+r,y1);
  let checked=0,mismatches=[];
  for(let i=0;i<31;i++)for(let j=0;j<31;j++){
   const x=minx+(maxx-minx)*(i+.371)/31,y=miny+(maxy-miny)*(j+.619)/31;
   const expected=((x-cx)**2+(y-cy)**2<r*r)!==(x>x0&&x<x1&&y>y0&&y<y1);
   const actual=unwrap(contain.path_containment(new g.Point(x,y),out,new g.Nonzero()));
   if((actual instanceof g.Inside)!==expected || actual instanceof g.Boundary)mismatches.push({x,y,expected,actual:actual.constructor.name});checked++;
  }
  row.analytic_region_samples={checked,mismatches};
 }
 rows.push(row);
}
console.log(JSON.stringify(rows,null,2));
