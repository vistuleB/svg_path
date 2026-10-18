import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as e from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./extra-cases.json',import.meta.url)));
const ids=['CX00420','CX00622','CX00636'];
const vertex=s=>[...s.matchAll(/(?:x|y|bulge): ([^,} ]+)/g)].map(m=>Number(m[1]));
const rows=cases.filter(c=>ids.includes(c.id)).map(c=>{
 const a=vertex(c.v1),b=vertex(c.v2),bulge=a[2];
 const radius=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+bulge*bulge)/(4*Math.abs(bulge));
 const result=e.endpoint_to_center(new e.EndpointArcData(new e.EllipsePoint(...a),new e.EllipsePoint(radius,radius),0,Math.abs(bulge)>1,bulge>0,new e.EllipsePoint(...b)));
 if(!result.isOk())throw result;
 return {id:c.id,start:a.slice(0,2),end:b.slice(0,2),bulge,radius,actual:result[0]};
});
console.log(JSON.stringify(rows,null,2));
