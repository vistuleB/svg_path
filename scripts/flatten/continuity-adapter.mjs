// Audit-only polygon adapter. Never mutates the captured input or library API.
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {pieces}=await import('./compare-arc-circle.mjs');
export const cap=1e-6;
export function makePolygonAdapter(policy,adjustments){
 if(!['end-to-next-start','start-to-previous-end'].includes(policy))throw Error('Unknown reconciliation policy');
 let conversion=0;
 return shape=>{
  const which=conversion++;
  return new g.Path(toList(shape.faces.map((face,faceIndex)=>{
   const segs=face.flatMap(pieces),starts=segs.map(s=>s.start),ends=segs.map(s=>s.end);
   for(let i=0;i<segs.length;i++){
    const next=(i+1)%segs.length,a=ends[i],b=starts[next],gap=Math.hypot(a.x-b.x,a.y-b.y);
    if(gap===0)continue;
    if(gap>cap)throw {adapterGapExceedsCap:true,conversion:which,face:faceIndex,edge:i,gap,cap};
    adjustments.push({conversion:which,face:faceIndex,edge:i,gap,from:policy==='end-to-next-start'?a:b,to:policy==='end-to-next-start'?b:a});
    if(policy==='end-to-next-start')ends[i]=b;else starts[next]=a;
   }
   const joined=segs.map((s,i)=>{
    if(s instanceof g.Line)return new g.Line(starts[i],ends[i]);
    if(s instanceof g.Arc)return new g.Arc(starts[i],s.radius,s.x_axis_rotation,s.large_arc,s.sweep,ends[i]);
    throw {unsupportedAdapterSegment:s.constructor.name};
   });
   const r=g.subpath(toList(joined));if(!r.isOk())throw r[0];return r[0];
  })));
 };
}
