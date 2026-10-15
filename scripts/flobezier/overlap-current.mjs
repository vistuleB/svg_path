import fs from 'node:fs';
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as overlaps from './probe/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
import * as intersections from './probe/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as encounters from './probe/build/dev/javascript/svg_path/svg_path/encounters.mjs';
import * as detection from './probe/build/dev/javascript/svg_path/svg_path/internal/overlap_detection.mjs';
const seg=ps=>new [null,null,g.Line,g.QuadraticBezier,g.CubicBezier][ps.length](...ps.map(p=>new g.Point(...p)));
const result=r=>r.isOk()?{ok:true,value:r[0]?.[Symbol.iterator]?[...r[0]]:r[0]}:{ok:false,error:r[0].constructor.name};
const fixtures=[
 {name:'FB001',a:[[1,1],[2,2]],b:[[0,0],[3,3],[.5,.5]]},
 {name:'FI003-a',a:[[0,0],[1,1],[.25,.25]],b:[[2,2],[.5,.5],[.25,.25],[-1,-1]]},
 {name:'FI003-b',a:[[.1,.1],[.8,.8],[.2,.2]],b:[[1,1],[.5,.5],[.3,.3]]},
 {name:'minimal-positive-overlap',a:[[1,0],[3,0]],b:[[0,0],[4,0],[0,0]]},
 {name:'minimal-touch-only',a:[[2,0],[3,0]],b:[[0,0],[4,0],[0,0]]},
 {name:'minimal-disjoint',a:[[3,0],[4,0]],b:[[0,0],[4,0],[0,0]]},
 {name:'identical-retraced',a:[[0,0],[4,0],[0,0]],b:[[0,0],[4,0],[0,0]]},
 {name:'affine-monotone',a:[[0,0],[1,0]],b:[[0,0],[.5,0],[1,0]]},
];
const rows=[];
for(const f of fixtures)for(const reverse of [false,true]){
 const left=seg(reverse?f.b:f.a),right=seg(reverse?f.a:f.b);
 const endpoints=[left.start,left.end,right.start,right.end];
 const endpointMatches=endpoints.map((p,i)=>result(detection.point_parameters(i<2?right:left,p,1e-9)));
 const row={...f,reverse,overlaps:result(overlaps.segment(left,right)),intersections:result(intersections.segment(left,right)),encounters:result(encounters.segment(left,right)),endpointMatches};rows.push(row);
 console.log(f.name,reverse?'reverse':'forward',JSON.stringify(row.overlaps),JSON.stringify(row.intersections));
}
fs.writeFileSync(new URL('overlap-current.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
